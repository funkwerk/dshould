module dshould.ShouldType;

import std.algorithm : map;
import std.format : format;
import std.range : iota;
import std.string : empty, join;
import std.traits : TemplateArgsOf;
public import std.traits : isInstanceOf;
import std.typecons : Tuple;

public auto should(T)(lazy T got) pure
{
    T get() pure @safe
    {
        return got;
    }

    return ShouldType!(typeof(&get))(&get);
}

public struct ShouldType(G, string[] words = [])
{
    import std.algorithm : canFind;

    public G got;

    private int* refs_ = null;

    public auto addWord(string word)()
    {
        return ShouldType!(G, words ~ word)(this.got, this.refs);
    }

    private this(G got) { this.got = got; this.refs = 1; }

    public this(G got, ref int refs) @trusted
    in
    {
        assert(refs != CHAIN_TERMINATED, "don't copy Should that's been terminated");
    }
    body
    {
        this.got = got;
        this.refs_ = &refs;
        this.refs++;
    }

    this(this) @trusted
    {
        assert(this.refs != CHAIN_TERMINATED);

        this.refs++;
    }

    ~this() @trusted
    {
        this.refs--;
        assert(this.refs > 0, "unterminated should-chain!");
    }

    public enum gencheck(string TestString, string[] ArgNames) = gencheckImpl(TestString, ArgNames);

    private static string gencheckImpl(string testString, string[] argNames)
    {
        auto args = argNames.join(", ");
        auto argStrings = argNames.length.iota.map!(i => format!`"%s"`(argNames[i])).join(", ");

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

    public void allowOnlyWordsBefore(string[] allowedWords, string newWord)()
    {
        static foreach (word; words)
        {
            static assert(allowedWords.canFind(word), `bad grammar: "` ~ word ~ ` ` ~ newWord ~ `"`);
        }
    }

    public void terminateChain()
    {
        this.refs = CHAIN_TERMINATED; // terminate chain, safe ref checker
    }

    public void requireWord(string requiredWord, string newWord)()
    {
        static assert(
            words.canFind(requiredWord),
            `bad grammar: expected "` ~ requiredWord ~ `" before "` ~ newWord ~ `"`
        );
    }

    public enum hasWord(string word) = words.canFind(word);

    // work around https://issues.dlang.org/show_bug.cgi?id=18839
    public auto empty()() { return this.empty_; }

    private enum CHAIN_TERMINATED = int.max;

    private @property ref int refs()
    {
        if (this.refs_ is null)
        {
            this.refs_ = new int;
            *this.refs_ = 0;
        }
        return *this.refs_;
    }
}

// must be here due to https://issues.dlang.org/show_bug.cgi?id=18839
void empty_(Should)(Should should, string file = __FILE__, size_t line = __LINE__)
if (isInstanceOf!(ShouldType, Should))
{
    import std.range : empty;

    with (should)
    {
        allowOnlyWordsBefore!(["be", "not"], "empty");
        requireWord!("be", "empty");

        terminateChain;

        auto got = should.got();

        static if (hasWord!"not")
        {
            check(!got.empty, `: expected nonempty array`, null, file, line);
        }
        else
        {
            check(got.empty, `: expected empty array`, format(", but got %s", got), file, line);
        }
    }
}

class FluentExceptionImpl(T : Exception) : T
{
    private const string leftPart = null; // before reason
    public const string reason = null;
    private const string rightPart = null; // after reason

    public this(string leftPart, string rightPart, string file, size_t line) pure @safe
    {
        this.leftPart = leftPart;
        this.rightPart = rightPart;

        super(genMessage, file, line);
    }

    public this(string leftPart, string reason, string rightPart, string file, size_t line) pure @safe
    {
        this.leftPart = leftPart;
        this.reason = reason;
        this.rightPart = rightPart;

        super(genMessage, file, line);
    }

    public this(string msg, string file, size_t line) pure @safe
    {
        this.leftPart = msg;

        super(genMessage, file, line);
    }

    public FluentException because(string reason) pure @safe
    {
        return new FluentException(this.leftPart, reason, this.rightPart, this.file, this.line);
    }

    private string genMessage() pure @safe
    {
        string message = "";

        if (!this.leftPart.empty)
        {
            message = this.leftPart;
        }

        if (!this.reason.empty)
        {
            message ~= message.empty ? "" : " ";
            message ~= format!`because %s`(this.reason);
        }

        if (!this.rightPart.empty)
        {
            message ~= this.rightPart;
        }

        return message;
    }
}

static if (__traits(compiles, { import unit_threaded.should : UnitTestException; }))
{
    import unit_threaded.should : UnitTestException;

    alias FluentException = FluentExceptionImpl!UnitTestException;
}
else
{
    alias FluentException = FluentExceptionImpl!Exception;
}
