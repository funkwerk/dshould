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

            terminateChain;

            with (data)
            {
                if (!mixin(format!q{%s}(%s)))
                {
                    throw new FluentException(
                        "test failed",
                        format(": %s", %s),
                        file, line
                    );
                }
            }
        }}(testString, argStrings, testString, args);
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
        *this.refs = int.max; // terminate chain, safe ref checker
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
    {
        *this.refs = *this.refs + 1;
    }

    private void delref()
    {
        *this.refs = *this.refs - 1;
    }

    // work around https://issues.dlang.org/show_bug.cgi?id=18839
    public auto empty()() { return this.empty_; }
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
        static if (Should.hasWord!"not")
        {
            mixin(gencheck!("!%s.empty", ["lhs()"]));
        }
        else
        {
            mixin(gencheck!("%s.empty", ["lhs()"]));
        }
    }
}

class FluentException : Exception
{
    private const string leftPart = null; // before reason
    public const string reason = null;
    private const string rightPart = null; // after reason

    public this(string leftPart, string rightPart, string file, size_t line) pure @safe
    {
        this.leftPart = leftPart;
        this.rightPart = rightPart;

        super("", file, line);

        this.msg = this.message;
    }

    public this(string leftPart, string reason, string rightPart, string file, size_t line) pure @safe
    {
        this.leftPart = leftPart;
        this.reason = reason;
        this.rightPart = rightPart;

        super("", file, line);

        this.msg = this.message;
    }

    public this(string msg, string file, size_t line) pure @safe
    {
        this.leftPart = msg;

        super("", file, line);

        this.msg = this.message;
    }

    public FluentException because(string reason) pure @safe
    {
        return new FluentException(this.leftPart, reason, this.rightPart, this.file, this.line);
    }

    public @property string message() pure @safe
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
