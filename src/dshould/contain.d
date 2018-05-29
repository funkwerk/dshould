module dshould.contain;

import dshould.ShouldType;

unittest
{
    import dshould.basic : not, should;

    [2, 3, 4].should.contain.all([3]);
    [2, 3, 4].should.contain(3);
    [2, 3, 4].should.contain.all([4, 3]);
    [2, 3, 4].should.not.contain.any([5, 6]);
    [2, 3, 4].should.not.contain(5);
    [2, 3, 4].should.not.contain.all([3, 4, 5]);
    [3, 4].should.only.contain([4, 3]);
    [3, 4].should.only.contain([1, 2, 3, 4]);
    [3, 4].should.contain.only([4, 3]);
    [2, 3, 4].should.not.only.contain([4, 3]);
}

public auto only(Should)(Should should)
if (isInstanceOf!(ShouldType, Should))
{
    should.allowOnlyWords!("not").before!"only";

    return should.addWord!"only";
}

public void contain(Should, T)(Should should, T expected, string file = __FILE__, size_t line = __LINE__)
if (isInstanceOf!(ShouldType, Should))
{
    should.allowOnlyWords!("not", "only").before!"contain";

    should.addWord!"contain".checkContain(expected, file, line);
}

public auto contain(Should)(Should should)
if (isInstanceOf!(ShouldType, Should))
{
    should.allowOnlyWords!("not").before!"contain";

    return should.addWord!"contain";
}

public void all(Should, T)(Should should, T expected, string file = __FILE__, size_t line = __LINE__)
if (isInstanceOf!(ShouldType, Should))
{
    should.requireWord!"contain".before!"all";
    should.allowOnlyWords!("not", "contain").before!"all";

    should.addWord!"all".checkContain(expected, file, line);
}

public void any(Should, T)(Should should, T expected, string file = __FILE__, size_t line = __LINE__)
if (isInstanceOf!(ShouldType, Should))
{
    should.requireWord!"contain".before!"any";
    should.allowOnlyWords!("not", "contain").before!"any";

    should.addWord!"any".checkContain(expected, file, line);
}

public void only(Should, T)(Should should, T expected, string file = __FILE__, size_t line = __LINE__)
if (isInstanceOf!(ShouldType, Should))
{
    should.requireWord!"contain".before!"only";
    should.allowOnlyWords!("not", "contain").before!"only";

    should.addWord!"only".checkContain(expected, file, line);
}

private void checkContain(Should, T)(Should should, T expected, string file, size_t line)
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
            allowOnlyWords!("not", "only", "contain").before!"contain";

            static if (hasWord!"only")
            {
                static if (hasWord!"not")
                {
                    mixin(genCheck!("%s.any!(a => a != %s)", ["got", "expected"]));
                }
                else
                {
                    mixin(genCheck!("%s.all!(a => a == %s)", ["got", "expected"]));
                }
            }
            else
            {
                static if (hasWord!"not")
                {
                    mixin(genCheck!("!%s.canFind(%s)", ["got", "expected"]));
                }
                else
                {
                    mixin(genCheck!("%s.canFind(%s)", ["got", "expected"]));
                }
            }
        }
        else
        {
            static if (hasWord!"only")
            {
                static if (hasWord!"not")
                {
                    mixin(genCheck!("!%s.all!(a => %s.canFind(a))", ["got", "expected"]));
                }
                else
                {
                    mixin(genCheck!("%s.all!(a => %s.canFind(a))", ["got", "expected"]));
                }
            }
            else static if (hasWord!"all")
            {
                static if (hasWord!"not")
                {
                    mixin(genCheck!("!%s.all!(a => %s.canFind(a))", ["expected", "got"]));
                }
                else
                {
                    mixin(genCheck!("%s.all!(a => %s.canFind(a))", ["expected", "got"]));
                }
            }
            else static if (hasWord!"any")
            {
                static if (hasWord!"not")
                {
                    mixin(genCheck!("!%s.any!(a => %s.canFind(a))", ["expected", "got"]));
                }
                else
                {
                    mixin(genCheck!("%s.any!(a => %s.canFind(a))", ["expected", "got"]));
                }
            }
            else
            {
                static assert(false,
                    `bad grammar: expected "all", "any" or "only" before "contain"`);
            }
        }
    }
}
