module tokens;

struct SourceLocation
{
    string fileName;
    uint line;
    uint col;
}

struct InputStream 
{
    char[] stream;
    uint index;
    char savedChar;
    SourceLocation location, savedLocation;
    ubyte tabulations;

    pure nothrow @safe this(char[] s, in string fileName = "", in ubyte tab = 4)
    in (stream.length != 0)
    in (tab == 4 || tab == 8)
    {
        stream = s;
        location = SourceLocation(fileName, 1, 1);
        savedChar = char.init;
        savedLocation = location;
        tabulations = tab;
    }

    pure nothrow @nogc @safe void updatePos(in char c)
    {
        if (c == char.init) return;
        if (c == '\n')
        {
            ++location.line;
            location.col = 1;
        }
        else if (c == '\t') location.col += tabulations;
        else ++location.col;
    }

    pure nothrow @nogc @safe char readChar()
    {
        char c;
        if (savedChar == char.init)
        {
            c = stream[index];
            ++index;
        }
        else
        {
            c = savedChar;
            savedChar = char.init;
        }

        savedLocation = location;
        updatePos(c);

        return c;
    }

    pure nothrow @nogc @safe void unreadChar(in char c)
    in (savedChar == char.init)
    {
        savedChar = c;
        location = savedLocation;
        --index;
    }
}