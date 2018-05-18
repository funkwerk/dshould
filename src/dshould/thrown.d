module dshould.thrown;

import std.format : format;
import std.traits : CommonType;
import dshould.ShouldType;

unittest
{
    import dshould.basic : be, equal, not, should;

    auto error = new Exception("");
    void throwme() { throw error; }

    throwme.should.throwAn!Exception.should.be(error);
    throwme.should.throwAn!Exception.should.not.be(null);

    2.should.be(5).because("it just should, okay")
        .should.throwA!FluentException.reason.should.equal("it just should, okay");

    2.should.be(5).should.throwA!FluentException;
    2.should.be(5).should.throwAn!Error.should.throwA!FluentException;

    2.should.be(2).should.not.throwA!FluentException;
}

template throwA(T : Throwable)
{
    auto throwA(Should)(Should should, string file = __FILE__, size_t line = __LINE__)
    if (isInstanceOf!(ShouldType, Should))
    {
        should.allowOnlyWordsBefore!(["not"], "throwA");

        should.terminateChain;

        FluentException innerError = null;

        auto inner()
        {
            try
            {
                should.data.lhs();
            }
            catch (T throwable)
            {
                static if (should.hasWord!"not")
                {
                    innerError = new FluentException(
                        format!`expected no %s`(T.stringof),
                        format!`, but expression threw %s`(throwable),
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
                    return throwable;
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
                    format!`expected %s`(T.stringof),
                    format!`, but expression threw %s`(otherThrowable),
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
                format!`expected %s`(T.stringof),
                `, but expression did not throw.`,
                file, line
            );
        }
    }
}

alias throwAn = throwA;

T because(T)(lazy T value, string reason)
{
    try
    {
        return value;
    }
    catch (FluentException fluentException)
    {
        throw fluentException.because(reason);
    }
}
