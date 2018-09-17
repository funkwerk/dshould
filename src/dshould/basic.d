module dshould.basic;

import std.format : format;
import std.string : empty;
import dshould.ShouldType;
public import dshould.ShouldType : should;

/**
 * The word `.not` negates the current phrase.
 */
public auto not(Should)(Should should) pure
if (isInstanceOf!(ShouldType, Should))
{
    should.allowOnlyWords!().before!"not";

    return should.addWord!"not";
}

/**
 * The word `.be` indicates a test for identity.
 * For value types, this is equivalent to equality.
 * It takes one parameter and terminates the phrase.
 */
public void be(Should, T)(Should should, T expected, Fence _ = Fence(), string file = __FILE__, size_t line = __LINE__)
if (isInstanceOf!(ShouldType, Should) && !should.hasWord!"approximately")
{
    import std.traits : isDynamicArray;

    static if (isDynamicArray!T)
    {
        pragma(msg, "reference comparison of dynamic array: this is probably not what you want.");
    }

    with (should)
    {
        allowOnlyWords!("not").before!"be";

        enum isNullType = is(T == typeof(null));
        // only types that can have toString need to disambiguate
        enum isReferenceType = is(T == class) || is(T == interface);

        auto got = should.got();

        static if (hasWord!"not")
        {
            const refInfo = isReferenceType ? "different reference than " : "not ";

            static if (isNullType)
            {
                check(got !is null, "non-null", "null", file, line);
            }
            else
            {
                check(
                    got !is expected,
                    format("%s%s", refInfo, expected.quote),
                    isReferenceType ? "same reference" : "it",
                    file, line
                );
            }
        }
        else
        {
            const refInfo = isReferenceType ? "same reference as " : "";

            static if (is(T == typeof(null)))
            {
                check(got is null, "null", format("%s", got.quote), file, line);
            }
            else
            {
                check(
                    got is expected,
                    format("%s%s", refInfo, expected.quote),
                    format("%s", got.quote),
                    file, line
                );
            }
        }
    }
}

///
pure @safe unittest
{
    2.should.be(2);
    2.should.not.be(5);
}

///
unittest
{
    (new Object).should.not.be(new Object);
    (new Object).should.not.be(null);
    (cast(Object) null).should.be(null);
}

///
unittest
{
    (cast(void delegate()) null).should.be(null);
}

unittest
{
    const(string)[][] a = [["a"]];
    string[][] b = [["a"]];

    a.should.equal(b);
    b.should.equal(a);
}

/**
 * When called without parameters, `.be` is a filler word for `.greater`, `.less` or `.equal`.
 */
public auto be(Should)(Should should) pure
if (isInstanceOf!(ShouldType, Should))
{
    should.allowOnlyWords!("not").before!"be";

    return should.addWord!"be";
}

/**
 * The word `.equal` tests for equality.
 * It takes one parameter and terminates the phrase.
 * Its parameter is the expected value for the left-hand side of the should phrase.
 */
public void equal(Should, T)(Should should, T expected, Fence _ = Fence(), string file = __FILE__, size_t line = __LINE__)
if (isInstanceOf!(ShouldType, Should) && !should.hasWord!"approximately")
{
    should.equal.numericCheck(expected, file, line);
}

///
pure @safe unittest
{
    5.should.equal(5);
    5.should.not.equal(6);
}

///
unittest
{
    (new Object).should.not.equal(new Object);
}

///
unittest
{
    auto obj = new Object;

    obj.should.equal(obj);
    obj.should.be(obj);
}

///
unittest
{
    class SameyClass
    {
        override bool opEquals(Object o) { return true; }
    }

    (new SameyClass).should.not.be(new SameyClass);
    (new SameyClass).should.equal(new SameyClass);
}

/**
 * When called without parameters, `.equal` must be terminated by `.greater` or `.less`.
 * .should.be.equal.greater(...) is equivalent to .should.be.greater.equal(...)
 * is equivalent to assert(got >= expected).
 */
public auto equal(Should)(Should should)
if (isInstanceOf!(ShouldType, Should))
{
    should.allowOnlyWords!("not", "be", "greater", "less").before!"equal";

    return should.addWord!"equal";
}

///
pure @safe unittest
{
    5.should.not.be.greater.equal(6);
    5.should.be.greater.equal(5);
    5.should.be.greater.equal(4);
    5.should.not.be.greater.equal(6);
}

/**
 * The word `.greater` tests that the left-hand side is greater than the expected value.
 * It takes one parameter and terminates the phrase.
 */
public void greater(Should, T)(Should should, T expected, Fence _ = Fence(), string file = __FILE__, size_t line = __LINE__)
if (isInstanceOf!(ShouldType, Should))
{
    should.greater.numericCheck(expected, file, line);
}

///
pure @safe unittest
{
    5.should.not.be.greater(6);
    5.should.not.be.greater(5);
    5.should.be.greater(4);
}

/**
 * When called without parameters, `.greater` must be terminated by `.equal`, indicating `>=`.
 */
public auto greater(Should)(Should should)
if (isInstanceOf!(ShouldType, Should))
{
    should.allowOnlyWords!("not", "be", "equal").before!"greater";
    should.requireWord!"be".before!"greater";

    return should.addWord!"greater";
}

/**
 * The word `.less` tests that the left-hand side is less than the expected value.
 * It takes one parameter and terminates the phrase.
 */
public void less(Should, T)(Should should, T expected, Fence _ = Fence(), string file = __FILE__, size_t line = __LINE__)
if (isInstanceOf!(ShouldType, Should))
{
    should.less.numericCheck(expected, file, line);
}

///
pure @safe unittest
{
    5.should.be.less(6);
}

/**
 * When called without parameters, `.less` must be terminated by `.equal`, indicating `<=`.
 */
public auto less(Should)(Should should)
if (isInstanceOf!(ShouldType, Should))
{
    should.allowOnlyWords!("not", "be", "equal").before!"less";
    should.requireWord!"be".before!"less";

    return should.addWord!"less";
}

// const version
private void numericCheck(Should, T)(Should should, const T expected, string file, size_t line)
if (isInstanceOf!(ShouldType, Should)
    && __traits(compiles,
        (Should should, const T expected) =>
            mixin(format!(numericComparison!(Should, T).checkString)("should.got()", "expected"))))
{
    with (should)
    {
        const got = should.got();

        alias enums = numericComparison!(Should, T);

        check(
            mixin(format!(enums.checkString)("got", "expected")),
            format("value %s", enums.message.format(expected.quote)),
            format("%s", got.quote),
            file, line
        );
    }
}

// nonconst version, for badwrong types that need nonconst opCmp
private void numericCheck(Should, T)(Should should, T expected, string file, size_t line)
if (isInstanceOf!(ShouldType, Should)
    && !__traits(compiles,
        (Should should, const T expected) =>
            mixin(format!(numericComparison!(Should, T).checkString)("should.got()", "expected")))
    && __traits(compiles,
        (Should should, T expected) =>
            mixin(format!(numericComparison!(Should, T).checkString)("should.got()", "expected"))))
{
    with (should)
    {
        auto got = should.got();

        alias enums = numericComparison!(Should, T);

        check(
            mixin(format!(enums.checkString)("got", "expected")),
            format("value %s", enums.message.format(expected.quote)),
            format("%s", got.quote),
            file, line
        );
    }
}

private template numericComparison(Should, T)
{
    enum equalPart = Should.hasWord!"equal" ? "==" : "";
    enum equalPartShort = Should.hasWord!"equal" ? "=" : "";
    enum lessPart = Should.hasWord!"less" ? "<" : "";
    enum greaterPart = Should.hasWord!"greater" ? ">" : "";

    enum comparison = lessPart ~ greaterPart;

    enum combined = comparison ~ (comparison.empty ? equalPart : equalPartShort);

    static if (Should.hasWord!"not")
    {
        enum checkString = "!(%s " ~ combined ~ " %s)";
        enum message = "not " ~ combined ~ " %s";
    }
    else
    {
        enum checkString = "%s " ~ combined ~ " %s";
        enum message = combined ~ " %s";
    }
}

/**
 * This could be in a separate file, say approx.d,
 * if doing so didn't crash dmd.
 * see https://issues.dlang.org/show_bug.cgi?id=18839
 */

private struct ErrorValue
{
    @disable this();

    private this(double value) pure @safe
    {
        this.value = value;
    }

    double value;
}

public auto error(double value) pure @safe
{
    return ErrorValue(value);
}

/**
 * `.approximately` is a word indicating an approximate value comparison.
 * When using .approximately, only the words `.be` and `.equal` may be used, though they may appear before or after.
 * Each must be called with an additional parameter, `error = <float>`, indicating the amount of permissible error.
 */
public auto approximately(Should)(
    Should should, double expected, ErrorValue error,
    Fence _ = Fence(), string file = __FILE__, size_t line = __LINE__
)
if (isInstanceOf!(ShouldType, Should))
{
    static assert(
        should.hasWord!"be" || should.hasWord!"equal",
        `bad grammar: expected "be" or "equal" before "approximately"`
    );

    should.allowOnlyWords!("be", "equal", "not").before!"approximately";

    return should
        .addWord!"approximately"
        .approximateCheck(expected, error, file, line);
}

///
unittest
{
    5.should.be.approximately(5.1, error = 0.11);
    5.should.approximately.be(5.1, error = 0.11);
    0.should.approximately.equal(1.0, error = 1.1);
    0.should.approximately.equal(-1.0, error = 1.1);
    0.should.not.approximately.equal(1, error = 0.1);
    42.3.should.be.approximately(42.3, error = 1e-3);
}

unittest
{
    class A
    {
        public override int opCmp(Object rhs) const @nogc pure nothrow @safe
        {
            return 0;
        }
    }

    auto a = new A;

    a.should.not.be.greater(a);
}

public void be(Should, T)(Should should, T expected, ErrorValue error, Fence _ = Fence(), string file = __FILE__, size_t line = __LINE__)
if (isInstanceOf!(ShouldType, Should) && should.hasWord!"approximately")
{
    should.allowOnlyWords!("approximately", "not").before!"equal";

    return should.approximateCheck(expected, error, file, line);
}

public void equal(Should, T)(Should should, T expected, ErrorValue error, Fence _ = Fence(), string file = __FILE__, size_t line = __LINE__)
if (isInstanceOf!(ShouldType, Should) && should.hasWord!"approximately")
{
    should.allowOnlyWords!("approximately", "not").before!"be";

    return should.approximateCheck(expected, error, file, line);
}

public auto approximately(Should)(Should should)
if (isInstanceOf!(ShouldType, Should))
{
    return should.addWord!"approximately";
}

private void approximateCheck(Should, T)(Should should, T expected, ErrorValue error, string file, size_t line)
if (isInstanceOf!(ShouldType, Should))
{
    import std.math : abs;

    with (should)
    {
        auto got = should.got();

        static if (hasWord!"not")
        {
            check(
                abs(expected - got) >= error.value,
                format("value outside %s ± %s", expected, error.value),
                format("%s", got),
                file, line
            );
        }
        else
        {
            check(
                abs(expected - got) < error.value,
                format("%s ± %s", expected, error.value),
                format("%s", got),
                file, line
            );
        }
    }
}

private string quote(T)(T t)
{
    static if (is(T: string))
    {
        return format("'%s'", t);
    }
    else
    {
        return format("%s", t);
    }
}
