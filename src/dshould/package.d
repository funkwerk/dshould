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
        should.stringcmp.equal(should, value, file, line);
    }
    else
    {
        should.basic.equal(should, value, file, line);
    }
}

auto equal(Should)(Should should)
if (isInstanceOf!(ShouldType, Should))
{
    return should.basic.equal(should);
}
