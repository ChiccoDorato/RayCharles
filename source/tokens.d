module tokens;

import std.typecons : Nullable;

// ************************* TokenType *************************
/// Enumeration of the 6 types of Token for the Lexer:
enum TokenType
{
    keyword,
    identifier,
    literalString,
    literalNumber,
    symbol,
    stopToken
}

// ************************* Keyword *************************
/// Enumeration of the Keywords
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

// ************************* TokenValue *************************
/// Union representing a TokenValue - Parameters: a Keyword, an idOrLitString, a literalNumber, a symbol
union TokenValue
{
    Keyword keyword;
    string idOrLitString;
    float literalNumber;
    char symbol;
}

// ************************* Token *************************
/// Struct of a TokenValue - Parameters: TokenType, TokenValue
struct Token
{
    TokenType type;
    TokenValue value;

    /// Build a Token - Parameter: char of type Nullable. Update the type of the Token
    this(Nullable!char)
    {
        type = TokenType.stopToken;
    }

    /// Build a Token - Parameter: Keyword. Update the type and the keyword value of the Token
    this(Keyword kw)
    {
        type = TokenType.keyword;
        value.keyword = kw;
    }

    /// Build a Token - Parameters: string, bool. Update the type and the idOrLitString of the Token
    this(string s, bool id = true)
    {
        if (id) type = TokenType.identifier;
        else type = TokenType.literalString;
        value.idOrLitString = s;
    }

    /// Build a Token - Parameter: literalNum. Update the type and the literalNumber value of the Token
    this(float literalNum)
    {
        type = TokenType.literalNumber;
        value.literalNumber = literalNum;
    }

    /// Build a Token - Parameter: char. Update the type and the symbol value of the Token
    this(char sym)
    {
        type = TokenType.symbol;
        value.symbol = sym;
    }
}

// ************************* SourceLocation *************************
/// Struct of a SourceLocation - Parameters: fileName (string), number of line and column (uint)
struct SourceLocation
{
    string fileName;
    uint line;
    uint col;
}

// ************************* InputStream *************************
/// Struct of an InputStream - Parameters: stream (char[]), index (uint), savedChar (char), 
///                             location and savedLocation (SourceLocation), tabulations (ubyte) 
struct InputStream 
{
    char[] stream;
    uint index;
    char savedChar;
    SourceLocation location, savedLocation;
    ubyte tabulations;

    /// Build an InputStream - Parameters: stream (char[]), fileName = "" (string), tabulation = 4 (ubyte).
    ///
    /// Default: SourceLocation at (1,1), savedChar (charInit)
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

    /// Return the updated position after a char is read from the Lexer
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

    /// Read and record a char, then update the position calling the function updatePos
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

    /// Unread a char, then update the position "going back" (decrease the index by one)
    pure nothrow @nogc @safe void unreadChar(in char c)
    in (savedChar == char.init)
    {
        savedChar = c;
        location = savedLocation;
        --index;
    }
}