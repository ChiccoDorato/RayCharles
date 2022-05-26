/* module tokens;

struct SourceLocation
{
    string fileName;
    uint line;
    uint col;
}

struct InputStream 
{
    char[] stream;
    uint index = 0;
    char savedChar;
    SourceLocation location, savedLocation;
    ubyte tabulations;

    this(in char[] s, in string fileName = "", in ubyte tab = 4) pure nothrow
    in (stream.length !=0)
    in (tab == 4 || tab == 8)
    {
        stream = s;
        location = SourceLocation(fileName, 1, 1);
        savedChar = char.init;
        savedLocation = location;
        tabulations = tab;
    }
    
    void updatePos(in char c) pure nothrow
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

    char read() pure nothrow
    {
        char c;
        if(savedChar == char.init)
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
    }

    void unreadChar(in char c) pure nothrow
    in(c == char.init)
    {
        savedChar = c;
        location = savedLocation;
        --index;
    }
} */