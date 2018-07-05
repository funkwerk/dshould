module dshould.stringcmp;

import std.algorithm : map;
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
    const cleanDiff = `method="` ~ green(`multiply`) ~ `"`;

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

@("supports comparison of large strings")
unittest
{
    import std.string : join, split;

    // given
    const repetitions = 500/"Hello World".length;
    const originalText = `Hello World`.repeat(repetitions).join ~ `AAA` ~ `Hello World`.repeat(repetitions).join;
    const modifiedText = `Hello World`.repeat(repetitions).join ~ `BBB` ~ `Hello World`.repeat(repetitions).join;

    originalText.oneLineDiff(modifiedText); // should terminate in an acceptable timespan
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

    if (path.count!(a => a != levenshtein.EditOp.Type.keep) > text.length)
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
            case levenshtein.EditOp.Type.keep:
                same(text.front);
                text = text.dropOne;
                expected = expected.dropOne;
                break;
            case levenshtein.EditOp.Type.insert:
                add(text.front);
                text = text.dropOne;
                break;
            case levenshtein.EditOp.Type.remove:
                remove(expected.front);
                expected = expected.dropOne;
                break;
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
                    + pathCost(EditOp.insert(1), i, j);
                auto costDeletion = this.matrix(i - 1, j).cost + deletionIncrement
                    + pathCost(EditOp.remove(1), i, j);
                auto costNone = (sFront != tCurrent.front)
                    ? float.infinity
                    : (this.matrix(i - 1, j - 1).cost + pathCost(EditOp.keep(1), i, j));

                tCurrent.popFront();

                Cell cell;

                if (costNone <= costDeletion)
                {
                    if (costNone <= costInsertion)
                    {
                        cell = Cell(costNone, EditOp.keep(matrix(i - 1, j - 1).op));
                    }
                    else
                    {
                        cell = Cell(costInsertion, EditOp.insert(matrix(i, j - 1).op));
                    }
                }
                else
                {
                    if (costDeletion <= costInsertion)
                    {
                        cell = Cell(costDeletion, EditOp.remove(matrix(i - 1, j).op));
                    }
                    else
                    {
                        cell = Cell(costInsertion, EditOp.insert(matrix(i, j - 1).op));
                    }
                }

                matrix(i, j) = cell;
            }
            s.popFront();
        }
    }

    private float pathCost(EditOp proposedOp, size_t i, size_t j) @nogc
    {
        import std.algorithm : countUntil, endsWith, equal, filter, startsWith;

        enum Path
        {
            insertPath,
            removePath,
        }

        alias step(Path path) = (a, n) {
            auto cell = a[n - 1];

            if (cell.i == 0 && cell.j == 0)
            {
                assert(cell.op.type == EditOp.Type.keep && cell.op.count == 0);

                return cell;
            }

            if (path == Path.insertPath && cell.op.type == EditOp.Type.remove
                || path == path.removePath && cell.op.type == EditOp.Type.insert
            )
            {
                cell.self.skipByOp(cell.op, cell.i, cell.j);
            }
            else
            {
                cell.self.moveByOp(cell.op, cell.i, cell.j);
            }

            return typeof(cell)(cell.self, cell.self.matrix(cell.i, cell.j).op, cell.i, cell.j);
        };

        alias stepInsertPath = step!(Path.insertPath); // path where there's never more than one remove in a row
        alias stepRemovePath = step!(Path.removePath); // path where there's never more than one insert in a row

        auto traceInsert = tuple!("self", "op", "i", "j")(&this, proposedOp, i, j)
            .recurrence!stepInsertPath
            .map!(a => a.op.type)
            .filter!(op => op != EditOp.Type.remove);

        auto traceRemove = tuple!("self", "op", "i", "j")(&this, proposedOp, i, j)
            .recurrence!stepRemovePath
            .map!(a => a.op.type)
            .filter!(op => op != EditOp.Type.insert);

        // significantly penalize orphaned "no change" lines
        alias orphan = op => only(op, EditOp.Type.keep, op);
        const orphanPathCost =
            traceInsert.startsWith(orphan(EditOp.Type.insert)) ? orphanCost : 0 +
            traceRemove.startsWith(orphan(EditOp.Type.remove)) ? orphanCost : 0;

        // slightly penalize mode changes, to avoid pathologies arising from distant matches
        const pathChangesModeCost =
            traceInsert.startsWith(only(EditOp.Type.keep, EditOp.Type.insert)) ? modeChangeCost : 0 +
            traceRemove.startsWith(only(EditOp.Type.keep, EditOp.Type.remove)) ? modeChangeCost : 0;

        return orphanPathCost + pathChangesModeCost;
    }

    public EditOp.Type[] reconstructPath()
    {
        import std.algorithm.mutation : reverse;

        EditOp.Type[] result;
        size_t i = this.rows - 1;
        size_t j = this.cols - 1;

        while (i > 0 || j > 0)
        {
            const op = matrix(i, j).op;

            assert(op.count > 0);

            result ~= op.type.repeat(op.count).array;

            skipByOp(op, i, j);
        }
        reverse(result);
        return result;
    }

    private void moveByOp(EditOp op, ref size_t i, ref size_t j)
    in
    {
        assert(i > 0 || j > 0);
        assert(op.count > 0);
    }
    do
    {
        final switch (op.type)
        {
            case EditOp.Type.keep:
                i--;
                j--;
                break;
            case EditOp.Type.insert:
                j--;
                break;
            case EditOp.Type.remove:
                i--;
                break;
        }
    }

    private void skipByOp(EditOp op, ref size_t i, ref size_t j)
    {
        final switch (op.type)
        {
            case EditOp.Type.keep:
                assert(i >= op.count && j >= op.count);

                i -= op.count;
                j -= op.count;
                break;
            case EditOp.Type.insert:
                assert(j >= op.count);

                j -= op.count;
                break;
            case EditOp.Type.remove:
                assert(i >= op.count);

                i -= op.count;
                break;
        }
    }

    struct EditOp
    {
        enum Type
        {
            insert,
            remove,
            keep,
        }

        template constructByType(Type type)
        {
            static EditOp constructByType(size_t count)
            {
                return EditOp(type, count);
            }

            static EditOp constructByType(EditOp previousOp)
            {
                return EditOp(type, (type == previousOp.type) ? (previousOp.count + 1) : 1);
            }
        }

        alias insert = constructByType!(Type.insert);
        alias remove = constructByType!(Type.remove);
        alias keep = constructByType!(Type.keep);

        Type type;

        size_t count; // number of times this op is repeated on the best path
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
        this.matrixData[] = Cell(0, EditOp.keep(0));

        foreach (r; 1 .. rows)
        {
            this.matrix(r, 0) = Cell(r * deletionIncrement, EditOp.remove(r));
        }

        foreach (c; 1 .. cols)
        {
            this.matrix(0, c) = Cell(c * insertionIncrement, EditOp.insert(c));
        }
    }
}
