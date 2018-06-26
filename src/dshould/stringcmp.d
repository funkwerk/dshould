module dshould.stringcmp;

import std.algorithm : EditOp, map;
import std.format : format;
import std.range;
import std.typecons;
import dshould.ShouldType;
import dshould.basic;

/**
 * Given string types, this version of the word `.equal` implements color-coded diffs.
 * <b>There is no need to call this directly</b> - simply `import dshould;` the right function will be called automatically.
 */
public void equal(Should, T)(Should should, T expected, Fence _ = Fence(), string file = __FILE__, size_t line = __LINE__)
if (isInstanceOf!(ShouldType, Should) && is(T == string))
{
    should.allowOnlyWords!().before!"equal (string)";

    should.addWord!"equal".stringCmp(expected, file, line);
}

private void stringCmp(Should, T)(Should should, T expected, string file, size_t line)
if (isInstanceOf!(ShouldType, Should))
{
    import std.algorithm : canFind;

    should.allowOnlyWords!("equal").before!"equal (string)";

    should.terminateChain;

    auto got = should.got();

    if (got != expected)
    {
        string original;
        string diff;

        if (got.canFind("\n"))
        {
            auto diffPair = multiLineDiff(expected.split("\n"), got.split("\n"));

            original = diffPair.original.join("\n") ~ "\n";
            diff = "\n" ~ diffPair.target.join("\n");
        }
        else
        {
            auto diffPair = oneLineDiff(expected, got);

            original = diffPair.original;
            diff = diffPair.target;
        }

        throw new FluentException(
            format!`'%s'`(original),
            format!`'%s'`(diff),
            file, line
        );
    }
}

private auto oneLineDiff(string expected, string text) @safe
{
    alias removePred = text => red(text);
    alias addPred = text => green(text);
    alias keepPred = text => text;
    alias ditchPred = lines => string.init;

    auto originalColored = colorizedDiff!(string, removePred, ditchPred, keepPred)(expected, text);
    auto targetColored = colorizedDiff!(string, ditchPred, addPred, keepPred)(expected, text);

    alias DiffPair = Tuple!(string, "original", string, "target");

    if (originalColored.isNull)
    {
        return DiffPair(expected, text);
    }
    else
    {
        return DiffPair(originalColored.get, targetColored.get);
    }
}

@("collates successive replacements")
unittest
{
    const expectedOriginal = "Hello W" ~ red("or") ~ "ld";
    const expectedTarget = "Hello W" ~ green("ey") ~ "ld";
    const diff = "Hello World".oneLineDiff("Hello Weyld");

    (diff.original ~ diff.target).should.equal(expectedOriginal ~ expectedTarget);
}

@("does not colorize diff view for strings that are too different")
unittest
{
    const diff = "Hello World".oneLineDiff("Goodbye Universe");

    (diff.original ~ diff.target).should.equal("Hello WorldGoodbye Universe");
}

@("tries to not change diff mode too often")
unittest
{
    const cleanDiff = `method="` ~ GREEN_CODE ~ `multiply` ~ CLEAR_CODE ~ `"`;

    `method="update"`.oneLineDiff(`method="multiply"`).target.should.equal(cleanDiff);
}

unittest
{
    const originalText = "test";
    const targetText = "test, but";

    with (originalText.oneLineDiff(targetText))
    {
        (original ~ target).should.equal(originalText ~ originalText ~ green(", but"));
    }
}

private auto multiLineDiff(string[] expected, string[] text) @safe
{
    alias removePred = lines => lines.map!(line => red("-" ~ line));
    alias addPred = lines => lines.map!(line => green("+" ~ line));
    alias keepPred = lines => lines.map!(line => " " ~ line);
    alias ditchPred = lines => (string[]).init;

    auto originalColored = colorizedDiff!(string[], removePred, ditchPred, keepPred)(expected, text);
    auto targetColored = colorizedDiff!(string[], ditchPred, addPred, keepPred)(expected, text);

    alias DiffPair = Tuple!(string[], "original", string[], "target");

    if (originalColored.isNull)
    {
        return DiffPair(expected, text);
    }
    else
    {
        return DiffPair(originalColored.get, targetColored.get);
    }
}

@("supports multiline diff")
unittest
{
    import std.string : join, split;

    // given
    const originalText = `{
        "int": 1,
        "array": ["XX"],
        "timecodeBegin": "2003-02-01T12:00:00Z",
        "timecodeEnd": "2003-02-01T14:00:00Z",
        "enum": "ENUM",
        "lastEntry": "goodbye"
    }`;
    const modifiedText = `{
        "int": 1,
        "array": ["XX"],
        "enum": "ENUM",
        "somethingElse": "goes here",
        "lastEntry": "goodbye"
    }`;

    // then
    const patchTextOriginal = ` {
         "int": 1,
         "array": ["XX"],
` ~ red(`-        "timecodeBegin": "2003-02-01T12:00:00Z",`) ~ `
` ~ red(`-        "timecodeEnd": "2003-02-01T14:00:00Z",`) ~ `
         "enum": "ENUM",
         "lastEntry": "goodbye"
     }`;

    const patchTextTarget = ` {
         "int": 1,
         "array": ["XX"],
         "enum": "ENUM",
` ~ green(`+        "somethingElse": "goes here",`) ~ `
         "lastEntry": "goodbye"
     }`;

    const diff = originalText.split("\n").multiLineDiff(modifiedText.split("\n"));

    (diff.original.join("\n") ~ diff.target.join("\n")).should.equal(patchTextOriginal ~ patchTextTarget);
}

// TODO bracket crossing cost
private Nullable!T colorizedDiff(T, alias removePred, alias addPred, alias keepPred)(T expected, T text) @trusted
{
    import std.algorithm : count;
    import std.array : Appender, empty;
    import std.range : dropOne, front;

    Appender!T diff;
    diff.reserve(text.length);

    // preds are called with continuous runs
    Appender!(ElementType!T[]) addBuffer;
    Appender!(ElementType!T[]) removeBuffer;

    auto levenshtein = Levenshtein!T(expected, text);
    const path = levenshtein.reconstructPath;

    if (path.count!(a => a != EditOp.none) > text.length)
    {
        return Nullable!T.init; // no diff view, too different
    }

    void flushAdd()
    {
        if (!addBuffer.data.empty)
        {
            diff ~= addPred(addBuffer.data);
            addBuffer.clear;
        }
    }

    void flushRemove()
    {
        if (!removeBuffer.data.empty)
        {
            diff ~= removePred(removeBuffer.data);
            removeBuffer.clear;
        }
    }

    void add(ElementType!T element)
    {
        flushRemove;
        addBuffer ~= element;
    }

    void remove(ElementType!T element)
    {
        flushAdd;
        removeBuffer ~= element;
    }

    void flush()
    {
        flushRemove;
        flushAdd;
    }

    void same(ElementType!T element)
    {
        flush;
        diff ~= keepPred([element]);
    }

    foreach (editOp; path)
    {
        final switch (editOp)
        {
            case EditOp.none:
                same(text.front);
                text = text.dropOne;
                expected = expected.dropOne;
                break;
            case EditOp.insert:
                add(text.front);
                text = text.dropOne;
                break;
            case EditOp.remove:
                remove(expected.front);
                expected = expected.dropOne;
                break;
            case EditOp.substitute:
                assert(false);
        }
    }

    assert(text.empty, format!`leftover %s`(text));
    assert(expected.empty);

    flush;

    return diff.data.nullable;
}

private auto red(T)(T text)
{
    return RED_CODE ~ text ~ CLEAR_CODE;
}

private auto green(T)(T text)
{
    return GREEN_CODE ~ text ~ CLEAR_CODE;
}

private enum RED_CODE = "\x1b[31m";
private enum GREEN_CODE = "\x1b[32m";
private enum CLEAR_CODE = "\x1b[39m";

/**
 * Modified Levenshtein distance from from std.algorithm
 * Given two ranges, returns a sequence of insertions and deletions
 * that turn the first range into the second.
 * This is equivalent to diff computation, though it's
 * comparatively inefficient at O(n^2) memory and runtime.
 *
 * This version adds customizable path cost, used to implement orphan avoidance.
 */
private struct Levenshtein(Range)
{
    @disable this();

    public this(Range s, Range t)
    {
        import std.algorithm : min;

        const slen = walkLength(s.save);
        const tlen = walkLength(t.save);

        this.rows = slen + 1;
        this.cols = tlen + 1;
        this.matrixData = new Cell[this.rows * this.cols];
        initMatrix;

        foreach (i; 1 .. this.rows)
        {
            const sFront = s.front;
            auto tCurrent = t.save;

            foreach (j; 1 .. this.cols)
            {
                auto costInsertion = this.matrix(i, j - 1).cost + insertionIncrement
                    + pathCost(EditOp.insert, i, j);
                auto costDeletion = this.matrix(i - 1, j).cost + deletionIncrement
                    + pathCost(EditOp.remove, i, j);
                auto costNone = (sFront != tCurrent.front)
                    ? float.infinity
                    : (this.matrix(i - 1, j - 1).cost + pathCost(EditOp.none, i, j));

                tCurrent.popFront();

                Cell cell;

                if (costNone <= costDeletion)
                {
                    if (costNone <= costInsertion)
                    {
                        cell = Cell(costNone, EditOp.none);
                    }
                    else
                    {
                        cell = Cell(costInsertion, EditOp.insert);
                    }
                }
                else
                {
                    if (costDeletion <= costInsertion)
                    {
                        cell = Cell(costDeletion, EditOp.remove);
                    }
                    else
                    {
                        cell = Cell(costInsertion, EditOp.insert);
                    }
                }

                matrix(i, j) = cell;
            }
            s.popFront();
        }
    }

    private float pathCost(EditOp proposedOp, size_t i, size_t j)
    {
        import std.algorithm : countUntil, endsWith, equal, filter, startsWith;

        alias step = (a, n) {
            auto cell = a[n - 1];

            if (cell.i == 0 && cell.j == 0)
            {
                assert(cell.op == EditOp.none);

                return cell;
            }

            moveByOp(cell.op, cell.i, cell.j);

            return typeof(cell)(matrix(cell.i, cell.j).op, cell.i, cell.j);
        };

        auto trace = tuple!("op", "i", "j")(proposedOp, i, j).recurrence!step.map!(a => a.op);
        auto traceInsert = trace.filter!(op => op == EditOp.insert || op == EditOp.none);
        auto traceRemove = trace.filter!(op => op == EditOp.remove || op == EditOp.none);

        // significantly penalize orphaned "no change" lines
        alias orphan = op => only(op, EditOp.none, op);
        const orphanPathCost =
            traceInsert.startsWith(orphan(EditOp.insert)) ? orphanCost : 0 +
            traceRemove.startsWith(orphan(EditOp.remove)) ? orphanCost : 0;

        // slightly penalize mode changes, to avoid pathologies arising from distant matches
        const pathChangesModeCost =
            traceInsert.startsWith(only(EditOp.none, EditOp.insert)) ? modeChangeCost : 0 +
            traceRemove.startsWith(only(EditOp.none, EditOp.remove)) ? modeChangeCost : 0;

        return orphanPathCost + pathChangesModeCost;
    }

    public EditOp[] reconstructPath()
    {
        import std.algorithm.mutation : reverse;

        EditOp[] result;
        size_t i = this.rows - 1;
        size_t j = this.cols - 1;

        while (i > 0 || j > 0)
        {
            const op = matrix(i, j).op;

            result ~= op;
            moveByOp(op, i, j);
        }
        reverse(result);
        return result;
    }

    private void moveByOp(EditOp op, ref size_t i, ref size_t j)
    in
    {
        assert(i > 0 || j > 0);
    }
    do
    {
        final switch (op)
        {
            case EditOp.none:
                i--;
                j--;
                break;
            case EditOp.insert:
                j--;
                break;
            case EditOp.remove:
                i--;
                break;
            case EditOp.substitute:
                assert(false);
        }
    }

    private enum deletionIncrement = 1;
    private enum insertionIncrement = 1;
    private enum orphanCost = 2.5;
    private enum modeChangeCost = 0.05;

    private alias Cell = Tuple!(float, "cost", EditOp, "op");
    private Cell[] matrixData = null;
    private size_t rows = 0;
    private size_t cols = 0;

    invariant
    {
        assert(matrixData.length == rows * cols);
    }

    // Treat _matrix as a rectangular array
    private ref Cell matrix(size_t row, size_t col)
    in
    {
        assert(row >= 0 && row < this.rows);
        assert(col >= 0 && col < this.cols);
    }
    do
    {
        return this.matrixData[row * this.cols + col];
    }

    private void initMatrix()
    {
        this.matrixData[] = Cell(0, EditOp.none);

        foreach (r; 1 .. rows)
        {
            this.matrix(r, 0) = Cell(r * deletionIncrement, EditOp.remove);
        }

        foreach (c; 1 .. cols)
        {
            this.matrix(0, c) = Cell(c * insertionIncrement, EditOp.insert);
        }
    }
}
