module tokens;

import std.algorithm : canFind;
import std.ascii : isAlpha, isAlphaNum, isDigit;
import std.conv : ConvException, to;
import std.file : read;
import std.format : format;
import std.sumtype : match, SumType;
import std.traits : EnumMembers;

struct SourceLocation
{
    string fileName;
    uint line;
    uint col;

    pure nothrow @safe string toString() const
    {
        return fileName ~ "(" ~ to!string(line) ~ ", " ~ to!string(col) ~ ")";
    }
}

class GrammarError : Exception
{
    pure nothrow @nogc @safe this(string msg, string file = __FILE__, size_t line = __LINE__)
    {
        super(msg, file, line);
    }
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

struct StopToken
{
    SourceLocation tokenLocation;
}

struct SymbolToken
{
    char symbol;
    SourceLocation tokenLocation;
}

struct KeywordToken
{
    Keyword kw;
    SourceLocation tokenLocation;
}

struct IdentifierToken
{
    string identifier;
    SourceLocation tokenLocation;
}

struct StringToken
{
    string literalString;
    SourceLocation tokenLocation;
}

struct LiteralNumberToken
{
    float literalNumber;
    SourceLocation tokenLocation;
}

alias KwOrId = SumType!(KeywordToken, IdentifierToken);
alias Token = SumType!(StopToken, SymbolToken, KeywordToken, IdentifierToken, StringToken, LiteralNumberToken);

pure nothrow @safe bool hasTokenValue(T)(Token token, T tokenValue)
{
    static if (is(T == char)) return token.match!(
        (SymbolToken symToken) => symToken.symbol == tokenValue,
        _ => false);
    else static if (is(T == Keyword)) return token.match!(
        (KeywordToken kwToken) => kwToken.kw == tokenValue,
        _ => false);
    else static if (is(T == string)) return token.match!(
        (IdentifierToken idToken) => idToken.identifier == tokenValue,
        (StringToken strToken) => strToken.literalString == tokenValue,
        _ => false);
    else static if (is(T == float)) return token.match!(
        (LiteralNumberToken numToken) => numToken.literalNumber == tokenValue,
        _ => false);
    else return false;
}

immutable char[] whiteSpaces = [' ', '\t', '\n', '\r'];
immutable char[] symbols = ['(', ')', '<', '>', '[', ']', '*'];

struct InputStream 
{
    immutable char[] stream;
    uint index;
    char savedChar;
    SourceLocation location, savedLocation;
    ubyte tabulations;
    Token savedToken;

    pure nothrow @safe this(in char[] s, in string fileName, in ubyte tab = 4)
    in (tab == 4 || tab == 8)
    {
        stream = s.idup;
        location = SourceLocation(fileName, 1, 1);
        savedLocation = location;
        tabulations = tab;
    }

    this(in string fileName, in ubyte tab = 4)
    {
        this(cast(immutable char[])(fileName.read), fileName, tab);
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
        if (index == stream.length) return char.init;

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
    }

    pure @safe void skipWhiteSpacesAndComments()
    {
        char c = readChar;
        while (canFind(whiteSpaces, c) || c == '#')
        {
            if (c == '#') while (!canFind(['\r', '\n'], readChar)) continue;
            c = readChar;
        }
        unreadChar(c);
    }

    pure @safe StringToken parseStringToken(in SourceLocation tokenLoc)
    {
        string token;
        while (index < stream.length)
        {
            immutable char c = readChar;
            if (c == '"') return StringToken(token, tokenLoc);
            token ~= c;
        }
        throw new GrammarError(format("Unterminated string beginning at %s", tokenLoc.toString));
    }

    pure @safe LiteralNumberToken parseFloatToken(in char firstChar, in SourceLocation tokenLoc)
    {
        string token = [firstChar];
        while (index < stream.length)
        {
            immutable char c = readChar;
            if (!c.isDigit && !canFind(['.', 'e', 'E'], c))
            {
                unreadChar(c);
                break;
            }
            token ~= c;
        }

        try
        {
            float value = to!float(token);
            return LiteralNumberToken(value, tokenLoc);
        }
		catch (ConvException exc) throw new GrammarError(format(
            "Invalid floating point number [%s] in %s", token, tokenLoc.toString));
    }

    pure @safe KwOrId parseKeywordOrIdentifierToken(in char firstChar, in SourceLocation tokenLoc)
    {
        string token = [firstChar];
        while(index < stream.length)
        {
            immutable char c = readChar;
            if (!c.isAlphaNum && c != '_')
            {
                unreadChar(c);
                break;
            }
            token ~= c;
        }

        static foreach (kw; EnumMembers!Keyword)
            if (token == kw) return KwOrId(KeywordToken(kw, tokenLoc));
        return KwOrId(IdentifierToken(token, tokenLoc));
    }

    pure Token readToken()
    {
        if (savedToken.match!((StopToken saved) => false, _ => true))
        {
            Token result = savedToken;
            savedToken = StopToken();
            return result;
        }

        skipWhiteSpacesAndComments;

        immutable char c = readChar;
        if (c == char.init) return Token();
        if (canFind(symbols, c)) return Token(SymbolToken(c, location));
        else if (c == '"') return Token(parseStringToken(location));
        else if (c.isDigit || canFind(['+', '-', '.'], c)) return Token(parseFloatToken(c, location));
        else if (c.isAlpha || c == '_') return parseKeywordOrIdentifierToken(c, location).match!(
            (KeywordToken kwT) => Token(kwT), (IdentifierToken idT) => Token(idT));
        else throw new GrammarError(format("Invalid character [%s] at %s", c, location.toString));
    }

    pure nothrow @nogc void unreadToken(Token t)
    in (savedToken.match!((StopToken t) => true, _ => false))
    {
        savedToken = t;
    }
}

unittest
{
    string str = "# This is a comment
    # This is another comment
    new material skyMaterial(
        diffuse(image(\"my file.pfm\")),
        <5.0, 500.0, 300.0>
    ) # Comment at the end of the line";
    auto inputFile = InputStream(str, "");

    assert(inputFile.readToken.hasTokenValue(Keyword.newKeyword));
    assert(inputFile.readToken.hasTokenValue(Keyword.material));
    assert(inputFile.readToken.hasTokenValue("skyMaterial"));
    assert(inputFile.readToken.hasTokenValue('('));
    assert(inputFile.readToken.hasTokenValue(Keyword.diffuse));
    assert(inputFile.readToken.hasTokenValue('('));
    assert(inputFile.readToken.hasTokenValue(Keyword.image));
    assert(inputFile.readToken.hasTokenValue('('));
    assert(inputFile.readToken.hasTokenValue("my file.pfm"));
    assert(inputFile.readToken.hasTokenValue(')'));
}