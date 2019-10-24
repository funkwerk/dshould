module dshould.ShouldType;

import std.algorithm : map;
import std.format : format;
import std.meta : allSatisfy;
import std.range : iota;
import std.string : empty, join;
import std.traits : TemplateArgsOf;
public import std.traits : isInstanceOf;
import std.typecons : Tuple;

// prevent default arguments from being accidentally filled by regular parameters
// void foo(..., Fence _ = Fence(), string file = __FILE__, size_t line = __LINE__)
public struct Fence
{
}

/**
 * .should begins every fluent assertion in dshould. It takes no parameters on its own.
 * Note that leaving a .should phrase unfinished will error at runtime.
 */
public auto should(T)(lazy T got) pure
{
    T get() pure @safe
    {
        return got;
    }

    return ShouldType!(typeof(&get))(&get);
}

/**
 * ShouldType is the base type passed between UFCS words in fluent assertions.
 * It stores the left-hand side expression of the phrase, called "got" in errors,
 * as well as the words making up the assertion phrase as template arguments.
 */
public struct ShouldType(G, string[] phrase = [])
{
    import std.algorithm : canFind;

    private G got_;

    private int* refCount_ = null;

    /**
     * Add a word to the phrase. Can be chained.
     */
    public auto addWord(string word)()
    {
        return ShouldType!(G, phrase ~ word)(this.got_, this.refCount);
    }

    // Ensure that ShouldType constness is applied to lhs value
    public auto got()
    {
        scope(failure)
        {
            // prevent exceptions in got_() from setting off the unterminated-chain error
            terminateChain;
        }

        return this.got_();
    }

    public const(typeof(this.got_())) got() const
    {
        scope(failure)
        {
            // we know refCount is nonconst
            (cast() this).terminateChain;
        }
        return this.got_();
    }

    private this(G got) { this.got_ = got; this.refCount = 1; }

    /**
     * Manually initialize a new ShouldType value from an existing one's ref count.
     * All ShouldTypes of one phrase must use the same reference counter.
     */
    public this(G got, ref int refCount) @trusted
    in
    {
        assert(refCount != CHAIN_TERMINATED, "don't copy Should that's been terminated");
    }
    do
    {
        this.got_ = got;
        this.refCount_ = &refCount;
        this.refCount++;
    }

    this(this) @trusted
    in
    {
        assert(this.refCount != CHAIN_TERMINATED);
    }
    do
    {
        this.refCount++;
    }

    ~this() @trusted
    {
        import std.exception : enforce;

        this.refCount--;
        // NOT an assert!
        // this ensures that if we fail as a side effect of a test failing, we don't override its exception
        enforce!Exception(this.refCount > 0, "unterminated should-chain!");
    }

    /**
     * Checks a boolean condition for truth, throwing an exception when it fails.
     * The components making up the exception string are passed lazily.
     * The message has the form: "Test failed: expected {expected}[ because reason], but got {butGot}"
     * For instance: "Test failed: expected got.empty() because there should be nothing in there, but got [5]."
     * In that case, `expected` is "got.empty()" and `butGot` is "[5]".
     */
    public void check(bool condition, lazy string expected, lazy string butGot, string file, size_t line) pure @safe
    {
        terminateChain;

        if (!condition)
        {
            throw new FluentException(expected, butGot, file, line);
        }
    }

    /**
     * Mark that the semantic end of this phrase has been reached.
     * If this is not called, the phrase will error on scope exit.
     */
    public void terminateChain()
    {
        this.refCount = CHAIN_TERMINATED; // terminate chain, safe ref checker
    }

    private static enum isStringLiteral(T...) = T.length == 1 && is(typeof(T[0]) == string);

    /**
     * Allows to check that only a select list of words are permitted before the current word.
     * On failure, an informative error is printed.
     * Usage: should.allowOnlyWords!("word1", "word2").before!"newWord";
     */
    public template allowOnlyWords(allowedWords...)
    if (allSatisfy!(isStringLiteral, allowedWords))
    {
        void before(string newWord)()
        {
            static foreach (word; phrase)
            {
                static assert([allowedWords].canFind(word), `bad grammar: "` ~ word ~ ` ` ~ newWord ~ `"`);
            }
        }
    }

    /**
     * Allows to check that a specified word appeared in the phrase before the current word.
     * On failure, an informative error is printed.
     * Usage: should.requireWord!"word".before!"newWord";
     */
    public template requireWord(string requiredWord)
    {
        void before(string newWord)()
        {
            static assert(
                hasWord!requiredWord,
                `bad grammar: expected "` ~ requiredWord ~ `" before "` ~ newWord ~ `"`
            );
        }
    }

    /**
     * Evaluates to true if the given word exists in the current phrase.
     */
    public enum hasWord(string word) = phrase.canFind(word);

    // work around https://issues.dlang.org/show_bug.cgi?id=18839
    public auto empty()(Fence _ = Fence(), string file = __FILE__, size_t line = __LINE__)
    {
        return this.empty_(Fence(), file, line);
    }

    private enum CHAIN_TERMINATED = int.max;

    private @property ref int refCount()
    {
        if (this.refCount_ is null)
        {
            this.refCount_ = new int;
            *this.refCount_ = 0;
        }
        return *this.refCount_;
    }
}

/**
 * Ensures that the given range is empty.
 * Specified here due to https://issues.dlang.org/show_bug.cgi?id=18839
 */
public void empty_(Should)(Should should, Fence _ = Fence(), string file = __FILE__, size_t line = __LINE__)
if (isInstanceOf!(ShouldType, Should))
{
    import std.range : empty;

    with (should)
    {
        allowOnlyWords!("be", "not").before!"empty";
        requireWord!"be".before!"empty";

        terminateChain;

        auto got = should.got();

        static if (hasWord!"not")
        {
            check(!got.empty, "nonempty range", format("%s", got), file, line);
        }
        else
        {
            check(got.empty, "empty range", format("%s", got), file, line);
        }
    }
}

///
unittest
{
    import dshould.basic;

    (int[]).init.should.be.empty;
    [5].should.not.be.empty;
}

private class FluentExceptionImpl(T : Exception) : T
{
    private const string expectedPart = null; // before reason
    public const string reason = null;
    private const string butGotPart = null; // after reason

    invariant
    {
        assert(!this.expectedPart.empty);
    }

    public this(string expectedPart, string butGotPart, string file, size_t line) pure @safe
    in
    {
        assert(!expectedPart.empty);
        assert(!butGotPart.empty);
    }
    do
    {
        this.expectedPart = expectedPart;
        this.butGotPart = butGotPart;

        super(combinedMessage, file, line);
    }

    public this(string expectedPart, string reason, string butGotPart, string file, size_t line) pure @safe
    in
    {
        assert(!expectedPart.empty);
        assert(!butGotPart.empty);
    }
    do
    {
        this.expectedPart = expectedPart;
        this.reason = reason;
        this.butGotPart = butGotPart;

        super(combinedMessage, file, line);
    }

    public this(string msg, string file, size_t line) pure @safe
    in
    {
        assert(!msg.empty);
    }
    do
    {
        this.expectedPart = msg;

        super(combinedMessage, file, line);
    }

    public FluentException because(string reason) pure @safe
    {
        return new FluentException(this.expectedPart, reason, this.butGotPart, this.file, this.line);
    }

    private @property string combinedMessage() pure @safe
    {
        string message = format!`Test failed: expected %s`(this.expectedPart);

        if (!this.reason.empty)
        {
            message ~= format!` because %s`(this.reason);
        }

        if (!this.butGotPart.empty)
        {
            message ~= format!`, but got %s`(this.butGotPart);
        }

        return message;
    }
}

/**
 * When a fluent exception is thrown during the evaluation of the left-hand side of this word,
 * then the reason for the test is set to the `reason` parameter.
 *
 * Usage: 2.should.be(2).because("math is sane");
 */
public T because(T)(lazy T value, string reason)
{
    try
    {
        return value;
    }
    catch (FluentException fluentException)
    {
        throw fluentException.because(reason);
    }
}

static if (__traits(compiles, { import unit_threaded.should : UnitTestException; }))
{
    import unit_threaded.should : UnitTestException;

    /**
     * Indicates a fluent assert has failed, as well as what was tested, why it was tested, and what the outcome was.
     * When unit_threaded is provided, FluentException is a unit_threaded test exception.
     */
    public alias FluentException = FluentExceptionImpl!UnitTestException;
}
else
{
    public alias FluentException = FluentExceptionImpl!Exception;
}
