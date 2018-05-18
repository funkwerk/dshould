module dshould.empty;

import dshould.ShouldType;

unittest
{
    import dshould.basic;

    [].should.be.empty;
    [5].should.not.be.empty;
}

// empty() function moved to ShouldType due to https://issues.dlang.org/show_bug.cgi?id=18839
