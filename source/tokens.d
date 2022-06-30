module tokens;

import cameras;
import geometry : Vec;
import hdrimage;
import materials;
import shapes;
import std.algorithm : canFind;
import std.ascii : isAlpha, isAlphaNum, isDigit;
import std.conv : ConvException, to;
import std.file : read;
import std.format : format;
import std.math : isFinite, isInfinity;
import std.sumtype : match, SumType;
import std.traits : EnumMembers;
import std.typecons : Nullable, tuple, Tuple;
import transformations;


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
    sphere = "sphere",
    plane = "plane",
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
pure nothrow @safe bool hasTokenValue(T)(Token token, in T tokenValue)
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
immutable char[] symbols = ['(', ')', '<', '>', '[', ']', ',', '*'];

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
        char c;
        if (savedChar == char.init)
        {
            if (index == stream.length) return char.init;
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
        if (!savedToken.isSpecificType!StopToken)
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
    pure nothrow @nogc void unreadToken(in Token t)
    in (savedToken.isSpecificType!StopToken)
    {
        savedToken = t;
    }

    /// Throw a GrammarError if the Token is not the expected one: a SymbolToken - Parameter: sym (char)
    pure void expectSymbol(in char sym)
    {
        Token token = readToken;
        if (!canFind(symbols, sym) || !hasTokenValue(token, sym))
            throw new GrammarError(format("Got token %s instead of symbol %s at %s",
                token.stringTokenValue, sym, token.location.toString));
    }

    /// Throw a GrammarError if the Token is not the expected one: a KeywordToken - Parameter: keywords (Keyword[])
    pure Keyword expectKeyword(in Keyword[] keywords)
    {
        Token token = readToken;
        Nullable!Keyword actualKw;

        token.type.match!(
            (KeywordToken kwToken) => actualKw = kwToken.keyword,
            _ => actualKw
            );

        if (!actualKw.isNull && canFind(keywords, actualKw.get)) return actualKw.get;
        throw new GrammarError(format("Expected one of the following keywords %s instead of %s at %s",
            keywords, token.stringTokenValue, token.location.toString));
    }

    /// Throw a GrammarError if the Token is not the expected one: a LiteralNumberToken - Parameter: scene (Scene)
    pure float expectNumber(in Scene scene)
    {
        Token token = readToken;
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

    /// Throw a GrammarError if the Token is not the expected one: a StringToken - Parameter:
    pure string expectString()
    {
        Token token = readToken;
        if (isSpecificType!StringToken(token)) return token.stringTokenValue;
        throw new GrammarError(format("Got a %s instead of a string at %s",
            token.type, token.location.toString));
    }

    /// Throw a GrammarError if the Token is not the expected one: an IdentifierToken - Parameter:
    pure string expectIdentifier()
    {
        Token token = readToken;
        if (isSpecificType!IdentifierToken(token)) return token.stringTokenValue;
        throw new GrammarError(format("Got a %s instead of an identifier at %s",
            token.type, token.location.toString));
    }

    /// Analyse an InputStream and return a 3D Vec (x,y,z) - Parameter: scene (Scene)
    pure Vec parseVector(in Scene scene)
    {
        expectSymbol('[');
        immutable x = expectNumber(scene);
        expectSymbol(',');
        immutable y = expectNumber(scene);
        expectSymbol(',');
        immutable z = expectNumber(scene);
        expectSymbol(']');
        return Vec(x, y, z);
    }

    /// Analyse an InputStream and return a Color (r,g,b) - Parameter: scene (Scene)
    pure Color parseColor(in Scene scene)
    {
        expectSymbol('<');
        immutable red = expectNumber(scene);
        expectSymbol(',');
        immutable green = expectNumber(scene);
        expectSymbol(',');
        immutable blue = expectNumber(scene);
        expectSymbol('>');
        return Color(red, green, blue);
    }

    /// Analyse an InputStream and return a Pigment - Parameter: scene (Scene)
    Pigment parsePigment(in Scene scene)
    {
        immutable Keyword pigKeyword = expectKeyword([Keyword.uniform, Keyword.checkered, Keyword.image]);
        Pigment pigment;

        expectSymbol('(');
        switch (pigKeyword)
        {
            case Keyword.uniform:
                immutable col = parseColor(scene);
                pigment = new UniformPigment(col);
                break;

            case Keyword.checkered:
                immutable col1 = parseColor(scene);
                expectSymbol(',');
                immutable col2 = parseColor(scene);
                expectSymbol(',');
                immutable numOfSteps = cast(int)(expectNumber(scene));
                pigment = new CheckeredPigment(col1, col2, numOfSteps);
                break;

            case Keyword.image:
                string fileName = expectString();
                HDRImage img = new HDRImage(fileName);
                pigment = new ImagePigment(img);
                break;

            default:
                assert(0, "This line should be unreachable");
        }

        expectSymbol(')');
        return pigment;
    }

    /// Analyse an InputStream and return a BRDF - Parameter: scene (Scene)
    BRDF parseBRDF(in Scene scene)
    {
        immutable Keyword brdfKeyword = expectKeyword([Keyword.diffuse, Keyword.specular]);
        expectSymbol('(');
        Pigment pigment = parsePigment(scene);
        expectSymbol(')');

        switch (brdfKeyword)
        {
            case Keyword.diffuse:
                return new DiffuseBRDF(pigment);

            case Keyword.specular:
                return new SpecularBRDF(pigment);

            default:
                assert(0, "This line should be unreachable");
        }
    }

    /// Analyse an InputStream and return a Material - Parameter: scene (Scene)
    Tuple!(string, Material) parseMaterial(in Scene scene)
    {
        string materialName = expectIdentifier;
        expectSymbol('(');
        BRDF brdf = parseBRDF(scene);
        expectSymbol(',');
        Pigment emittedRadiance = parsePigment(scene);
        expectSymbol(')');
        return tuple(materialName, Material(brdf, emittedRadiance));
    }

    /// Analyse an InputStream and return a Transformation - Parameter: scene (Scene)
    pure Transformation parseTransformation(in Scene scene)
    {
        Transformation transf;

        while (true)
        {
            immutable Keyword transfKeyword = expectKeyword([Keyword.identity,
                Keyword.translation,
                Keyword.rotationX,
                Keyword.rotationY,
                Keyword.rotationZ,
                Keyword.scaling]);

            switch (transfKeyword)
            {
                case Keyword.identity:
                    break;

                case Keyword.translation:
                    expectSymbol('(');
                    transf = transf * translation(parseVector(scene));
                    expectSymbol(')');
                    break;

                case Keyword.rotationX:
                    expectSymbol('(');
                    transf = transf * rotationX(expectNumber(scene));
                    expectSymbol(')');
                    break;

                case Keyword.rotationY:
                    expectSymbol('(');
                    transf = transf * rotationY(expectNumber(scene));
                    expectSymbol(')');
                    break;

                case Keyword.rotationZ:
                    expectSymbol('(');
                    transf = transf * rotationZ(expectNumber(scene));
                    expectSymbol(')');
                    break;

                case Keyword.scaling:
                    expectSymbol('(');
                    transf = transf * scaling(parseVector(scene));
                    expectSymbol(')');
                    break;

                default:
                    assert(0, "This line should be unreachable");
            }

            Token nextKeyword = readToken;
            if (!nextKeyword.hasTokenValue('*'))
            {
                unreadToken(nextKeyword);
                break;
            }
        }

        return transf;
    }

    // Analyse an InputStream and return a Sphere - Parameter: scene (Scene)
    pure Sphere parseSphere(Scene scene)
    {
        expectSymbol('(');

        string materialName = expectIdentifier;
        if ((materialName in scene.materials) is null)
            throw new GrammarError(format("Unknown material %s at %s", materialName, location.toString));

        expectSymbol(',');
        Transformation transf = parseTransformation(scene);
        expectSymbol(')');

        return new Sphere(transf, scene.materials[materialName]);
    }

    // Analyse an InputStream and return a Plane - Parameter: scene (Scene)
    pure Plane parsePlane(Scene scene)
    {
        expectSymbol('(');

        string materialName = expectIdentifier;
        if ((materialName in scene.materials) is null)
            throw new GrammarError(format("Unknown material %s at %s", materialName, location.toString));

        expectSymbol(',');
        Transformation transf = parseTransformation(scene);
        expectSymbol(')');

        return new Plane(transf, scene.materials[materialName]);
    }

    // Analyse an InputStream and return an AABox - Parameter: scene (Scene)
    pure AABox parseAABox(Scene scene)
    {
        expectSymbol('(');

        string materialName = expectIdentifier;
        if ((materialName in scene.materials) is null)
            throw new GrammarError(format("Unknown material %s at %s", materialName, location.toString));

        expectSymbol(',');
        Transformation transf = parseTransformation(scene);
        expectSymbol(')');

        return new AABox(transf, scene.materials[materialName]);
    }

    // Analyse an InputStream and return a CylinderShell - Parameter: scene (Scene)
    pure CylinderShell parseCylinderShell(Scene scene)
    {
        expectSymbol('(');

        string materialName = expectIdentifier;
        if ((materialName in scene.materials) is null)
            throw new GrammarError(format("Unknown material %s at %s", materialName, location.toString));

        expectSymbol(',');
        Transformation transf = parseTransformation(scene);
        expectSymbol(')');

        return new CylinderShell(transf, scene.materials[materialName]);
    }

    // Analyse an InputStream and return a Cylinder - Parameter: scene (Scene)
    pure Cylinder parseCylinder(Scene scene)
    {
        expectSymbol('(');

        string materialName = expectIdentifier;
        if ((materialName in scene.materials) is null)
            throw new GrammarError(format("Unknown material %s at %s", materialName, location.toString));

        expectSymbol(',');
        Transformation transf = parseTransformation(scene);
        expectSymbol(')');

        return new Cylinder(transf, scene.materials[materialName]);
    }

    // Analyse an InputStream and return a Camera - Parameter: scene (Scene)
    pure Camera parseCamera(in Scene scene)
    {
        expectSymbol('(');
        immutable Keyword cameraType = expectKeyword([Keyword.orthogonal, Keyword.perspective]);
        expectSymbol(',');
        Transformation transf = parseTransformation(scene);
        expectSymbol(',');
        immutable float aspectRatio = expectNumber(scene);
        expectSymbol(',');
        immutable float distance = expectNumber(scene);
        expectSymbol(')');
        switch (cameraType)
        {
            case Keyword.orthogonal:
                return new OrthogonalCamera(aspectRatio, transf);

            case Keyword.perspective:
                return new PerspectiveCamera(distance, aspectRatio, transf);

            default:
                assert(0, "This line should be unreachable");
        }
    }

    // Analyse an InputStream, read the scene description and return a Scene - Parameters: a tuple of a string and a float
    Scene parseScene(float[string] variables = null)
    {
        Scene scene;
        scene.floatVars = variables.dup;
        scene.overriddenVars = make!RedBlackTree(variables.keys);

        while (true)
        {
            Token what = readToken;

            if (what.isSpecificType!StopToken) break;
            if (!what.isSpecificType!KeywordToken)
                throw new GrammarError(
                    format("%s Expected a keyword instead of %s",
                    what.location.toString, what.stringTokenValue));

            string whatKw = what.stringTokenValue;
            if (whatKw == Keyword.floatKeyword)
            {
                string varName = expectIdentifier;
                SourceLocation varLocation = location;

                expectSymbol('(');
                immutable float varValue = expectNumber(scene);
                expectSymbol(')');

                if ((varName in scene.floatVars) !is null && varName !in scene.overriddenVars)
                    throw new GrammarError(
                        format("%s Variable %s cannot be redefined", varLocation.toString, varName));
                if (varName !in scene.overriddenVars) scene.floatVars[varName] = varValue;
            }
            else if (whatKw == Keyword.sphere)
                scene.world.addShape(parseSphere(scene));
            else if (whatKw == Keyword.plane)
                scene.world.addShape(parsePlane(scene));
            else if (whatKw == Keyword.aabox)
                scene.world.addShape(parseAABox(scene));
            else if (whatKw == Keyword.cylinderShell)
                scene.world.addShape(parseCylinderShell(scene));
            else if (whatKw == Keyword.cylinder)
                scene.world.addShape(parseCylinder(scene));
            else if (whatKw == Keyword.camera)
            {
                if (!scene.cam.isNull) throw new GrammarError(
                    format("%s Camera definible only once", what.location.toString));
                scene.cam = parseCamera(scene);
            }
            else if (whatKw == Keyword.material)
            {
                Tuple!(string, Material) newMaterial = parseMaterial(scene);
                scene.materials[newMaterial[0]] = newMaterial[1];
            }
        }

        return scene;
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

// RBTree probably not needed for our purposes. Associative arrays probably works better
// in this case and best choice would be void[0][string]. Not clear how it works, though.
import std.container.rbtree;
struct Scene
{
    Material[string] materials;
    World world;
    Nullable!Camera cam;
    float[string] floatVars;
    auto overriddenVars = make!(RedBlackTree!string);
}

///
unittest
{
    string stream = "float clock(150)

    material skyMaterial(
        diffuse(uniform(<0, 0, 0>)),
        uniform(<0.7, 0.5, 1>)
    )

    # Here is a comment

    material groundMaterial(
        diffuse(checkered(<0.3, 0.5, 0.1>,
                            <0.1, 0.2, 0.5>, 4)),
        uniform(<0, 0, 0>)
    )

    material sphereMaterial(
        specular(uniform(<0.5, 0.5, 0.5>)),
        uniform(<0, 0, 0>)
    )

    plane (skyMaterial, translation([0, 0, 100]) * rotationY(clock))
    plane (groundMaterial, identity)

    sphere(sphereMaterial, translation([0, 0, 1]))

    camera(perspective, rotationZ(30) * translation([-4, 0, 1]), 1.0, 2.0)";

    auto inpStr = InputStream(stream, "");
    Scene scene = inpStr.parseScene();

    // Verify that the float variables are correct
    assert(scene.floatVars.length == 1);
    assert(("clock" in scene.floatVars) !is null);
    assert(scene.floatVars["clock"] == 150.0);

    // Verify that the materials are correct
    assert(scene.materials.length == 3);
    assert(("sphereMaterial" in scene.materials) !is null);
    assert(("skyMaterial" in scene.materials) !is null);
    assert(("groundMaterial" in scene.materials) !is null);

    auto sphereMaterial = scene.materials["sphereMaterial"];
    auto skyMaterial = scene.materials["skyMaterial"];
    auto groundMaterial = scene.materials["groundMaterial"];

    auto skyBRDF = cast(DiffuseBRDF)(skyMaterial.brdf);
    assert(is(typeof(skyBRDF) == DiffuseBRDF));
    auto skyPigment = cast(UniformPigment)(skyBRDF.pigment);
    assert(is(typeof(skyPigment) == UniformPigment));
    assert(skyPigment.color.colorIsClose(Color(0.0, 0.0, 0.0)));
    auto skyEmitted = cast(UniformPigment)(skyMaterial.emittedRadiance);
    assert(is(typeof(skyEmitted) == UniformPigment));
    assert(skyEmitted.color.colorIsClose(Color(0.7, 0.5, 1.0)));

    auto groundBRDF = cast(DiffuseBRDF)(groundMaterial.brdf);
    assert(is(typeof(groundBRDF) == DiffuseBRDF));
    auto groundPigment = cast(CheckeredPigment)(groundBRDF.pigment);
    assert(is(typeof(groundPigment) == CheckeredPigment));
    assert(groundPigment.color1.colorIsClose(Color(0.3, 0.5, 0.1)));
    assert(groundPigment.color2.colorIsClose(Color(0.1, 0.2, 0.5)));
    assert(groundPigment.numberOfSteps == 4);
    auto groundEmitted = cast(UniformPigment)(groundMaterial.emittedRadiance);
    assert(is(typeof(groundEmitted) == UniformPigment));
    assert(groundEmitted.color.colorIsClose(Color(0.0, 0.0, 0.0)));

    auto sphereBRDF = cast(SpecularBRDF)(sphereMaterial.brdf);
    assert(is(typeof(sphereBRDF) == SpecularBRDF));
    auto spherePigment = cast(UniformPigment)(sphereBRDF.pigment);
    assert(is(typeof(spherePigment) == UniformPigment));
    assert(spherePigment.color.colorIsClose(Color(0.5, 0.5, 0.5)));
    auto sphereEmitted = cast(UniformPigment)(sphereMaterial.emittedRadiance);
    assert(is(typeof(sphereEmitted) == UniformPigment));
    assert(sphereEmitted.color.colorIsClose(Color(0.0, 0.0, 0.0)));

    // Verify that the shapes are correct
    assert(scene.world.shapes.length == 3);
    auto plane1 = cast(Plane)(scene.world.shapes[0]);
    assert(is(typeof(plane1) == shapes.Plane));
    assert(plane1.transf.transfIsClose(translation(Vec(0.0, 0.0, 100.0)) * rotationY(150.0)));
    auto plane2 = cast(Plane)(scene.world.shapes[1]);
    assert(is(typeof(plane2) == shapes.Plane));
    assert(plane2.transf.transfIsClose(Transformation()));
    auto sphere = cast(Sphere)(scene.world.shapes[2]);
    assert(is(typeof(sphere) == shapes.Sphere));
    assert(sphere.transf.transfIsClose(translation(Vec(0.0, 0.0, 1.0))));

    // Verify that the camera is correct
    auto sceneCam = cast(PerspectiveCamera)(scene.cam.get());
    assert(is(typeof(sceneCam) == PerspectiveCamera));
    Transformation cameraTransf = rotationZ(30.0) * translation(Vec(-4.0, 0.0, 1.0));
    assert(sceneCam.transformation.transfIsClose(cameraTransf));
    assert(areClose(sceneCam.aspectRatio, 1.0));
    assert(areClose(sceneCam.d, 2.0));
}

///
unittest
{
    // Verify that unknown materials raise a GrammarError
    string stream = "plane(thisMaterialDoesNotExist, identity)";
    auto inpStr = InputStream(stream, "");

    try
    {
        Scene scene = inpStr.parseScene();
        assert(0, "the code did not throw an exception");
    }
    catch (GrammarError exc) {}
}

///
unittest
{
    // Verify that defining two cameras in the same file raises a GrammarError
    string stream = "camera(perspective, rotationZ(30) * translation([-4, 0, 1]), 1.0, 1.0)
    camera(orthogonal, identity, 1.0, 1.0)";
    auto inpStr = InputStream(stream, "");

    try
    {
        Scene scene = inpStr.parseScene();
        assert(0, "the code did not throw an exception");
    }
    catch (GrammarError exc) {}
}