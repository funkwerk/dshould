module dshould.prettyprint;

import std.algorithm;
import std.range;
import std.typecons;

/**
 * This function takes the input text and returns a pretty-printed, multiline, indented version.
 * It assumes that the input text is the output of toString and forms a valid comma separated paren tree.
 *
 * A comma separated paren tree is a string that contains a balanced number of quotation marks, parentheses
 * and brackets.
 */
public string prettyprint(const string text, size_t columnLength = 80)
{
    const tree = text.parse;

    if (tree.isNull)
    {
        return text;
    }

    return tree.get.prettyprint(columnLength);
}

///
@("pretty print a string")
unittest
{
    import dshould : equal, should;

    prettyprint("Foo()").should.equal("Foo()");
    prettyprint("Foo(Bar(Baz()), Baq())", 16).should.equal(
"Foo(
    Bar(Baz()),
    Baq()
)");
    prettyprint("Foo(Bar(Baz()), Baq())", 13).should.equal(
"Foo(
    Bar(
        Baz()
    ),
    Baq()
)");
}

private enum indent = "    ";

private string prettyprint(const Tree tree, size_t width)
{
    import std.string : stripLeft;

    Appender!string result;

    // skip prefix so caller can decide whether or not to strip
    void walkOneLine(const Tree tree)
    {
        if (tree.parenType.isNull)
        {
            return;
        }
        result ~= tree.parenType.get.opening;
        tree.children.enumerate.each!((index, child) {
            if (index > 0)
            {
                result ~= ",";
            }
            result ~= child.prefix;
            walkOneLine(child);
        });
        result ~= tree.parenType.get.closing;
    }

    void walk(size_t level, const Tree tree)
    {
        if (!tree.lengthExceeds(width - level * indent.length))
        {
            result ~= tree.prefix.stripLeft;
            walkOneLine(tree);
            return;
        }

        result ~= tree.prefix.stripLeft;
        if (tree.parenType.isNull)
        {
            return;
        }
        result ~= tree.parenType.get.opening;
        tree.children.enumerate.each!((index, child) {
            if (index > 0)
            {
                result ~= ",";
            }
            result ~= "\n";
            (level + 1).iota.each!((_) { result ~= indent; });
            walk(level + 1, child);
        });
        result ~= "\n";
        level.iota.each!((_) { result ~= indent; });
        result ~= tree.parenType.get.closing;
    }
    walk(0, tree);
    return result.data;
}

private Nullable!Tree parse(string text)
{
    auto textRange = text.quoted;
    auto result = parse(textRange);

    if (!textRange.empty)
    {
        return Nullable!Tree();
    }

    return result;
}

@("parse a paren expression to a tree")
unittest
{
    import dshould : equal, should;

    parse("Foo").should.equal(Tree("Foo").nullable);
    parse(`"Foo"`).should.equal(Tree(`"Foo"`).nullable);
    parse("Foo,").should.equal(Nullable!Tree());
    parse("Foo, Bar").should.equal(Nullable!Tree());
    parse("Foo()").should.equal(Tree("Foo", ParenType.paren.nullable));
    parse("Foo[a, b]").should.equal(Tree(
        "Foo",
        ParenType.squareBracket.nullable,
        [Tree("a"), Tree(" b")]).nullable);
    parse(`Foo{"\""}`).should.equal(Tree(
        "Foo",
        ParenType.curlyBracket.nullable,
        [Tree(`"\""`)]).nullable);
}

private Nullable!Tree parse(ref QuotedText textRange)
{
    auto parenStart = textRange.findAmong("({[");
    auto closer = textRange.findAmong(",)}]");

    if (textRange.textUntil(closer).length < textRange.textUntil(parenStart).length)
    {
        const prefix = textRange.textUntil(closer);

        textRange = closer;
        return Tree(prefix).nullable;
    }

    const prefix = textRange.textUntil(parenStart);

    if (parenStart.empty)
    {
        textRange = parenStart;
        return Tree(prefix).nullable;
    }

    const parenType = () {
        switch (parenStart.front)
        {
            case '(':
                return ParenType.paren;
            case '[':
                return ParenType.squareBracket;
            case '{':
                return ParenType.curlyBracket;
            default:
                assert(false);
        }
    }();

    textRange = parenStart;
    textRange.popFront;

    Tree[] children = null;

    while (true)
    {
        if (textRange.empty)
        {
            return Nullable!Tree();
        }
        if (textRange.front == parenType.closing)
        {
            // single child, quote only
            const quoteChild = textRange.textUntil(textRange);

            if (!quoteChild.empty)
            {
                children ~= Tree(quoteChild);
            }

            textRange.popFront;

            return Tree(prefix, Nullable!ParenType(parenType), children).nullable;
        }

        if (!children.empty)
        {
            if (textRange.front != ',')
            {
                return Nullable!Tree();
            }
            textRange.popFront;
        }

        auto child = parse(textRange);

        if (child.isNull)
        {
            return Nullable!Tree();
        }
        children ~= child;
    }
}

// prefix
// prefix { [child[, child]*]? }
// prefix ( [child[, child]*]? )
// prefix [ [child[, child]*]? ]
private struct Tree
{
    string prefix;

    Nullable!ParenType parenType = Nullable!ParenType();

    Tree[] children = null;

    bool lengthExceeds(size_t limit) const
    {
        return lengthRemainsOf(limit) < 0;
    }

    // returns how much remains of length after printing this. if negative, may be inaccurate.
    private ptrdiff_t lengthRemainsOf(ptrdiff_t length) const
    {
        length -= this.prefix.length;
        length -= this.parenType.isNull ? 0 : 2;
        if (length >= 0)
        {
            foreach (child; this.children)
            {
                length = child.lengthRemainsOf(length);
                if (length < 0)
                {
                    break;
                }
            }
        }
        return length;
    }
}

@("estimate the print length of a tree")
unittest
{
    import dshould : be, less, should;

    parse("Foo(Bar(Baz()), Baq())").get.lengthRemainsOf(10).should.be.less(0);
}

private enum ParenType
{
    paren, // ()
    squareBracket, // []
    curlyBracket, // {}
}

private dchar opening(const ParenType parenType)
{
    final switch (parenType)
    {
        case ParenType.paren:
            return '(';
        case ParenType.squareBracket:
            return '[';
        case ParenType.curlyBracket:
            return '{';
    }
}

private dchar closing(const ParenType parenType)
{
    final switch (parenType)
    {
        case ParenType.paren:
            return ')';
        case ParenType.squareBracket:
            return ']';
        case ParenType.curlyBracket:
            return '}';
    }
}

private QuotedText quoted(string text)
{
    return QuotedText(text);
}

// range over text that skips quoted strings
private struct QuotedText
{
    string text; // current read head after skipping quotes

    string textBeforeSkip; // current read head before skipping quotes

    this(string text)
    {
        this(text, text);
    }

    private this(string text, string textBeforeSkip)
    {
        this.text = text;
        this.textBeforeSkip = textBeforeSkip;
        skipQuote;
    }

    // return text from start until other, which must be a different range over the same text
    string textUntil(QuotedText other)
    in (other.text.ptr >= this.text.ptr && other.text.ptr <= this.text.ptr + this.text.length)
    {
        // from our skip-front to other's skip-back
        // ie. foo"test"bar
        // from   ^ to ^ is the "same" range, but returns '"test"'
        return this.textBeforeSkip[0 .. this.textBeforeSkip.length - other.text.length];
    }

    @("quote at the beginning and end of a range")
    unittest
    {
        import dshould : equal, should;

        auto range = QuotedText(`"Foo"`);

        range.textUntil(range).should.equal(`"Foo"`);
    }

    bool empty() const
    {
        return this.text.empty;
    }

    dchar front() const
    {
        return this.text.front;
    }

    QuotedText save() const
    {
        return QuotedText(this.text, this.textBeforeSkip);
    }

    void popFront()
    {
        this.text.popFront;
        this.textBeforeSkip = this.text;
        skipQuote;
    }

    private void skipQuote()
    {
        if (!this.text.empty && this.text.front == '"')
        {
           this.text.popFront; // skip opening '"'

           while (!this.text.empty && this.text.front != '"')
           {
               const bool wasEscape = this.text.front == '\\';

               this.text.popFront; // skip non-'"' character
               if (wasEscape && !this.text.empty)
               {
                   this.text.popFront; // if \", skip " as well
               }
           }
           if (!this.text.empty)
           {
               this.text.popFront; // skip closing '"'
           }
        }
    }
}
