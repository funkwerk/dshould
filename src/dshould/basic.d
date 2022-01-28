module dshould.basic;

import std.format : format;
import std.range : isInputRange;
import std.string : empty;
import std.typecons : Nullable;
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
 * The word `.be()` is a placeholder for `.equal`.
 *
 * Note: Reference comparison is achieved with `.be.same.as()`.
 */
public void be(Should, T)(Should should, T expected, Fence _ = Fence(), string file = __FILE__, size_t line = __LINE__)
if (isInstanceOf!(ShouldType, Should) && !should.hasWord!"approximately" && !is(T == typeof(null)))
{
    return equal(should, expected, Fence(), file, line);
}

/**
 * The phrase `be.same.as()` compares two values by reference.
 */
public auto same(Should)(Should should) pure
if (isInstanceOf!(ShouldType, Should) && should.hasWord!"be")
{
    should.allowOnlyWords!("not", "be").before!"same";

    return should.addWord!"same";
}

/**
 * The phrase `be(null)` is equivalent to `be.same.as(null)`.
 */
public void be(Should)(
    Should should, typeof(null) expected, Fence _ = Fence(), string file = __FILE__, size_t line = __LINE__)
if (isInstanceOf!(ShouldType, Should) && !should.hasWord!"approximately")
{
    should.allowOnlyWords!("not").before!"be";

    should.be.same.as(null, Fence(), file, line);
}

///
public auto as(Should, T)(
    Should should, T expected,
    Fence _ = Fence(), string file = __FILE__, size_t line = __LINE__)
if (isInstanceOf!(ShouldType, Should) && should.hasWord!"same")
{
    return dshould.basic.compareReference(should, expected, Fence(), file, line);
}

//
unittest
{
    auto array1 = [5], array2 = array1.dup;

    array1.should.be(array1);
    array1.should.be(array2);

    array1.should.be.same.as(array1);
    array1.should.not.be.same.as(array2);

    (new Object).should.not.be(new Object);
}

private void compareReference(Should, T)(
    Should should, T expected, Fence _ = Fence(), string file = __FILE__, size_t line = __LINE__)
if (isInstanceOf!(ShouldType, Should))
{
    with (should)
    {
        enum isNullType = is(T == typeof(null));

        auto got = should.got();

        static if (hasWord!"not")
        {
            static if (isNullType)
            {
                check(got !is null, "non-null", "null", file, line);
            }
            else
            {
                check(
                    got !is expected,
                    format("different reference than %s", expected.quote),
                    "same reference",
                    file, line
                );
            }
        }
        else
        {
            static if (isNullType)
            {
                check(got is null, "null", format("%s", got.quote), file, line);
            }
            else
            {
                check(
                    got is expected,
                    format("same reference as %s", expected.quote),
                    format("%s", got.quote),
                    file, line
                );
            }
        }
    }
}

unittest
{
    const(string)[][] a = [["a"]];
    string[][] b = [["a"]];

    a.should.equal(b);
    b.should.equal(a);
}

/**
 * `Nullable!int().should.beNull` tests that the `Nullable` is null.
 * `should.not.beNull` tests the reverse.
 */
public void beNull(Should)(Should should, string file = __FILE__, size_t line = __LINE__)
if (isInstanceOf!(ShouldType, Should))
{
    import std.format : format;

    should.allowOnlyWords!("not")
        .before!"beNull";

    auto got = should.got();

    static if (__traits(compiles, got is null))
    {
        compareReference(should, null, Fence(), file, line);
        return;
    }
    else
    {
        static assert(is(typeof(got) : Nullable!T, T));
        static if (Should.hasWord!"not")
        {
            should.check(!got.isNull, "non-null Nullable", format!"%s"(got), file, line);
        }
        else
        {
            should.check(got.isNull, "Nullable.null", format!"%s"(got), file, line);
        }
    }
}

///
unittest
{
    Nullable!int().should.beNull;
    Nullable!int(5).should.not.beNull;
}

///
unittest
{
    Object.init.should.beNull;
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

    (new SameyClass).should.be(new SameyClass);
    (new SameyClass).should.equal(new SameyClass);
    (new SameyClass).should.not.be.same.as(new SameyClass);
}

///
unittest
{
    const string[int] hashmap1 = [1: "2", 5: "4"];
    string[int] hashmap2 = null;

    hashmap2[5] = "4";
    hashmap2[1] = "2";

    // TODO reliable way to produce a hash collision
    // assert(hashmap1.keys != hashmap2.keys, "hash collision not found"); // make sure that ordering doesn't matter

    hashmap1.should.equal(hashmap2);
    hashmap2.should.equal(hashmap1);
}

///
unittest
{
    import std.range : only;

    5.only.should.equal([5]);
    [5].should.equal(5.only);
    5.only.should.not.equal(6.only);
    5.only.should.not.equal([6]);
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
        (const Should should, const T expected) =>
            mixin(format!(numericComparison!(Should, T).checkString)("should.got()", "expected"))))
{
    with (should)
    {
        const got = should.got();

        alias enums = numericComparison!(Should, T);

        check(
            mixin(format!(enums.checkString)("got", "expected")),
            format(enums.message, expected.quote),
            got.quote,
            file, line
        );
    }
}

// nonconst version, for badwrong types that need nonconst opCmp
private void numericCheck(Should, T)(Should should, T expected, string file, size_t line)
if (isInstanceOf!(ShouldType, Should)
    && !__traits(compiles,
        (const Should should, const T expected) =>
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
            format(enums.message, expected.quote),
            got.quote,
            file, line
        );
    }
}

// range version
private void numericCheck(Should, T)(Should should, T expected, string file, size_t line)
if (isInstanceOf!(ShouldType, Should)
    && numericComparison!(Should, T).combined == "=="
    && !__traits(compiles, should.got() == expected)
    && !__traits(compiles, cast(const) should.got() == cast(const) expected)
    && isInputRange!(typeof(should.got())) && isInputRange!T)
{
    import std.range : array;

    with (should)
    {
        auto got = should.got();

        alias enums = numericComparison!(Should, T);

        check(
            mixin(format!(enums.checkString)("got.array", "expected.array")),
            format(enums.message, expected.quote),
            got.quote,
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
        enum message = "value not " ~ combined ~ " %s";
    }
    else static if (combined == "==")
    {
        enum checkString = "%s == %s";
        enum message = "%s";
    }
    else
    {
        enum checkString = "%s " ~ combined ~ " %s";
        enum message = "value " ~ combined ~ " %s";
    }
}

/**
 * This could be in a separate file, say approx.d,
 * if doing so didn't crash dmd.
 * see https://issues.dlang.org/show_bug.cgi?id=18839
 */

package struct ErrorValue
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

package string quote(T)(T t)
{
    import std.typecons : Nullable;

    static if (is(T : Nullable!U, U))
    {
        if (t.isNull)
        {
            return "Nullable.null";
        }
    }

    static if (is(T: string))
    {
        return format("'%s'", t);
    }
    else
    {
        return format("%s", t);
    }
}
