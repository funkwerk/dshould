module dshould.basic;

import std.string : empty;
import dshould.ShouldType;
public import dshould.ShouldType : should;

pure @safe unittest
{
    2.should.be(2);
    2.should.not.be(5);
    5.should.equal(5);
    5.should.not.equal(6);
    5.should.not.be.equal.greater(6);
    5.should.be.equal.greater(5);
    5.should.be.equal.greater(4);
    5.should.not.be.equal.greater(6);
    5.should.be.smaller(6);
}

unittest
{
    (new Object).should.not.be(new Object);
    (new Object).should.not.equal(new Object);
    (new Object).should.not.be(null);
    (cast(Object) null).should.be(null);

    auto obj = new Object;

    obj.should.equal(obj);
    obj.should.be(obj);

    class SameyClass
    {
        override bool opEquals(Object o) { return true; }
    }

    (new SameyClass).should.not.be(new SameyClass);
    (new SameyClass).should.equal(new SameyClass);

    (cast(void delegate()) null).should.be(null);
}

auto not(Should)(Should should) pure
if (isInstanceOf!(ShouldType, Should))
{
    should.allowOnlyWordsBefore!([], "not");

    return should.addWord!"not";
}

auto be(Should)(Should should) pure
if (isInstanceOf!(ShouldType, Should))
{
    should.allowOnlyWordsBefore!(["not"], "be");

    return should.addWord!"be";
}

void be(Should, T)(Should should, T value, string file = __FILE__, size_t line = __LINE__)
if (isInstanceOf!(ShouldType, Should) && !should.hasWord!"approximately")
{
    import std.format : format;

    should.allowOnlyWordsBefore!(["not"], "be");

    enum isNullType = is(T == typeof(null));
    // only types that can have toString need to disambiguate
    enum isReferenceType = is(T == class) || is(T == interface);

    with (should.addData!"rhs"(value))
    {
        static if (hasWord!"not")
        {
            const refInfo = isReferenceType ? "different reference than " : "not ";

            static if (isNullType)
            {
                check(data.lhs() !is null, format(": expected non-null, but got null"), file, line);
            }
            else
            {
                auto lhs = data.lhs();
                auto rhs = data.rhs;

                check(lhs !is rhs, format(": expected %s%s, but got %s", refInfo, rhs.quote, lhs.quote), file, line);
            }
        }
        else
        {
            const refInfo = isReferenceType ? "same reference as " : "";
            auto lhs = data.lhs();
            auto rhs = data.rhs;

            static if (is(T == typeof(null)))
            {
                check(lhs is null, format(": expected null, but got %s", lhs.quote), file, line);
            }
            else
            {

                check(lhs is rhs, format(": expected %s%s, but got %s", refInfo, rhs.quote, lhs.quote), file, line);
            }
        }
    }
}

auto equal(Should)(Should should)
if (isInstanceOf!(ShouldType, Should))
{
    should.allowOnlyWordsBefore!(["not", "be", "greater", "smaller"], "equal");

    return should.addWord!"equal";
}

void equal(Should, T)(Should should, T value, string file = __FILE__, size_t line = __LINE__)
if (isInstanceOf!(ShouldType, Should) && !should.hasWord!"approximately")
{
    should.equal.addData!"rhs"(value).numericCheck(file, line);
}

auto greater(Should)(Should should)
if (isInstanceOf!(ShouldType, Should))
{
    should.allowOnlyWordsBefore!(["not", "be", "equal", "smaller"], "greater");
    should.requireWord!("be", "greater");

    return should.addWord!"greater";
}

void greater(Should, T)(Should should, T value, string file = __FILE__, size_t line = __LINE__)
if (isInstanceOf!(ShouldType, Should))
{
    should.greater.addData!"rhs"(value).numericCheck(file, line);
}

auto smaller(Should)(Should should)
if (isInstanceOf!(ShouldType, Should))
{
    should.allowOnlyWordsBefore!(["not", "be", "equal", "greater"], "smaller");
    should.requireWord!("be", "smaller");

    return should.addWord!"smaller";
}

void smaller(Should, T)(Should should, T value, string file = __FILE__, size_t line = __LINE__)
if (isInstanceOf!(ShouldType, Should))
{
    should.smaller.addData!"rhs"(value).numericCheck(file, line);
}

void numericCheck(Should)(Should should, string file, size_t line)
if (isInstanceOf!(ShouldType, Should))
{
    import std.format : format;

    enum notPart = should.hasWord!"not" ? "!" : "";
    enum equalPart = should.hasWord!"equal" ? "==" : "";
    enum equalPartShort = should.hasWord!"equal" ? "=" : "";
    enum smallerPart = should.hasWord!"smaller" ? "<" : "";
    enum greaterPart = should.hasWord!"greater" ? ">" : "";

    enum isFloating = __traits(isFloating, typeof(should.data.lhs()));

    static if (isFloating)
    {
        enum combinedWithoutEqual = notPart ~ smallerPart ~ greaterPart;
    }
    else
    {
        enum combinedWithoutEqual = smallerPart ~ greaterPart;
    }

    enum combined = combinedWithoutEqual ~ (combinedWithoutEqual.empty ? equalPart : equalPartShort);

    static if (isFloating || !should.hasWord!"not")
    {
        enum checkString = "%s " ~ combined ~ " %s";
        enum message = combined ~ " %s";
    }
    else
    {
        enum checkString = "!(%s " ~ combined ~ " %s)";
        enum message = "not " ~ combined ~ " %s";
    }

    with (should)
    {
        auto lhs = data.lhs();
        auto rhs = data.rhs;

        check(
            mixin(format!checkString("lhs", "rhs")),
            format(": expected value %s, but got %s", message.format(rhs.quote), lhs.quote),
            file, line
        );
    }
}

/**
 * This could be in a separate file, say approx.d,
 * if doing so didn't crash dmd.
 * see https://issues.dlang.org/show_bug.cgi?id=18839
 */
unittest
{
    5.should.be.approximately(5.1, 0.11);
    5.should.approximately(0.11).be(5.1);
    0.should.approximately(1.1).equal(1.0);
    0.should.approximately(1.1).equal(-1.0);
    0.should.not.approximately(0.1).equal(1);
    42.3.should.be.approximately(42.3, 1e-3);
}

auto approximately(Should)(Should should, double permissibleError)
if (isInstanceOf!(ShouldType, Should))
{
    return should.addWord!"approximately".addData!"permissibleError"(permissibleError);
}

auto approximately(Should)(
    Should should, double value, double permissibleError,
    string file = __FILE__, size_t line = __LINE__
)
if (isInstanceOf!(ShouldType, Should))
{
    static assert(
        should.hasWord!"be" || should.hasWord!"equal",
        `bad grammar: expected "be" or "equal" before "approximately"`
    );

    should.allowOnlyWordsBefore!(["be", "equal", "not"], "approximately");

    return should
        .addWord!"approximately"
        .addData!"permissibleError"(permissibleError)
        .addData!"rhs"(value)
        .approximateCheck(file, line);
}

void be(Should, T)(Should should, T value, string file = __FILE__, size_t line = __LINE__)
if (isInstanceOf!(ShouldType, Should) && should.hasWord!"approximately")
{
    import std.traits : isDynamicArray;

    static if (isDynamicArray!T)
    {
        pragma(msg, "reference comparison of dynamic array: this is probably not what you want.");
    }

    should.allowOnlyWordsBefore!(["approximately", "not"], "equal");

    return should.addData!"rhs"(value).approximateCheck(file, line);
}

void equal(Should, T)(Should should, T value, string file = __FILE__, size_t line = __LINE__)
if (isInstanceOf!(ShouldType, Should) && should.hasWord!"approximately")
{
    should.allowOnlyWordsBefore!(["approximately", "not"], "be");

    return should.addData!"rhs"(value).approximateCheck(file, line);
}

void approximateCheck(Should)(Should should, string file, size_t line)
if (isInstanceOf!(ShouldType, Should))
{
    import std.format : format;
    import std.math : abs;

    with (should)
    {
        auto lhs = data.lhs();
        auto rhs = data.rhs;

        static if (hasWord!"not")
        {
            check(
                abs(lhs - rhs) >= data.permissibleError,
                format(": expected value outside %s ± %s, but got %s", rhs, data.permissibleError, lhs),
                file, line
            );
        }
        else
        {
            check(
                abs(lhs - rhs) < data.permissibleError,
                format(": expected %s ± %s, but got %s", rhs, data.permissibleError, lhs),
                file, line
            );
        }
    }
}

private string quote(T)(T t)
{
    import std.format : format;

    static if (is(T: string))
    {
        return format(`'%s'`, t);
    }
    else
    {
        return format(`%s`, t);
    }
}
