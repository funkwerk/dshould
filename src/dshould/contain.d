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

void contain(Should, T)(Should should, T expected, string file = __FILE__, size_t line = __LINE__)
if (isInstanceOf!(ShouldType, Should))
{
    should.allowOnlyWordsBefore!(["not", "only"], "contain");

    should.addWord!"contain".checkContain(expected, file, line);
}

auto contain(Should)(Should should)
if (isInstanceOf!(ShouldType, Should))
{
    should.allowOnlyWordsBefore!(["not"], "contain");

    return should.addWord!"contain";
}

void only(Should, T)(Should should, T expected, string file = __FILE__, size_t line = __LINE__)
if (isInstanceOf!(ShouldType, Should))
{
    should.requireWord!("contain", "only");
    should.allowOnlyWordsBefore!(["not", "contain"], "only");

    should.addWord!"only".checkContain(expected, file, line);
}

void checkContain(Should, T)(Should should, T expected, string file, size_t line)
if (isInstanceOf!(ShouldType, Should))
{
    import std.algorithm : any, all, canFind;
    import std.range : ElementType;

    with (should)
    {
        auto got = should.got();

        enum rhsIsValue = is(T == ElementType!(typeof(got)));

        static if (rhsIsValue)
        {
            static if (hasWord!"only")
            {
                static if (hasWord!"not")
                {
                    mixin(gencheck!("%s.any!(a => a != %s)", ["got", "expected"]));
                }
                else
                {
                    mixin(gencheck!("%s.all!(a => a == %s)", ["got", "expected"]));
                }
            }
            else
            {
                static if (hasWord!"not")
                {
                    mixin(gencheck!("!%s.canFind(%s)", ["got", "expected"]));
                }
                else
                {
                    mixin(gencheck!("%s.canFind(%s)", ["got", "expected"]));
                }
            }
        }
        else
        {
            static if (hasWord!"only")
            {
                static if (hasWord!"not")
                {
                    mixin(gencheck!("%s.any!(a => !%s.canFind(a))", ["got", "expected"]));
                }
                else
                {
                    mixin(gencheck!("%s.all!(a => %s.canFind(a))", ["got", "expected"]));
                }
            }
            else
            {
                static if (hasWord!"not")
                {
                    mixin(gencheck!("%s.all!(a => !%s.canFind(a))", ["expected", "got"]));
                }
                else
                {
                    mixin(gencheck!("%s.all!(a => %s.canFind(a))", ["expected", "got"]));
                }
            }
        }
    }
}
