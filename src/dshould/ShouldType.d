module dshould.ShouldType;

import std.algorithm : map;
import std.format : format;
import std.range : iota;
import std.string : empty, join;
import std.traits : TemplateArgsOf;
public import std.traits : isInstanceOf;
import std.typecons : Tuple;

public auto should(T)(lazy T lhs) pure
{
    const delegate_ = { return lhs; };

    auto should = ShouldType!().init;
    should.refs = new int;
    *should.refs = 1;

    return should.addData!"lhs"(delegate_);
}

public struct ShouldType(Data = Tuple!(), string[] Words = [])
{
    import std.algorithm : canFind;

    public Data data;

    private int* refs = null;

    public auto addWord(string Word)()
    {
        return ShouldType!(Data, Words ~ Word)(this.data, this.refs);
    }

    @disable this();

    this(Data data, int* refs) @trusted
    in
    {
        assert(*refs != CHAIN_TERMINATED, "don't copy Should that's been terminated");
    }
    body
    {
        this.data = data;
        this.refs = refs;
        addref;
    }

    this(this) @trusted
    {
        addref;
    }

    ~this() @trusted
    {
        delref;
        assert(*this.refs > 0, "unterminated should-chain!");
    }

    public enum gencheck(string TestString, string[] ArgNames) = gencheckImpl(TestString, ArgNames);

    private static string gencheckImpl(string testString, string[] argNames)
    {
        auto args = argNames.join(", ");
        auto argStrings = argNames.length.iota.map!(i => format!`"%s"`(argNames[i])).join(", ");

        return format!q{{
            import std.format : format;

            with (data)
            {
                check(mixin(format!q{%s}(%s)), format(": expected %s", %s), null, file, line);
            }
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

    public void allowOnlyWordsBefore(string[] AllowedWords, string NewWord)()
    {
        static foreach (Word; Words)
        {
            static assert(AllowedWords.canFind(Word), `bad grammar: "` ~ Word ~ ` ` ~ NewWord ~ `"`);
        }
    }

    public void terminateChain()
    {
        *this.refs = CHAIN_TERMINATED; // terminate chain, safe ref checker
    }

    public void requireWord(string RequiredWord, string NewWord)()
    {
        static assert(
            Words.canFind(RequiredWord),
            `bad grammar: expected "` ~ RequiredWord ~ `" before "` ~ NewWord ~ `"`
        );
    }

    public enum hasWord(string Word) = Words.canFind(Word);

    public template addData(string Name)
    {
        auto addData(T)(T value)
        {
            alias NewTuple = Tuple!(TemplateArgsOf!Data, T, Name);

            return ShouldType!(NewTuple, Words)(NewTuple(this.data.tupleof, value), this.refs);
        }
    }

    private void addref()
    in
    {
        assert(*this.refs != CHAIN_TERMINATED);
    }
    body
    {
        *this.refs = *this.refs + 1;
    }

    private void delref()
    {
        *this.refs = *this.refs - 1;
    }

    // work around https://issues.dlang.org/show_bug.cgi?id=18839
    public auto empty()() { return this.empty_; }

    private enum CHAIN_TERMINATED = int.max;
}

// must be here due to https://issues.dlang.org/show_bug.cgi?id=18839
void empty_(Should)(Should should, string file = __FILE__, size_t line = __LINE__)
if (isInstanceOf!(ShouldType, Should))
{
    import std.range : empty;

    should.allowOnlyWordsBefore!(["be", "not"], "empty");
    should.requireWord!("be", "empty");

    with (should)
    {
        terminateChain;

        auto lhs = data.lhs();

        static if (hasWord!"not")
        {
            check(!lhs.empty, `: expected nonempty array`, null, file, line);
        }
        else
        {
            check(lhs.empty, `: expected empty array`, format(", but got %s", lhs), file, line);
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
