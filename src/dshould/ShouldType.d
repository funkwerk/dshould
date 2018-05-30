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

public auto should(T)(lazy T got) pure
{
    T get() pure @safe
    {
        return got;
    }

    return ShouldType!(typeof(&get))(&get);
}

public struct ShouldType(G, string[] phrase = [])
{
    import std.algorithm : canFind;

    public G got;

    private int* refCount_ = null;

    public auto addWord(string word)()
    {
        return ShouldType!(G, phrase ~ word)(this.got, this.refCount);
    }

    private this(G got) { this.got = got; this.refCount = 1; }

    public this(G got, ref int refCount) @trusted
    in
    {
        assert(refCount != CHAIN_TERMINATED, "don't copy Should that's been terminated");
    }
    do
    {
        this.got = got;
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
        this.refCount--;
        assert(this.refCount > 0, "unterminated should-chain!");
    }

    public enum genCheck(string TestString, string[] ArgNames) = genCheckImpl(TestString, ArgNames);

    private static string genCheckImpl(string testString, string[] argNames)
    {
        auto args = format!"%-(%s, %)"(argNames);
        auto argStrings = format!"%(%s, %)"(argNames);

        return format!q{{
            import std.format : format;

            check(mixin(format!q{%s}(%s)), format(": expected %s", %s), null, file, line);
        }}(testString, argStrings, testString, args);
    }

    public void check(bool condition, lazy string left, lazy string right, string file, size_t line) pure @safe
    {
        terminateChain;

        if (!condition)
        {
            throw new FluentException("test failed" ~ left, right, file, line);
        }
    }

    public void terminateChain()
    {
        this.refCount = CHAIN_TERMINATED; // terminate chain, safe ref checker
    }

    private static enum isStringLiteral(T...) = T.length == 1 && is(typeof(T[0]) == string);

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

    public enum hasWord(string word) = phrase.canFind(word);

    // work around https://issues.dlang.org/show_bug.cgi?id=18839
    public auto empty()() { return this.empty_; }

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

// must be here due to https://issues.dlang.org/show_bug.cgi?id=18839
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
            check(!got.empty, `: expected nonempty range`, null, file, line);
        }
        else
        {
            check(got.empty, `: expected empty range`, format(", but got %s", got), file, line);
        }
    }
}

private class FluentExceptionImpl(T : Exception) : T
{
    private const string leftPart = null; // before reason
    public const string reason = null;
    private const string rightPart = null; // after reason

    invariant
    {
        assert(!this.leftPart.empty);
    }

    public this(string leftPart, string rightPart, string file, size_t line) pure @safe
    in
    {
        assert(!leftPart.empty);
    }
    do
    {
        this.leftPart = leftPart;
        this.rightPart = rightPart;

        super(combinedMessage, file, line);
    }

    public this(string leftPart, string reason, string rightPart, string file, size_t line) pure @safe
    in
    {
        assert(!leftPart.empty);
    }
    do
    {
        this.leftPart = leftPart;
        this.reason = reason;
        this.rightPart = rightPart;

        super(combinedMessage, file, line);
    }

    public this(string msg, string file, size_t line) pure @safe
    in
    {
        assert(!msg.empty);
    }
    do
    {
        this.leftPart = msg;

        super(combinedMessage, file, line);
    }

    public FluentException because(string reason) pure @safe
    {
        return new FluentException(this.leftPart, reason, this.rightPart, this.file, this.line);
    }

    private @property string combinedMessage() pure @safe
    {
        string message = this.leftPart;

        if (!this.reason.empty)
        {
            message ~= format!` because %s`(this.reason);
        }

        if (!this.rightPart.empty)
        {
            message ~= this.rightPart;
        }

        return message;
    }
}

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

    public alias FluentException = FluentExceptionImpl!UnitTestException;
}
else
{
    public alias FluentException = FluentExceptionImpl!Exception;
}
