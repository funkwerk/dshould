module dshould.thrown;

import std.format : format;
import std.traits : CommonType;
import std.typecons;
import dshould.ShouldType;
import dshould.basic : be, equal, not, should;

/**
 * The phrase `.should.throwA!Type` (or `.throwAn!Exception`, depending on grammar) expects the left-hand side expression
 * to throw an exception of the given type.
 * The exception is caught. If no exception was thrown, `.throwA` itself throws a `FluentException` to complain.
 * If the left-hand side threw an exception, the word `.where` may be used to inspect this exception further.
 * The meaning of `.throwA` may be negated with `.not`, in which case nothing is returned.
 */
public template throwA(T : Throwable)
{
    auto throwA(Should)(Should should, Fence _ = Fence(), string file = __FILE__, size_t line = __LINE__)
    if (isInstanceOf!(ShouldType, Should))
    {
        should.allowOnlyWords!("not").before!"throwA";

        should.terminateChain;

        FluentException innerError = null;

        auto inner()
        {
            try
            {
                should.got();
            }
            catch (T throwable)
            {
                static if (should.hasWord!"not")
                {
                    innerError = new FluentException(
                        format!`no exception of type %s`(T.stringof),
                        format!`%s`(throwable),
                        file, line
                    );
                }
                else
                {
                    return throwable;
                }
            }

            static if (!should.hasWord!"not")
            {
                return null;
            }
        }

        try
        {
            static if (is(typeof(inner()) == void))
            {
                inner;
            }
            else
            {
                if (auto throwable = inner())
                {
                    return tuple!("where", "which")(throwable, throwable);
                }
            }
        }
        // don't go up beyond Exception unless we're not from beneath it:
        // keeps us from needlessly breaking purity.
        catch (CommonType!(Exception, T) otherThrowable)
        {
            static if (should.hasWord!"not")
            {
                return;
            }
            else
            {
                throw new FluentException(
                    format!`exception of type %s`(T.stringof),
                    format!`%s`(otherThrowable),
                    file, line
                );
            }
        }

        static if (should.hasWord!"not")
        {
            if (innerError !is null)
            {
                throw innerError;
            }
        }
        else
        {
            throw new FluentException(
                format!`exception of type %s`(T.stringof),
                `no exception`,
                file, line
            );
        }
    }
}

/// ditto
public alias throwAn = throwA;

///
unittest
{
    auto exception = new Exception("");

    /**
     * Throws: Exception
     */
    void throwsException() { throw exception; }

    throwsException.should.throwAn!Exception.which.should.be(exception);
    throwsException.should.throwAn!Exception.which.should.not.be(null);

    2.should.be(5).should.throwA!FluentException;
    2.should.be(5).should.throwAn!Error.should.throwA!FluentException;

    2.should.be(2).should.not.throwA!FluentException;
}
