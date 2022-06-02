module tokens;

import std.typecons : Nullable;

enum TokenType
{
    keyword,
    identifier,
    literalString,
    literalNumber,
    symbol,
    stopToken
}

enum Keyword : string
{
    newKeyword = "new",
    material = "material",
    plane = "plane",
    sphere = "sphere",
    aabox = "aabox",
    cylinderShell = "cylindershell",
    cylinder = "cylinder",
    diffuse = "diffuse",
    specular = "specular",
    uniform = "uniform",
    checkered = "checkered",
    image = "image",
    identity = "identity",
    translation = "translation",
    rotationX = "rotationX",
    rotationY = "rotationY",
    rotationZ = "rotationZ",
    scaling = "scaling",
    camera = "camera",
    orthogonal = "orthogonal",
    perspective = "perspective",
    floatKeyword = "float"
}

union TokenValue
{
    Keyword keyword;
    string idOrLitString;
    float literalNumber;
    char symbol;
}

struct Token
{
    TokenType type;
    TokenValue value;

    this(Nullable!char)
    {
        type = TokenType.stopToken;
    }

    this(Keyword kw)
    {
        type = TokenType.keyword;
        value.keyword = kw;
    }

    this(string s, bool id = true)
    {
        if (id) type = TokenType.identifier;
        else type = TokenType.literalString;
        value.idOrLitString = s;
    }

    this(float literalNum)
    {
        type = TokenType.literalNumber;
        value.literalNumber = literalNum;
    }

    this(char sym)
    {
        type = TokenType.symbol;
        value.symbol = sym;
    }
}

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