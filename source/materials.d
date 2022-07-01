module materials;

import geometry : createONBFromZ, Normal, Point, Vec, Vec2d;
import hdrimage : black, Color, HDRImage, white;
import std.math : abs, acos, cos, floor, PI, sin, sqrt;
import pcg;
import ray;

/// Verify if a floating point number given is included in the Real interval [0.0, 1.0]
pure nothrow @nogc @safe bool validParm(in float coordinate)
{
    return coordinate >= 0.0 && coordinate <= 1.0;
}

// ************************* Pigment *************************
/// Class representing a Pigment
class Pigment
{
    /// Get the Color of a given bidimensional vector: Vec2d (u, v)
    abstract pure nothrow @nogc @safe Color getColor(in Vec2d uv) const
    in (validParm(uv.u) && validParm(uv.v));
}

// ************************* UniformPigment *************************
/// Class representing a Pigment with a Uniform Color
class UniformPigment : Pigment
{
    Color color;

    /// Build a UniformPigment - Parameter: Color
    pure nothrow @nogc @safe this(in Color col = black)
    {
        color = col;
    }

    /// Get the Color of a given bidimensional vector: Vec2d (u, v)
    override pure nothrow @nogc @safe Color getColor(in Vec2d uv) const
    in (validParm(uv.u) && validParm(uv.v))
    {
        return color;
    }
}

///
unittest
{
    auto c = Color(1.0, 2.0, 3.0);
    auto p = new UniformPigment(c);

    // getColor
    assert(p.getColor(Vec2d(0.0, 0.0)).colorIsClose(c));
    assert(p.getColor(Vec2d(1.0, 0.0)).colorIsClose(c));
    assert(p.getColor(Vec2d(0.0, 1.0)).colorIsClose(c));
    assert(p.getColor(Vec2d(1.0, 1.0)).colorIsClose(c));
}

// ************************* CheckeredPigment *************************
/// Class representing a Checkered Pigment made up of 2 Colors
class CheckeredPigment : Pigment
{
    Color color1, color2;
    int numberOfSteps = 10;

    /// Build a CheckeredPigment - Parameters: 2 Colors
    pure nothrow @nogc @safe this(in Color c1, in Color c2)
    {
        color1 = c1;
        color2 = c2;
    }

    /// Build a CheckeredPigment - Parameters: 2 Colors, number of steps (int)
    pure nothrow @nogc @safe this(in Color c1, in Color c2, in int nSteps)
    in (nSteps >= 0)
    {
        this(c1, c2);
        numberOfSteps = nSteps;
    }
    /// Get the Color of a given bidimensional vector: Vec2d (u, v)
    override pure nothrow @nogc @safe Color getColor(in Vec2d uv) const
    in (validParm(uv.u) && validParm(uv.v))
    {
        immutable u = cast(int)(floor(uv.u * numberOfSteps));
        immutable v = cast(int)(floor(uv.v * numberOfSteps));
        return (u % 2) == (v % 2) ? color1 : color2;
    }
}

///
unittest
{
    auto c1 = Color(1.0, 2.0, 3.0), c2 = Color(10.0, 20.0, 30.0);
    auto p = new CheckeredPigment(c1, c2, 2);

    // getColor
    assert(p.getColor(Vec2d(0.25, 0.25)).colorIsClose(c1));
    assert(p.getColor(Vec2d(0.75, 0.25)).colorIsClose(c2));
    assert(p.getColor(Vec2d(0.25, 0.75)).colorIsClose(c2));
    assert(p.getColor(Vec2d(0.75, 0.75)).colorIsClose(c1));
}

// ************************* ImagePigment *************************
/// Class representing a Pigment made up of an Image
class ImagePigment : Pigment
{
    HDRImage image;

    pure nothrow @nogc @safe this(HDRImage img)
    {
        image = img;
    }

    /// Get the Color of a given bidimensional vector: Vec2d (u, v)
    override pure nothrow @nogc @safe Color getColor(in Vec2d uv) const
    in (validParm(uv.u) && validParm(uv.v))
    {
        auto col = cast(int)(uv.u * image.width);
        auto row = cast(int)(uv.v * image.height);

        if (col >= image.width) col = image.width - 1;
        if (row >= image.height) row = image.height - 1;

        return image.getPixel(col, row);
    }
}

///
unittest
{
    auto img = new HDRImage(2, 2);

    img.setPixel(0, 0, Color(1.0, 2.0, 3.0));
    img.setPixel(1, 0, Color(2.0, 3.0, 1.0));
    img.setPixel(0, 1, Color(2.0, 1.0, 3.0));
    img.setPixel(1, 1, Color(3.0, 2.0, 1.0));

    auto p = new ImagePigment(img);
    // getColor
    assert(p.getColor(Vec2d(0.0, 0.0)).colorIsClose(Color(1.0, 2.0, 3.0)));
    assert(p.getColor(Vec2d(1.0, 0.0)).colorIsClose(Color(2.0, 3.0, 1.0)));
    assert(p.getColor(Vec2d(0.0, 1.0)).colorIsClose(Color(2.0, 1.0, 3.0)));
    assert(p.getColor(Vec2d(1.0, 1.0)).colorIsClose(Color(3.0, 2.0, 1.0)));
}

// ************************* BRDF *************************
/// Class of a Bidirectional Reflectance Distribution Function (BRDF)
class BRDF
{
    Pigment pigment;

    /// Build a BRDF - Parameter: Pigment
    pure nothrow @nogc @safe this(Pigment p = new UniformPigment(white))
    {
        pigment = p;
    }

    /// Evaluate the Color in a 2D point (u, v) - Parameters: Normal, inDir and ourDir (Vec), Vec2d
    abstract pure nothrow @safe Color eval(
        in Normal n, in Vec inDir, in Vec outDir, in Vec2d uv
        ) const;

    /// Return the Ray that is diffuse by an object
    abstract pure nothrow @nogc @safe Ray scatterRay(
        PCG pcg,
        in Vec incomingDir,
        in Point interactionPoint,
        in Normal n,
        in int depth
        ) const;
}

// ************************* DiffuseBRDF *************************
/// Class of a Diffuse BRDF
class DiffuseBRDF : BRDF
{
    float reflectance = 1.0;

    /// Build a DiffuseBRDF - Parameters: Pigment, reflectance (float)
    ///
    /// Use super(p) with the pigment given
    pure nothrow @nogc @safe this(
        Pigment p = new UniformPigment(white), in float refl = 1.0
        )
    in (refl > 0.0)
    {
        super(p);
        reflectance = refl;
    }

    /// Build a DiffuseBRDF - Parameter: reflectance (float)
    ///
    /// Use super(): the pigment is Uniform and white
    pure nothrow @nogc @safe this(in float refl)
    in (refl > 0.0)
    {
        reflectance = refl;
    }

    /// Evaluate the Color in a 2D point (u, v) - Parameters: Normal, inDir and ourDir (Vec), Vec2d
    override pure nothrow @nogc @safe Color eval(
        in Normal n, in Vec inDir, in Vec outDir, in Vec2d uv
        ) const
    {
        return pigment.getColor(uv) * (reflectance / PI);
    }

    /// Return the Ray that is diffuse by an object
    override pure nothrow @nogc @safe Ray scatterRay(
        PCG pcg,
        in Vec incomingDir,
        in Point interactionPoint,
        in Normal n,
        in int depth
        ) const
    {
        immutable Vec[3] e = createONBFromZ(n);
        immutable float cosSq = pcg.randomFloat;
        immutable float cosine = sqrt(cosSq), sine = sqrt(1.0 - cosSq);
        immutable float phi = 2.0 * PI * pcg.randomFloat;

        return Ray(
            interactionPoint,
            e[0] * cos(phi) * cosine + e[1] * sin(phi) * cosine + e[2] * sine,
            1e-3,
            float.infinity,
            depth
            );
    }
}

// ************************* SpecularBRDF *************************
/// Class of a Specular BRDF for mirror sufaces
class SpecularBRDF : BRDF
{
    float thresholdAngleRad = PI / 1800.0;

    /// Build a DiffuseBRDF - Parameters: Pigment, threshold angle [rad] (float)
    ///
    /// Use super(p) with the pigment given
    pure nothrow @nogc @safe this(
        Pigment p = new UniformPigment(white), in float threshold = PI / 1800.0
        )
    in (threshold > 0.0)
    {
        super(p);
        thresholdAngleRad = threshold;
    }

    /// Build a DiffuseBRDF - Parameters: threshold angle [rad] (float)
    ///
    /// Use super(): the pigment is Uniform and white
    pure nothrow @nogc @safe this(in float threshold)
    in (threshold > 0.0)
    {
        thresholdAngleRad = threshold;
    }

    /// Evaluate the Color in a 2D point (u, v) - Parameters: Normal, inDir and ourDir (Vec), Vec2d
    override pure nothrow @nogc @safe Color eval(
        in Normal n, in Vec inDir, in Vec outDir, in Vec2d uv
        ) const
    {
        immutable float thetaIn = acos(n * inDir), thetaOut = acos(n * outDir);
        return abs(thetaIn - thetaOut) < thresholdAngleRad ?
            pigment.getColor(uv) : black;
    }

    /// Return the Ray that is diffuse by an object
    override pure nothrow @nogc @safe Ray scatterRay(
        PCG pcg,
        in Vec incomingDir,
        in Point interactionPoint,
        in Normal n,
        in int depth
        ) const
    {
        immutable rayDir = incomingDir.normalize;
        immutable normal = n.toVec.normalize;
        immutable float dotProduct = normal * rayDir;
        return Ray(
            interactionPoint,
            rayDir - normal * 2.0 * dotProduct,
            1e-5,
            float.infinity,
            depth);
    }
}

// ************************* Material *************************
/// Stucture representing a Material - Parameters: BRDF, Pigment
struct Material
{
    BRDF brdf = new DiffuseBRDF();
    Pigment emittedRadiance = new UniformPigment();
}