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
    should.allowOnlyWordsBefore!(["not"], "be");

    static if (Should.hasWord!"not")
    {
        with (should.addData!"rhs"(value))
        {
            mixin(gencheck!("%s !is %s", ["lhs()", is(T == typeof(null)) ? "null" : "rhs"]));
        }
    }
    else
    {
        with (should.addData!"rhs"(value))
        {
            mixin(gencheck!("%s is %s", ["lhs()", is(T == typeof(null)) ? "null" : "rhs"]));
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
        enum check = "%s " ~ combined ~ " %s";
    }
    else
    {
        enum check = "!(%s " ~ combined ~ " %s)";
    }

    with (should)
    {
        mixin(gencheck!(check, ["lhs()", "rhs"]));
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
    import std.math : abs;

    with (should)
    {
        static if (should.hasWord!"not")
        {
            mixin(gencheck!("abs(%s - %s) >= %s", ["lhs()", "rhs", "permissibleError"]));
        }
        else
        {
            mixin(gencheck!("abs(%s - %s) < %s", ["lhs()", "rhs", "permissibleError"]));
        }
    }
}
