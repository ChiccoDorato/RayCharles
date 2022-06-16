module tokens;

import cameras : Camera;
import materials : Material;
import shapes : World;
import std.algorithm : canFind;
import std.ascii : isAlpha, isAlphaNum, isDigit;
import std.conv : ConvException, to;
import std.file : read;
import std.format : format;
import std.math : isFinite, isInfinity;
import std.sumtype : match, SumType;
import std.traits : EnumMembers;
import std.typecons : Nullable;

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

struct StopToken {}

struct SymbolToken { char symbol; }

struct KeywordToken { Keyword keyword; }

struct IdentifierToken { string identifier; }

struct StringToken { string literalString; }

struct LiteralNumberToken { float literalNumber; }

alias TokenType = SumType!(StopToken, SymbolToken, KeywordToken, IdentifierToken, StringToken, LiteralNumberToken);

struct Token
{
    TokenType type;
    SourceLocation location;

    pure nothrow @safe this(T)(in T tokenType, in SourceLocation tokenLocation = SourceLocation())
    {
        type = cast(TokenType)(tokenType);
        location = tokenLocation;
    }

    pure nothrow @nogc void opAssign(Token rhs)
    {
        type = rhs.type;
        location = rhs.location;
    }
}

pure nothrow @safe bool isSpecificType(T)(Token token)
{
    return token.type.match!((T t) => true, _ => false);
}

unittest
{
    auto stop = Token(StopToken(), SourceLocation("noFile", 3, 5));
    assert(isSpecificType!StopToken(stop));
    assert(!isSpecificType!LiteralNumberToken(stop));

    auto literalString = Token(StringToken("I am a literal string token"));
    assert(isSpecificType!StringToken(literalString));
    assert(!isSpecificType!SymbolToken(literalString));
}

// Try to make it better because of StopToken
pure @safe string stringTokenValue(Token token)
{
    return token.type.match!(
        (StopToken stop) => "",
        (SymbolToken sym) => to!string(sym.symbol),
        (KeywordToken kw) => kw.keyword,
        (IdentifierToken id) => id.identifier,
        (StringToken str) => str.literalString,
        (LiteralNumberToken number) => to!string(number.literalNumber)
    );
}

pure nothrow @safe bool hasTokenValue(T)(Token token, T tokenValue)
{
    static if (is(T == char)) return token.type.match!(
        (SymbolToken sym) => sym.symbol == tokenValue,
        _ => false);
    else static if (is(T == Keyword)) return token.type.match!(
        (KeywordToken kw) => kw.keyword == tokenValue,
        _ => false);
    else static if (is(T == string)) return token.type.match!(
        (IdentifierToken id) => id.identifier == tokenValue,
        (StringToken str) => str.literalString == tokenValue,
        _ => false);
    else static if (is(T == float)) return token.type.match!(
        (LiteralNumberToken number) => number.literalNumber == tokenValue,
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
    pure nothrow @safe char readChar()
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

    pure @safe Token parseStringToken(in SourceLocation tokenLoc)
    {
        string token;
        while (index < stream.length)
        {
            immutable char c = readChar;
            if (c == '"') return Token(StringToken(token), tokenLoc);
            token ~= c;
        }
        throw new GrammarError(format("Unterminated string beginning at %s", tokenLoc.toString));
    }

    pure @safe Token parseFloatToken(in char firstChar, in SourceLocation tokenLoc)
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
            return Token(LiteralNumberToken(value), tokenLoc);
        }
		catch (ConvException exc) throw new GrammarError(format(
            "Invalid floating point number %s at %s", token, tokenLoc.toString));
    }

    pure @safe Token parseKeywordOrIdentifierToken(in char firstChar, in SourceLocation tokenLoc)
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
            if (token == kw) return Token(KeywordToken(kw), tokenLoc);
        return Token(IdentifierToken(token), tokenLoc);
    }

    pure Token readToken()
    {
        if (savedToken.type.match!((StopToken saved) => false, _ => true))
        {
            Token result = savedToken;
            savedToken = Token();
            return result;
        }

        skipWhiteSpacesAndComments;

        immutable char c = readChar;
        if (c == char.init) return Token(StopToken(), location);
        if (canFind(symbols, c)) return Token(SymbolToken(c), location);
        else if (c == '"') return parseStringToken(location);
        else if (c.isDigit || canFind(['+', '-', '.'], c)) return parseFloatToken(c, location);
        else if (c.isAlpha || c == '_') return parseKeywordOrIdentifierToken(c, location);
        else throw new GrammarError(format("Invalid character %s at %s", c, location.toString));
    }

    pure nothrow @nogc void unreadToken(Token t)
    in (savedToken.type.match!((StopToken stop) => true, _ => false))
    {
        savedToken = t;
    }

    pure void expectSymbol(InputStream inpStr, char sym)
    {
        Token token = inpStr.readToken;
        if (!canFind(symbols, sym) && !hasTokenValue(token, sym))
            throw new GrammarError(format("Got token %s instead of symbol %s at %s",
                token.stringTokenValue, sym, token.location.toString));
    }

    pure Keyword expectKeyword(InputStream inpStr, Keyword[] keywords)
    {
        Token token = inpStr.readToken;
        Nullable!Keyword actualKw;

        token.type.match!(
            (KeywordToken kwToken) => actualKw = kwToken.keyword,
            _ => actualKw
            );

        if (!actualKw.isNull && canFind(keywords, actualKw.get)) return actualKw.get;
        throw new GrammarError(format("Expected one of the following keywords %s instead of %s at %s",
            keywords, token.stringTokenValue, token.location.toString));
    }

    pure float expectNumber(InputStream inpStr, Scene scene)
    {
        Token token = inpStr.readToken;
        float value;

        token.type.match!(
            (LiteralNumberToken numberToken) => value = numberToken.literalNumber,
            (IdentifierToken idToken) => value = scene.floatVars.get(idToken.identifier, float.infinity),
            _ => value
        );

        if (value.isFinite) return value;
        if (value.isInfinity) throw new GrammarError(format("Unknown variable %s at %s",
            token.stringTokenValue, token.location.toString));
        throw new GrammarError(format("Got token %s instead of a number at %s",
            token.stringTokenValue, token.location.toString));
    }

    pure string expectString(InputStream inpStr)
    {
        Token token = inpStr.readToken;
        if (isSpecificType!StringToken(token)) return token.stringTokenValue;
        throw new GrammarError(format("Got a %s instead of a string at %s",
            token.type, token.location.toString));
    }

    pure string expectIdentifier(InputStream inpStr)
    {
        Token token = inpStr.readToken;
        if (isSpecificType!IdentifierToken(token)) return token.stringTokenValue;
        throw new GrammarError(format("Got a %s instead of an identifier at %s",
            token.type, token.location.toString));
    }
}

unittest
{
    auto stream = InputStream("abc   \nd\nef", "");

    assert(stream.location.line == 1);
    assert(stream.location.col == 1);

    assert(stream.readChar == 'a');
    assert(stream.location.line == 1);
    assert(stream.location.col == 2);

    stream.unreadChar('A');
    assert(stream.location.line == 1);
    assert(stream.location.col == 1);

    assert(stream.readChar == 'A');
    assert(stream.location.line == 1);
    assert(stream.location.col == 2);

    assert(stream.readChar == 'b');
    assert(stream.location.line == 1);
    assert(stream.location.col == 3);

    assert(stream.readChar == 'c');
    assert(stream.location.line == 1);
    assert(stream.location.col == 4);

    stream.skipWhiteSpacesAndComments;

    assert(stream.readChar == 'd');
    assert(stream.location.line == 2);
    assert(stream.location.col == 2);

    assert(stream.readChar == '\n');
    assert(stream.location.line == 3);
    assert(stream.location.col == 1);

    assert(stream.readChar == 'e');
    assert(stream.location.line == 3);
    assert(stream.location.col == 2);

    assert(stream.readChar == 'f');
    assert(stream.location.line == 3);
    assert(stream.location.col == 3);

    assert(stream.readChar == char.init);
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

// Probably not needed for our purposes. Associative arrays probably works better in
// this case and best choice would be void[0][string]. Not clear how it works, though.
import std.container.rbtree;
struct Scene
{
    Material[string] materials;
    World world;
    Nullable!Camera cam;
    float[string] floatVars;
    auto overriddenVars = make!(RedBlackTree!string);
}