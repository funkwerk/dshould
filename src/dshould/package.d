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
    import std.json : JSONValue;
    import std.traits : Unqual;

    static if (is(typeof(should.got()) == string) && is(T == string) && !should.hasWord!"not")
    {
        dshould.stringcmp.equal(should, value, Fence(), file, line);
    }
    else static if (
        is(Unqual!T == JSONValue)
        && is(Unqual!(typeof(should.got())) == JSONValue)
        && !should.hasWord!"not"
    )
    {
        should.terminateChain;
        should.got().toPrettyString.should.equal(value.toPrettyString);
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
    2.should.be(3).should.throwA!FluentException("Test failed: expected 3, but got 2");
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

    obj.should.not.be(obj)
        .should.throwA!FluentException(
            "Test failed: expected different reference than object.Object, but got same reference");

    obj.should.be(new Object)
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
    [].should.not.be.empty
        .should.throwA!FluentException("Test failed: expected nonempty range, but got []");

    [5].should.be.empty
        .should.throwA!FluentException("Test failed: expected empty range, but got [5]");
}

@("prettyprints json values for comparison")
unittest
{
    import std.json : parseJSON;

    const expected = `Test failed: expected ' {
` ~ red(`-    "b": "Bar"`) ~ `
 }
', but got '
 {
` ~ green(`+    "a": "Foo"`) ~ `
 }'`;

    const left = parseJSON(`{"a": "Foo"}`);
    const right = parseJSON(`{"b": "Bar"}`);

    left.should.equal(right)
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
    import core.exception : AssertError;

    void test()
    {
        2.should;
    }

    test.should.throwAn!AssertError("unterminated should-chain!");
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
        ("Test failed: expected value == Nullable!int.null, but got 42");
}
