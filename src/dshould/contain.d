module dshould.contain;

import dshould.ShouldType;
import dshould.basic : not, should;
import std.traits : isAssociativeArray;

/**
 * The word `.contain` takes one value, expected to appear in the range on the left hand side.
 */
public void contain(Should, T)(Should should, T expected, Fence _ = Fence(), string file = __FILE__, size_t line = __LINE__)
if (isInstanceOf!(ShouldType, Should))
{
    should.allowOnlyWords!("not", "only").before!"contain";

    should.addWord!"contain".checkContain(expected, file, line);
}

///
unittest
{
    [2, 3, 4].should.contain(3);
    [2, 3, 4].should.not.contain(5);
}

public auto contain(Should)(Should should)
if (isInstanceOf!(ShouldType, Should))
{
    should.allowOnlyWords!("not").before!"contain";

    return should.addWord!"contain";
}

/**
 * The phrase `.contain.only` or `.only.contain` takes a range, the elements of which are expected to be the only
 * elements appearing in the range on the left hand side.
 */
public void only(Should, T)(Should should, T expected, Fence _ = Fence(), string file = __FILE__, size_t line = __LINE__)
if (isInstanceOf!(ShouldType, Should))
{
    should.requireWord!"contain".before!"only";
    should.allowOnlyWords!("not", "contain").before!"only";

    should.addWord!"only".checkContain(expected, file, line);
}

///
unittest
{
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

/**
 * The phrase `.contain.all` takes a range, all elements of which are expected to appear
 * in the range on the left hand side.
 */
public void all(Should, T)(Should should, T expected, Fence _ = Fence(), string file = __FILE__, size_t line = __LINE__)
if (isInstanceOf!(ShouldType, Should))
{
    should.requireWord!"contain".before!"all";
    should.allowOnlyWords!("not", "contain").before!"all";

    should.addWord!"all".checkContain(expected, file, line);
}

///
unittest
{
    [2, 3, 4].should.contain.all([3]);
    [2, 3, 4].should.contain.all([4, 3]);
    [2, 3, 4].should.not.contain.all([3, 4, 5]);
}

/**
 * The phrase `.contain.any` takes a range, at least one element of which is expected to appear
 * in the range on the left hand side.
 */
public void any(Should, T)(Should should, T expected, Fence _ = Fence(), string file = __FILE__, size_t line = __LINE__)
if (isInstanceOf!(ShouldType, Should))
{
    should.requireWord!"contain".before!"any";
    should.allowOnlyWords!("not", "contain").before!"any";

    should.addWord!"any".checkContain(expected, file, line);
}

///
unittest
{
    [2, 3, 4].should.contain.any([4, 5]);
    [2, 3, 4].should.not.contain.any([5, 6]);
}

unittest
{
    const int[] constArray = [2, 3, 4];

    constArray.should.contain(4);
}

unittest
{
    string[string] assocArray = ["a": "b"];

    assocArray.should.contain.all(["a": "b"]);
    assocArray.should.not.contain.any(["a": "y"]);
    assocArray.should.not.contain.any(["x": "b"]);
}

private void checkContain(Should, T)(Should should, T expected, string file, size_t line)
if (isInstanceOf!(ShouldType, Should) && isAssociativeArray!T && is(const typeof(should.got()) == const T))
{
    import std.algorithm : any, all, canFind;
    import std.format : format;

    alias pairEqual = (a, b) => a.key == b.key && a.value == b.value;

    with (should)
    {
        auto got = should.got();
        alias inExpected = a => expected.byKeyValue.canFind!pairEqual(a);
        alias inGot = a => got.byKeyValue.canFind!pairEqual(a);

        static if (hasWord!"only")
        {
            static if (hasWord!"not")
            {
                check(
                    !got.byKeyValue.all!inExpected,
                    format("associative array containing pairs other than %s", expected),
                    format("%s", got),
                    file, line);
            }
            else
            {
                check(
                    got.byKeyValue.all!inExpected,
                    format("associative array containing only the pairs %s", expected),
                    format("%s", got),
                    file, line);
            }
        }
        else static if (hasWord!"all")
        {
            static if (hasWord!"not")
            {
                check(
                    !expected.byKeyValue.all!inGot,
                    format("associative array not containing every pair in %s", expected),
                    format("%s", got),
                    file, line);
            }
            else
            {
                check(
                    expected.byKeyValue.all!inGot,
                    format("associative array containing every pair in %s", expected),
                    format("%s", got),
                    file, line);
            }
        }
        else static if (hasWord!"any")
        {
            static if (hasWord!"not")
            {
                check(
                    !expected.byKeyValue.any!inGot,
                    format("associative array not containing any pair in %s", expected),
                    format("%s", got),
                    file, line);
            }
            else
            {
                check(
                    expected.byKeyValue.any!inGot,
                    format("associative array containing any pair of %s", expected),
                    format("%s", got),
                    file, line);
            }
        }
        else
        {
            static assert(false,
                `bad grammar: expected "contain all", "contain any", "contain only" (or "only contain")`);
        }
    }
}

private void checkContain(Should, T)(Should should, T expected, string file, size_t line)
if (isInstanceOf!(ShouldType, Should) && !isAssociativeArray!T)
{
    import std.algorithm : any, all, canFind;
    import std.format : format;
    import std.range : ElementType, save;

    with (should)
    {
        auto got = should.got();

        enum rhsIsValue = is(const T == const ElementType!(typeof(got)));

        static if (rhsIsValue)
        {
            allowOnlyWords!("not", "only", "contain").before!"contain";

            static if (hasWord!"only")
            {
                static if (hasWord!"not")
                {
                    check(
                        got.any!(a => a != expected),
                        format("array containing values other than %s", expected),
                        format("%s", got),
                        file, line);
                }
                else
                {
                    check(
                        got.all!(a => a == expected),
                        format("array containing only the value %s", expected),
                        format("%s", got),
                        file, line);
                }
            }
            else
            {
                static if (hasWord!"not")
                {
                    check(
                        !got.save.canFind(expected),
                        format("array not containing %s", expected),
                        format("%s", got),
                        file, line);
                }
                else
                {
                    check(
                        got.save.canFind(expected),
                        format("array containing %s", expected),
                        format("%s", got),
                        file, line);
                }
            }
        }
        else
        {
            static if (hasWord!"only")
            {
                static if (hasWord!"not")
                {
                    check(
                        !got.all!(a => expected.save.canFind(a)),
                        format("array containing values other than %s", expected),
                        format("%s", got),
                        file, line);
                }
                else
                {
                    check(
                        got.all!(a => expected.save.canFind(a)),
                        format("array containing only the values %s", expected),
                        format("%s", got),
                        file, line);
                }
            }
            else static if (hasWord!"all")
            {
                static if (hasWord!"not")
                {
                    check(
                        !expected.all!(a => got.save.canFind(a)),
                        format("array not containing every value in %s", expected),
                        format("%s", got),
                        file, line);
                }
                else
                {
                    check(
                        expected.all!(a => got.save.canFind(a)),
                        format("array containing every value in %s", expected),
                        format("%s", got),
                        file, line);
                }
            }
            else static if (hasWord!"any")
            {
                static if (hasWord!"not")
                {
                    check(
                        !expected.any!(a => got.save.canFind(a)),
                        format("array not containing any value in %s", expected),
                        format("%s", got),
                        file, line);
                }
                else
                {
                    check(
                        expected.any!(a => got.save.canFind(a)),
                        format("array containing any value of %s", expected),
                        format("%s", got),
                        file, line);
                }
            }
            else
            {
                static assert(false,
                    `bad grammar: expected "contain all", "contain any", "contain only" (or "only contain")`);
            }
        }
    }
}

unittest
{
    const foo = ["foo": "bar"];

    foo.byKey.should.contain("foo");
    foo.byValue.should.contain("bar");
}
