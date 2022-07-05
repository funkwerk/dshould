module dshould.json;

import dshould.contain;
import dshould.ShouldType;
import dshould.stringcmp;
import dshould.thrown;
import std.algorithm;
import std.json;
import std.range;
import std.typecons;

/**
 * Checks if a JSON value contains another JSON value.
 * Keys that are only in the first JSON value are ignored.
 *
 * In other words, every value in the second JSON value must
 * appear in the same position in the first value.
 *
 * This satisfies the JSON convention that extraneous keys are ignored.
 */
public void json(Should)(Should should, const JSONValue expected,
    Fence _ = Fence(), string file = __FILE__, size_t line = __LINE__)
if (isInstanceOf!(ShouldType, Should))
{
    should.allowOnlyWords!("contain").before!"json";

    should.terminateChain;

    with (should)
    {
        auto got = should.got();

        if (!got.containsJson(expected))
        {
            stringCmpError(got.toPrettyString, expected.toPrettyString, No.quote, file, line);
        }
    }
}

///
@("should contain JSON")
unittest
{
    `{"a": 5, "b": 6}`.parseJSON.should.contain.json(`{}`.parseJSON);
    `{"a": 5, "b": 6}`.parseJSON.should.contain.json(`{"b": 6}`.parseJSON);
    `{"a": 5, "b": 6}`.parseJSON.should.contain.json(`{"c": 4}`.parseJSON).should.throwAn!Error;

    `{"x": {"a": 5, "b": 6}}`.parseJSON.should.contain.json(`{"x": {"b": 6}}`.parseJSON);
    `{"x": {"a": 5, "b": 6}}`.parseJSON.should.contain.json(`{"x": {"c": 4}}`.parseJSON).should.throwAn!Error;

    `{"a": 5, "b": 6}`.parseJSON.should.contain.json(`{"b": 5}`.parseJSON).should.throwAn!Error;

    `[2, 3]`.parseJSON.should.contain.json(`[2, 3]`.parseJSON);
    `[2, 3]`.parseJSON.should.contain.json(`[2]`.parseJSON).should.throwAn!Error;
}

/// ditto
public void json(string jsonString, Should)(Should should,
    Fence _ = Fence(), string file = __FILE__, size_t line = __LINE__)
if (isInstanceOf!(ShouldType, Should))
{
    enum expected = jsonString.parseJSON;

    return should.json(expected, Fence(), file, line);
}

///
@("should contain JSON literal")
unittest
{
    `{"a": 5, "b": 6}`.parseJSON.should.contain.json!`{"a": 5}`;
}

private bool containsJson(const JSONValue actual, const JSONValue expected) pure
{
    if (actual.type != expected.type)
    {
        return false;
    }

    const type = actual.type;

    if (type == JSONType.array)
    {
        return (actual.array.length == expected.array.length) &&
            actual.array.length.iota.all!(i => actual.array[i].containsJson(expected.array[i]));
    }
    if (type == JSONType.object)
    {
        return expected.object.byKey
            .all!(key => (key in actual.object) && actual.object[key].containsJson(expected.object[key]));
    }
    return actual == expected;
}
