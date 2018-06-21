# should
dshould is a library that implements fluent asserts using common keywords such as `should`, `not`, `be`, `equal`, `greater` and so on.
Each sentence must begin with `should`.

Note that these asserts are only examples; for instance, the word `not` can be used in any sentence.

When in doubt, use English grammar. If an intuitive combination of words does not work, please file a bug report.

# Basic use

    value.should.equal(value);

    value.should.not.equal(value);

    value.should.be.greater(value);

    value.should.be.less.equal(value);

    value.should.approximately.equal(value, error=plusminus);

    object.should.be(null);

# Arrays

    array.should.not.be(null);

    array.should.be.empty;

    array.should.equal(array);

    array.should.contain(value);

    array.should.contain.all(values);

    array.should.not.contain.any(values);

    array.should.contain.only(values);

# Strings

    string.should.not.be.empty;

    string.should.equal(string);

For strings, `equal` will use diff colors in its output - red indicates missing expected characters,
and green indicates unexpected characters.

For multiline strings, red indicates missing expected lines,
and green indicates unexpected lines.

# Exceptions

    expression.should.throwAn!Exception;

    expression.should.throwA!Throwable;

The words `throwA` and `throwAn` are identical; their only difference is grammatical.

The expression of the provided type is caught and returned, and may be accessed with the property `.where`.

    expression.should.throwAn!Exception.where.msg.should.equal("Assertion failed!");

# Extensions

`should` can be extended by defining further functions representing words.
This takes the form:

    import dshould.ShouldType;

    // for nonterminal words, such as 'not':

    auto <word>(Should)(Should should)
    if (isInstanceOf!(ShouldType, Should))
    {
        ...
    }

    // for terminal words, such as 'equal':

    void <word>(Should, T)(Should should, T expected,
                           Fence _ = Fence(), string file = __FILE__, size_t line = __LINE__)
    if (isInstanceOf!(ShouldType, Should))
    {
    }

The `Fence` parameter is used to fence off the file/line parameters from parameters provided by users.
It ensures that the `file` parameter is never provided by accident, for instance if a user falsely believes that a
function takes a string argument.

The `should` parameter has the following properties:

 * `should.addWord!"word"` to add a word to the current sentence.

 * `should.hasWord!"word"` to check if a word appears in the current sentence.

 * `should.allowOnlyWords!("word", "word").before!"this word"` to limit the permissible words to appear before this word.

 * `should.requireWord!"word".before!"this word"` to require that a word appear before this one.

 * `should.got()` to evaluate the left-hand side of the `should` sentence, ie. the expression appearing before `.should`.

 * `check(condition, expectedMessage, butGotMessage, file, line)` to actually check the `should` condition.
