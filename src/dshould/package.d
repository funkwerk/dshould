module dshould;

import dshould.ShouldType;

public import dshould.basic;
public import dshould.contain;
public import dshould.empty;
public import dshould.stringcmp;
public import dshould.thrown;

// dispatch based on type
void equal(Should, T)(Should should, T value, string file = __FILE__, size_t line = __LINE__)
if (isInstanceOf!(ShouldType, Should))
{
    static if (is(typeof(should.data.lhs()) == string) && is(T == string) && !Should.hasWord!"not")
    {
        dshould.stringcmp.equal(should, value, file, line);
    }
    else
    {
        dshould.basic.equal(should, value, file, line);
    }
}

auto equal(Should)(Should should)
if (isInstanceOf!(ShouldType, Should))
{
    return should.basic.equal(should);
}

@("prints informative errors for int comparison")
unittest
{
    2.should.be(3).should.throwA!FluentException.message.should.equal("test failed: expected 3, but got 2");
}

@("prints informative errors for object comparison")
unittest
{
    Object obj;

    obj.should.not.be(null)
        .should.throwA!FluentException.message.should.equal("test failed: expected non-null, but got null");

    obj = new Object;

    obj.should.be(null)
        .should.throwA!FluentException.message.should.equal("test failed: expected null, but got object.Object");
}

@("prints informative errors for inequalities")
unittest
{
    2.should.be.greater.equal(5)
        .should.throwA!FluentException.message.should.equal("test failed: expected value >= 5, but got 2");
}

@("prints informative errors for array emptiness")
unittest
{
    [].should.not.be.empty
        .should.throwA!FluentException.message.should.equal("test failed: ![].empty");

    [5].should.be.empty
        .should.throwA!FluentException.message.should.equal("test failed: [5].empty");
}
