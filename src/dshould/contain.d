module dshould.contain;

import dshould.ShouldType;

unittest
{
    import dshould.basic : not, should;

    [2, 3, 4].should.contain([3]);
    [2, 3, 4].should.contain([4, 3]);
    [2, 3, 4].should.not.contain([5]);
    [3, 4].should.only.contain([4, 3]);
    [3, 4].should.only.contain([1, 2, 3, 4]);
    [3, 4].should.contain.only([4, 3]);
    [2, 3, 4].should.not.only.contain([4, 3]);
}

auto only(Should)(Should should)
if (isInstanceOf!(ShouldType, Should))
{
    should.allowOnlyWordsBefore!(["not"], "only");

    return should.addWord!"only";
}

void contain(Should, T)(Should should, T set, string file = __FILE__, size_t line = __LINE__)
if (isInstanceOf!(ShouldType, Should))
{
    should.allowOnlyWordsBefore!(["not", "only"], "contain");

    should.addWord!"contain".addData!"rhs"(set).checkContain(file, line);
}

auto contain(Should)(Should should)
if (isInstanceOf!(ShouldType, Should))
{
    should.allowOnlyWordsBefore!(["not"], "contain");

    return should.addWord!"contain";
}

void only(Should, T)(Should should, T set, string file = __FILE__, size_t line = __LINE__)
if (isInstanceOf!(ShouldType, Should))
{
    should.requireWord!("contain", "only");
    should.allowOnlyWordsBefore!(["not", "contain"], "only");

    should.addWord!"only".addData!"rhs"(set).checkContain(file, line);
}

void checkContain(Should)(Should should, string file, size_t line)
if (isInstanceOf!(ShouldType, Should))
{
    import std.algorithm : any, all, canFind;
    import std.range : ElementType;

    with (should)
    {
        auto lhsValue = data.lhs();
        enum rhsIsValue = is(typeof(data.rhs) == ElementType!(typeof(lhsValue)));

        static if (rhsIsValue)
        {
            static if (Should.hasWord!"only")
            {
                static if (Should.hasWord!"not")
                {
                    mixin(gencheck!("%s.any!(a => a != %s)", ["lhsValue", "rhs"]));
                }
                else
                {
                    mixin(gencheck!("%s.all!(a => a == %s)", ["lhsValue", "rhs"]));
                }
            }
            else
            {
                static if (Should.hasWord!"not")
                {
                    mixin(gencheck!("!%s.canFind(%s)", ["lhsValue", "rhs"]));
                }
                else
                {
                    mixin(gencheck!("%s.canFind(%s)", ["lhsValue", "rhs"]));
                }
            }
        }
        else
        {
            static if (Should.hasWord!"only")
            {
                static if (Should.hasWord!"not")
                {
                    mixin(gencheck!("%s.any!(a => !%s.canFind(a))", ["lhsValue", "rhs"]));
                }
                else
                {
                    mixin(gencheck!("%s.all!(a => %s.canFind(a))", ["lhsValue", "rhs"]));
                }
            }
            else
            {
                static if (Should.hasWord!"not")
                {
                    mixin(gencheck!("%s.all!(a => !%s.canFind(a))", ["rhs", "lhsValue"]));
                }
                else
                {
                    mixin(gencheck!("%s.all!(a => %s.canFind(a))", ["rhs", "lhsValue"]));
                }
            }
        }
    }
}
