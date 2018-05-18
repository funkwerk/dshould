module dshould.stringcmp;

import std.algorithm : EditOp, map;
import std.format : format;
import std.range;
import std.typecons;
import dshould.ShouldType;
import dshould.basic;

void equal(Should, T)(Should should, T value, string file = __FILE__, size_t line = __LINE__)
if (isInstanceOf!(ShouldType, Should) && is(T == string))
{
    should.allowOnlyWordsBefore!([], "equal (string)");

    should.addWord!"equal".addData!"rhs"(value).stringCmp(file, line);
}

void stringCmp(Should)(Should should, string file, size_t line)
if (isInstanceOf!(ShouldType, Should))
{
    should.allowOnlyWordsBefore!(["equal"], "");

    with (should)
    {
        terminateChain;
        if (data.lhs() != data.rhs)
        {
            string original;
            string diff;

            if (data.lhs().canFind("\n"))
            {
                auto diffPair = multiLineDiff(data.rhs.split("\n"), data.lhs().split("\n"));

                original = diffPair.original.join("\n") ~ "\n";
                diff = "\n" ~ diffPair.target.join("\n");
            }
            else
            {
                auto diffPair = oneLineDiff(data.rhs, data.lhs());

                original = diffPair.original;
                diff = diffPair.target;
            }

            throw new FluentException(
                "test failed",
                format!`: expected %s but got %s`(original, diff),
                file, line
            );
        }
    }
}

@("collates successive replacements")
unittest
{
    import unit_threaded.should;

    const expectedOriginal = "Hello W" ~ RED_CODE ~ "or" ~ CLEAR_CODE ~ "ld";
    const expectedTarget = "Hello W" ~ GREEN_CODE ~ "ey" ~ CLEAR_CODE ~ "ld";
    const diff = "Hello World".oneLineDiff("Hello Weyld");

    (diff.original ~ diff.target).shouldEqual(expectedOriginal ~ expectedTarget);
}

@("does not colorize diff view for strings that are too different")
unittest
{
    import unit_threaded.should;

    const diff = "Hello World".oneLineDiff("Goodbye Universe");
    (diff.original ~ diff.target).shouldEqual("Hello WorldGoodbye Universe");
}

@("tries to not change diff mode too often")
unittest
{
    import unit_threaded.should;

    const cleanDiff = `method="` ~ GREEN_CODE ~ `multiply` ~ CLEAR_CODE ~ `"`;

    `method="update"`.oneLineDiff(`method="multiply"`).target.shouldEqual(cleanDiff);
}

@("supports multiline diff")
unittest
{
    import std.string : join, split;
    import unit_threaded.should;

    // given
    const originalText = `{
        "id": 1,
        "speakers": ["KK__LK02"],
        "startTime": "2003-02-01T12:00:00Z",
        "stopTime": "2003-02-01T14:00:00Z",
        "route": "ROUTE",
        "phraseId": 42
    }`;
    const modifiedText = `{
        "id": 1,
        "speakers": ["KK__LK02"],
        "route": "ROUTE",
        "somethingElse": "goes here",
        "phraseId": 42
    }`;

    // then
    const MINUS = RED_CODE ~ `-`;
    const PLUS = GREEN_CODE ~ `+`;

    const patchTextOriginal = ` {
         "id": 1,
         "speakers": ["KK__LK02"],
` ~ MINUS ~ `        "startTime": "2003-02-01T12:00:00Z",` ~ CLEAR_CODE ~ `
` ~ MINUS ~ `        "stopTime": "2003-02-01T14:00:00Z",` ~ CLEAR_CODE ~ `
         "route": "ROUTE",
         "phraseId": 42
     }`;

    const patchTextTarget = ` {
         "id": 1,
         "speakers": ["KK__LK02"],
         "route": "ROUTE",
` ~ PLUS ~ `        "somethingElse": "goes here",` ~ CLEAR_CODE ~ `
         "phraseId": 42
     }`;

    const diff = originalText.split("\n").multiLineDiff(modifiedText.split("\n"));

    (diff.original.join("\n") ~ diff.target.join("\n")).shouldEqual(patchTextOriginal ~ patchTextTarget);
}

auto oneLineDiff(string expected, string text) @safe
{
    alias removePred = text => RED_CODE ~ text ~ CLEAR_CODE;
    alias addPred = text => GREEN_CODE ~ text ~ CLEAR_CODE;
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

auto multiLineDiff(string[] expected, string[] text) @safe
{
    alias removePred = lines => lines.map!(line => RED_CODE ~ "-" ~ line ~ CLEAR_CODE);
    alias addPred = lines => lines.map!(line => GREEN_CODE ~ "+" ~ line ~ CLEAR_CODE);
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

// TODO bracket crossing cost
Nullable!T colorizedDiff(T, alias removePred, alias addPred, alias keepPred)(T expected, T text) @trusted
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

enum RED_CODE = "\x1b[31m";
enum GREEN_CODE = "\x1b[32m";
enum CLEAR_CODE = "\x1b[39m";

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
                auto costInsertion = this.matrix(i, j - 1).cost + insertionIncrement + pathCost(EditOp.insert, i, j);
                auto costDeletion = this.matrix(i - 1, j).cost + deletionIncrement + pathCost(EditOp.remove, i, j);
                auto costNone = (sFront == tCurrent.front) ? this.matrix(i - 1, j - 1).cost : float.infinity;

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

    private void moveByOp(EditOp op, ref size_t i, ref size_t j)
    in
    {
        assert(i > 0 || j > 0);
    }
    body
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

    private float pathCost(EditOp proposedOp, size_t i, size_t j)
    {
        import std.algorithm : countUntil, endsWith, equal, filter;

        alias step = (a, n) {
            auto cell = a[n - 1];

            if (cell.i == 0 && cell.j == 0)
            {
                return cell;
            }

            moveByOp(cell.op, cell.i, cell.j);

            return typeof(cell)(matrix(cell.i, cell.j).op, cell.i, cell.j);
        };

        auto infiniteTrace = tuple!("op", "i", "j")(proposedOp, i, j).recurrence!step;
        auto trace = infiniteTrace.takeExactly(infiniteTrace.countUntil!(a => a.i == 0 && a.j == 0)).map!(a => a.op);
        auto traceInsert = trace.filter!(op => op == EditOp.insert || op == EditOp.none);
        auto traceRemove = trace.filter!(op => op == EditOp.remove || op == EditOp.none);

        return traceInsert.take(3).equal(only(EditOp.insert, EditOp.none, EditOp.insert)) ? orphanCost : 0
            +  traceRemove.take(3).equal(only(EditOp.remove, EditOp.none, EditOp.remove)) ? orphanCost : 0;
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

    private enum deletionIncrement = 1;
    private enum insertionIncrement = 1;
    private enum orphanCost = 2.5;

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
    body
    {
        return this.matrixData[row * this.cols + col];
    }

    private void initMatrix()
    {
        this.matrixData[] = Cell(0, EditOp.insert);

        foreach (r; 0 .. rows)
        {
            this.matrix(r, 0) = Cell(r * deletionIncrement, EditOp.remove);
        }

        foreach (c; 0 .. cols)
        {
            this.matrix(0, c) = Cell(c * insertionIncrement, EditOp.insert);
        }
    }
}
