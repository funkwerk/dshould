module dshould;

import dshould.ShouldType;

public import dshould.ShouldType : because, should;
public import dshould.basic;
public import dshould.contain;
public import dshould.empty;
public import dshould.stringcmp;
public import dshould.thrown;

// dispatch based on type

/**
 * The word `.equal` tests its parameter for equality with the left-hand side.
 * If the parameters are strings, a colored diff is used.
 */
public void equal(Should, T)(Should should, T value, Fence _ = Fence(), string file = __FILE__, size_t line = __LINE__)
if (isInstanceOf!(ShouldType, Should))
{
    import dshould.prettyprint : prettyprint;
    import std.json : JSONValue;
    import std.traits : Unqual;

    static if (is(typeof(should.got()) == string) && is(T == string) && !should.hasWord!"not")
    {
        dshould.stringcmp.equal(should, value, Fence(), file, line);
    }
    else static if (
        is(Unqual!T == JSONValue)
        && is(Unqual!(typeof(should.got())) == JSONValue)
        && !should.hasWord!"not")
    {
        should.allowOnlyWords!().before!"equal (string)";
        should.terminateChain;

        auto got = should.got();

        if (got != value)
        {
            stringCmpError(
                got.toPrettyString,
                value.toPrettyString,
                false, file, line);
        }
    }
    else static if (
        __traits(compiles, T.init.toString())
        && __traits(compiles, typeof(should.got()).init.toString())
        && !should.hasWord!"not")
    {
        should.allowOnlyWords!().before!"equal (string)";
        should.terminateChain;

        auto got = should.got();

        if (got != value)
        {
            stringCmpError(
                got.toString().prettyprint,
                value.toString().prettyprint,
                false, file, line);
        }
    }
    else
    {
        dshould.basic.equal(should, value, Fence(), file, line);
    }
}

public auto equal(Should)(Should should)
if (isInstanceOf!(ShouldType, Should))
{
    return dshould.basic.equal(should);
}

/// be is equivalent to equal for the .should.be(value) case
public void be(Should, T)(Should should, T value, Fence _ = Fence(), string file = __FILE__, size_t line = __LINE__)
if (isInstanceOf!(ShouldType, Should))
{
    static if (should.hasNoWords && !is(T == typeof(null)))
    {
        return equal(should, value, Fence(), file, line);
    }
    else
    {
        // be is basic.be for all other cases
        return dshould.basic.be(should, value, Fence(), file, line);
    }
}

// be is basic.be for all other cases
public auto be(Should)(Should should)
if (isInstanceOf!(ShouldType, Should))
{
    return dshould.basic.be(should);
}

// be is basic.be for all other cases
public auto be(Should, T)(
    Should should, T expected, ErrorValue error, Fence _ = Fence(), string file = __FILE__, size_t line = __LINE__)
if (isInstanceOf!(ShouldType, Should) && should.hasWord!"approximately")
{
    return dshould.basic.be(should, expected, error, Fence(), file, line);
}

/**
 * The word `.throwA` (or `.throwAn`) expects its left-hand side expression to throw an exception.
 * Instead of the cumbersome `.where.msg.should.equal("msg")`, the `msg` of the Exception to expect
 * can be passed directly.
 */
public template throwA(T : Throwable)
{
    void throwA(Should)(Should should, string msgTest, Fence _ = Fence(), string file = __FILE__, size_t line = __LINE__)
    if (isInstanceOf!(ShouldType, Should))
    {
        dshould.thrown.throwA!T(should, Fence(), file, line).where.msg.should.equal(msgTest, Fence(), file, line);
    }

    auto throwA(Should)(Should should, Fence _ = Fence(), string file = __FILE__, size_t line = __LINE__)
    if (isInstanceOf!(ShouldType, Should))
    {
        return dshould.thrown.throwA!T(should, Fence(), file, line);
    }
}

/// ditto
public alias throwAn = throwA;

@("because defines reason for assertion")
unittest
{
    2.should.be(5).because("string A")
        .should.throwA!FluentException.where.reason.should.equal("string A");
}

@("compares messages in throwA string overload")
unittest
{
    2.should.be(5).because("string A")
        .should.throwA!FluentException("string B")
        .should.throwA!FluentException;
}

@("prints informative errors for int comparison")
unittest
{
    2.should.be(3).should.throwA!FluentException("Test failed: expected value == 3, but got 2");
}

@("prints informative errors for object comparison")
unittest
{
    Object obj;

    obj.should.not.be(null)
        .should.throwA!FluentException("Test failed: expected non-null, but got null");

    obj = new Object;

    obj.should.be(null)
        .should.throwA!FluentException("Test failed: expected null, but got object.Object");

    obj.should.not.be.same.as(obj)
        .should.throwA!FluentException(
            "Test failed: expected different reference than object.Object, but got same reference");

    obj.should.be.same.as(new Object)
        .should.throwA!FluentException(
            "Test failed: expected same reference as object.Object, but got object.Object");
}

@("prints informative errors for inequalities")
unittest
{
    2.should.be.greater.equal(5)
        .should.throwA!FluentException("Test failed: expected value >= 5, but got 2");

    2.should.not.be.less.equal(5)
        .should.throwA!FluentException("Test failed: expected value not <= 5, but got 2");
}

@("prints informative errors for range emptiness")
unittest
{
    (int[]).init.should.not.be.empty
        .should.throwA!FluentException("Test failed: expected nonempty range, but got []");

    [5].should.be.empty
        .should.throwA!FluentException("Test failed: expected empty range, but got [5]");
}

@("prettyprints json values for comparison")
unittest
{
    import std.json : parseJSON;

    const expected = `Test failed: expected ` ~ `
 {
` ~ red(`-    "b": "Bar"`) ~ `
 }, but got ` ~ `
 {
` ~ green(`+    "a": "Foo"`) ~ `
 }`;

    const left = parseJSON(`{"a": "Foo"}`);
    const right = parseJSON(`{"b": "Bar"}`);

    left.should.equal(right)
        .should.throwA!FluentException(expected);
    left.should.be(right)
        .should.throwA!FluentException(expected);
}

@("prints informative errors for approximate checks")
unittest
{
    2.should.approximately.be(4, error=0.5)
        .should.throwA!FluentException("Test failed: expected 4 ± 0.5, but got 2");

    (2.4).should.not.approximately.be(2, error=0.5)
        .should.throwA!FluentException("Test failed: expected value outside 2 ± 0.5, but got 2.4");
}

@("asserts when forgetting to terminate should expression")
unittest
{
    void test()
    {
        2.should;
    }

    test.should.throwAn!Exception("unterminated should-chain!");
}

@("exceptions in the lhs don't set off the unterminated-chain error")
unittest
{
    int foo()
    {
        throw new Exception("");
    }

    foo.should.be(3).should.throwAn!Exception;
}

@("nullable equality")
unittest
{
    import std.typecons : Nullable;

    Nullable!int(42).should.not.equal(Nullable!int());

    Nullable!int(42).should.equal(Nullable!int()).should.throwA!FluentException
        ("Test failed: expected Nullable.null, but got 42");
}

@("nullable equality")
unittest
{
    import std.typecons : Nullable;

    Nullable!string().should.not.equal("");

    Nullable!string().should.equal("").should.throwA!FluentException
        ("Test failed: expected value == '', but got Nullable!string.null");
}

@("exception thrown by value is not hijacked by unterminated should-chain error")
unittest
{
    int foo()
    {
        throw new Exception("foo");
    }

    foo.should.equal(2).should.throwAn!Exception("foo");
    2.should.equal(foo).should.throwAn!Exception("foo");
}

@("compare two unequal values with the same toString")
unittest
{
    class Class
    {
        override bool opEquals(const Object other) const
        {
            return false;
        }

        override string toString() const
        {
            return "Class";
        }
    }

    auto first = new Class;
    auto second = new Class;

    (first == second).should.be(false);
    first.should.equal(second).should.throwAn!Exception("Test failed: expected Class, but got Class");
}
