module tokens;

import cameras : Camera;
import geometry : Vec;
import hdrimage : Color, HDRImage;
import materials : BRDF, CheckeredPigment, ImagePigment, Material, Pigment, SpecularBRDF, UniformPigment;
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

// ************************* Source Location *************************
/// Structure of a SourceLocation  - Members: fileName (string) and the number of line and col (uint)
struct SourceLocation
{
    string fileName;
    uint line;
    uint col;

    /// Convert a SourceLocarion into a string
    pure nothrow @safe string toString() const
    {
        return fileName ~ "(" ~ to!string(line) ~ ", " ~ to!string(col) ~ ")";
    }
}

// ************************* GrammarError *************************
/// Class of a GrammarError derivate of a Exception class - Members: message (string), file (string) and line number (size_t)
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

// ************************* StopToken *************************
/// Struct of a StopToken: needed to stop the lecture
struct StopToken {}

// ************************* SymbolToken *************************
/// Struct of a SymbolToken - Member: symbol (char)
struct SymbolToken { char symbol; }

// ************************* KeywordToken *************************
/// Struct of a KeywordToken - Member: a type Keyword
struct KeywordToken { Keyword keyword; }

// ************************* IdentifierToken *************************
/** Struct of a IdentifierToken - Member: identifier (string)
* @param identifier (string)
**/
struct IdentifierToken { string identifier; }

// ************************* StringToken *************************
/// Struct of a StringToken - Member: literalString (string)
struct StringToken { string literalString; }

// ************************* IdentifierToken *************************
/// Struct of a IdentifierToken - Member: an identifier (string)
struct LiteralNumberToken { float literalNumber; }

// ************************* TokenType *************************
/// SumType of all the kind of Tokens one can find: StopToken, SymbolToken, KeywordToken, IdentifierToken, StringToken, LiteralNumberToken
alias TokenType = SumType!(StopToken, SymbolToken, KeywordToken, IdentifierToken, StringToken, LiteralNumberToken);

// ************************* Token *************************
/// Struct of a Token - Members: type (TokenType) and location (SourceLocation)
struct Token
{
    TokenType type;
    SourceLocation location;

    /// Build a certain type of Token - Parameters: TokenType, SourceLocation 
    pure nothrow @safe this(T)(in T tokenType, in SourceLocation tokenLocation = SourceLocation())
    {
        type = cast(TokenType)(tokenType);
        location = tokenLocation;
    }

    /// Assignement operator between two Tokens
    pure nothrow @nogc void opAssign(Token rhs)
    {
        type = rhs.type;
        location = rhs.location;
    }
}

/// Verify if a Token is of the specific type given 
pure nothrow @safe bool isSpecificType(T)(Token token)
{
    return token.type.match!((T t) => true, _ => false);
}

///
unittest
{
    // isSpecificType: StopToken
    auto stop = Token(StopToken(), SourceLocation("noFile", 3, 5));
    assert(isSpecificType!StopToken(stop));
    assert(!isSpecificType!LiteralNumberToken(stop));
    // isSpecificType: StringToken
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

// Verify if two given Token have the same values
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

/// All possible white Spaces
immutable char[] whiteSpaces = [' ', '\t', '\n', '\r'];

/// All possible Symbols
immutable char[] symbols = ['(', ')', '<', '>', '[', ']', '*'];

// ************************* InputStream *************************
/// Struct of an InputStream 
///
/// Members: stream (immutable char[]), index (uint), savedChar (char), 
/// location and savedLocation (SourceLocation), tabulations (ubyte), savedToken (Token)
struct InputStream 
{
    immutable char[] stream;
    uint index;
    char savedChar;
    SourceLocation location, savedLocation;
    ubyte tabulations;
    Token savedToken;

    /// Build an InputStream - Parameters: s (char[]), fileName (string), tab (ubyte)
    pure nothrow @safe this(in char[] s, in string fileName, in ubyte tab = 4)
    in (tab == 4 || tab == 8)
    {
        stream = s.idup;
        location = SourceLocation(fileName, 1, 1);
        savedLocation = location;
        tabulations = tab;
    }

    /// Build an InputStream - Parameters: fileName (string), tab (ubyte)
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

    /// Find white spaces due to '\r' or '\n' and comments preceded by '#'
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

    /// Analyse if in a certain SourceLocation there is a StringToken - Parameter: tokenLoc (SourceLocation)
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

    /// Analyse if in a certain SourceLocation there is a LiteralNumberToken  - Parameter: firstChar (char), tokenLoc (SourceLocation)
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

    /// Analyse if in a certain SourceLocation there is a KeywordToken or an IdentifierToken - Parameter: firstChar (char), tokenLoc (SourceLocation)
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

    /// Read and Analyse a Token returning the correct kind
    pure Token readToken()
    {   
        // StopToken
        if (savedToken.type.match!((StopToken saved) => false, _ => true))
        {
            Token result = savedToken;
            savedToken = Token();
            return result;
        }
        // Here white spaces and comments are skipped
        skipWhiteSpacesAndComments;

        immutable char c = readChar;
        if (c == char.init) return Token(StopToken(), location);
        if (canFind(symbols, c)) return Token(SymbolToken(c), location);
        else if (c == '"') return parseStringToken(location);
        else if (c.isDigit || canFind(['+', '-', '.'], c)) return parseFloatToken(c, location);
        else if (c.isAlpha || c == '_') return parseKeywordOrIdentifierToken(c, location);
        else throw new GrammarError(format("Invalid character %s at %s", c, location.toString));
    }

    /// Unread a Token - Parameter: t (Token)
    pure nothrow @nogc void unreadToken(Token t)
    in (savedToken.type.match!((StopToken stop) => true, _ => false))
    {
        savedToken = t;
    }

    /// Throw a GrammarError if the Token is not the expected one: a SymbolToken - Parameters: inpStr (InputStream), sym (char)
    pure void expectSymbol(InputStream inpStr, char sym)
    {
        Token token = inpStr.readToken;
        if (!canFind(symbols, sym) && !hasTokenValue(token, sym))
            throw new GrammarError(format("Got token %s instead of symbol %s at %s",
                token.stringTokenValue, sym, token.location.toString));
    }

    /// Throw a GrammarError if the Token is not the expected one: a KeywordToken - Parameters: inpStr (InputStream), keywords (Keyword[])
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
    
    /// Throw a GrammarError if the Token is not the expected one: a LiteralNumberToken - Parameters: inpStr (InputStream), scene (Scene)
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

    /// Throw a GrammarError if the Token is not the expected one: a StringToken - Parameters: inpStr (InputStream)
    pure string expectString(InputStream inpStr)
    {
        Token token = inpStr.readToken;
        if (isSpecificType!StringToken(token)) return token.stringTokenValue;
        throw new GrammarError(format("Got a %s instead of a string at %s",
            token.type, token.location.toString));
    }

    /// Throw a GrammarError if the Token is not the expected one: a IdentifierToken - Parameters: inpStr (InputStream)
    pure string expectIdentifier(InputStream inpStr)
    {
        Token token = inpStr.readToken;
        if (isSpecificType!IdentifierToken(token)) return token.stringTokenValue;
        throw new GrammarError(format("Got a %s instead of an identifier at %s",
            token.type, token.location.toString));
    }
}

///
unittest
{
    // InputStream unittest
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

///
unittest
{
    // Lexer unittest
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

// /// Analyse an InputStream and return a 3D Vec (x,y,z) - Parameters: inpFile (InputStream), scene (Scene)
// Vec parseVec(InputStream inpFile, Scene scene)
// {
//     expectSymbol(inpFile, "[");
//     float x = expectNumber(inpFile, scene);
//     expectSymbol(inpFile, ",");
//     float y = expectNumber(inpFile, scene);
//     expectSymbol(inpFile, ",");
//     float z = expectNumber(inpFile, scene);
//     expectSymbol(inpFile, "]");

//     return Vec(x, y, z);
// }

// /// Analyse an InputStream and return a Color (r,g,b) - Parameters: inpFile (InputStream), scene (Scene)
// Color parseColor(InputStream inpFile, Scene scene)
// {
//     expectSymbol(inpFile, "<");
//     float r = expectNumber(inpFile, scene);
//     expectSymbol(inpFile, ",");
//     float g = expectNumber(inpFile, scene);
//     expectSymbol(inpFile, ",");
//     float b = expectNumber(inpFile, scene);
//     expectSymbol(inpFile, ">");

//     return Color(r, g, b);
// }

// /// Analyse an InputStream and return a Pigment - Parameters: inpFile (InputStream), scene (Scene)
// Pigment parsePigment(InputStream inpFile, Scene scene)
// {
//     Keyword[] keys = [Keyword.uniform, Keyword.checkered, Keyword.image];
//     Keyword k = expectKeyword(inpFile, keys);
//     Pigment result;
//     expectSymbol(inpFile, "(");

//     if(k.hasTokenValue(Keyword.uniform))
//     {
//         Color color = parseColor(inpFile, scene);
//         result = new UniformPigment(color);
//     }  
//     else if (k.hasTokenValue(Keyword.checkered))
//     {
//         Color color1 = parseColor(inpFile, scene);
//         expectSymbol(inpFile, ",");
//         Color color2 = parseColor(inpFile, scene);
//         expectSymbol(inpFile, ",");
//         int numOfSteps = cast(int)(expectNumber(inpFile, scene));
//         result = CheckeredPigment(color1, color2, numOfSteps);
//     }
//     else if (k.hasTokenValue(Keyword.image))
//     {
//         string fileName = expectString(inpFile);
//         HDRImage image = writePFMFile(fileName);
//         result = new ImagePigment(image);
//     }
//     else
//         assert(false, "None will reach this line..."); 

//     expectSymbol(inpFile, ")");
//     return result;
// }

// BRDF parseBRDF(InputStream inpFile, Scene scene)
// {
//     Keyword[] keys = [Keyword.diffuse, Keyword.specular];
//     Keyword brdfKeyword = expectKeywords(inpFile, keys);
//     BRDF result;
//     expectSymbol(inpFile, "(");
//     Pigment pigment = parsePigment(inpFile, scene);
//     expectSymbol(inpFile, ")");

//     if (brdfKeyword.hasTokenValue(Keyword.diffuse)) 
//     {
//         result = DiffuseBRDF(pigment);
//         return result;
//     }
//     else if (brdfKeyword.hasTokenValue(Keyword.specular))
//     {
//         result = SpecularBRDF(pigment);
//         return result;
//     }

//     assert(false, "None will reach this line...");
// }
    
    