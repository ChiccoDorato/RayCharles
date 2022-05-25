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
    char savedChar;
    SourceLocation location, savedLocation;
    ubyte tabulations;

    this(in char[] s, in string fileName = "", in ubyte tab = 8) pure nothrow
    in (tab == 4 || tab == 8)
    {
        stream = s;
        location = SourceLocation(fileName, 1, 1);
        savedChar = '';
        savedLocation = location;
        tabulations = tab;
    }
}