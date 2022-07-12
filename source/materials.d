module materials;

import geometry : createONBFromZ, Normal, Point, Vec, Vec2d;
import hdrimage : black, Color, HDRImage, white;
import std.format : formattedWrite;
import std.math : abs, acos, cos, floor, PI, sin, sqrt;
import pcg;
import ray;

/**
* Verify if a floating point number given is into the interval [0.0, 1.0]
* Params: 
*   coordinate = (float)
*/
pure nothrow @nogc @safe bool validParm(in float coordinate)
{
    return coordinate >= 0.0 && coordinate <= 1.0;
}

// ************************* Pigment *************************
/**
* Class representing a Pigment
*/
class Pigment
{
    /**
    * Get the Color of a given bidimensional vector: Vec2d (u, v)
    * Params:
    *   uv = (Vec2d)
    * Return: Color
    */
    abstract pure nothrow @nogc @safe Color getColor(in Vec2d uv) const
    in (validParm(uv.u) && validParm(uv.v));

    @trusted void toString(
        scope void delegate(scope const(char)[]) @safe sink
        ) const
    {
        if (typeid(this) == typeid(UniformPigment))
        {
            auto unif = cast(UniformPigment)this;
            sink.formattedWrite!"Uniform %s"(unif.color);
        }
        else if (typeid(this) == typeid(CheckeredPigment))
        {
            auto check = cast(CheckeredPigment)this;
            sink.formattedWrite!"Checkered %s, %s"(check.color1, check.color2);
        }
        else if (typeid(this) == typeid(ImagePigment))
        {
            auto img = cast(ImagePigment)this;
            img.image.toString(sink);
        }
        else sink("Pigment");
    }
}

// ************************* UniformPigment *************************
/**
* Class representing a Pigment with a Uniform Color
*/
class UniformPigment : Pigment
{
    Color color;

    /**
    * Build a UniformPigment
    * Params: 
        col = (Color) = black
    */
    pure nothrow @nogc @safe this(in Color col = black)
    {
        color = col;
    }

    /**
    * Get the Color of a given bidimensional vector: Vec2d (u, v)
    * Params: 
    *   uv = (Vec2d)
    * Return: Color
    */
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

    assert(p.getColor(Vec2d(0.0, 0.0)).colorIsClose(c));
    assert(p.getColor(Vec2d(1.0, 0.0)).colorIsClose(c));
    assert(p.getColor(Vec2d(0.0, 1.0)).colorIsClose(c));
    assert(p.getColor(Vec2d(1.0, 1.0)).colorIsClose(c));
}

// ************************* CheckeredPigment *************************
/**
* Class representing a Checkered Pigment made up of 2 Colors
*/
class CheckeredPigment : Pigment
{
    Color color1, color2;
    int numberOfSteps = 10;

    /**
    * Build a CheckeredPigment from 2 Colors
    * Params: 
    *   c1 = (Color)
    *   c2 = (Color)
    */
    pure nothrow @nogc @safe this(in Color c1, in Color c2)
    {
        color1 = c1;
        color2 = c2;
    }

    /**
    * Build a CheckeredPigment
    * Params: 
    *   c1 = (Color)
    *   c2 = (Color)
    *   nSteps = (int)
    */
    pure nothrow @nogc @safe this(in Color c1, in Color c2, in int nSteps)
    in (nSteps >= 0)
    {
        this(c1, c2);
        numberOfSteps = nSteps;
    }

    /**
    * Get the Color of a given bidimensional vector: Vec2d (u, v)
    * Params: 
    *   uv = (Vec2d)
    * Return: Color
    */
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

    assert(p.getColor(Vec2d(0.25, 0.25)).colorIsClose(c1));
    assert(p.getColor(Vec2d(0.75, 0.25)).colorIsClose(c2));
    assert(p.getColor(Vec2d(0.25, 0.75)).colorIsClose(c2));
    assert(p.getColor(Vec2d(0.75, 0.75)).colorIsClose(c1));
}

// ************************* ImagePigment *************************
/**
* Class representing a Pigment made up of an Image
*/
class ImagePigment : Pigment
{
    HDRImage image;

    pure nothrow @nogc @safe this(HDRImage img)
    {
        image = img;
    }

    /**
    * Get the Color of a given bidimensional vector: Vec2d (u, v)
    * Params:
    *   uv = (Vec2d)
    * Return: Color
    */
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

    assert(p.getColor(Vec2d(0.0, 0.0)).colorIsClose(Color(1.0, 2.0, 3.0)));
    assert(p.getColor(Vec2d(1.0, 0.0)).colorIsClose(Color(2.0, 3.0, 1.0)));
    assert(p.getColor(Vec2d(0.0, 1.0)).colorIsClose(Color(2.0, 1.0, 3.0)));
    assert(p.getColor(Vec2d(1.0, 1.0)).colorIsClose(Color(3.0, 2.0, 1.0)));
}

// ************************* BRDF *************************
/**
* Class of a Bidirectional Reflectance Distribution Function (BRDF)
*/
class BRDF
{
    Pigment pigment;

    /**
    * Build a BRDF
    * Params:
    *   p = (Pigment)
    */
    pure nothrow @nogc @safe this(Pigment p = new UniformPigment(white))
    {
        pigment = p;
    }

    /**
    * Evaluate the Color in a 2D point (u, v)
    * Params: 
    *   n = (Normal)
    *   inDir = (Vec) 
    *   ourDir = (Vec)
    *   uv = (Vec2d)
    */
    abstract pure nothrow @nogc @safe Color eval(
        in Normal n, in Vec inDir, in Vec outDir, in Vec2d uv
        ) const;

    /**
    * Return the Ray that is diffuse by an object
    * Params: 
    *   pcg = (PCG)
    *   incomingDir = (Vec)
    *   interactionPoint = (Point)
    *   n = (Normal)
    *   depth = (int)
    */
    abstract pure nothrow @nogc @safe Ray scatterRay(
        PCG pcg,
        in Vec incomingDir,
        in Point interactionPoint,
        in Normal n,
        in int depth
        ) const;
    
    /** 
    * Convert a Pigment into a string 
    */
    @trusted void toString(
        scope void delegate(scope const(char)[]) @safe sink
        ) const
    {
        pigment.toString(sink);
    }
}

// ************************* DiffuseBRDF *************************
/**
* Class of a Diffuse BRDF
*/
class DiffuseBRDF : BRDF
{
    float reflectance = 1.0;

    /**
    * Build a DiffuseBRDF 
    * Params: 
    *   p = (Pigment)
    *   reflectance = (float)
    *___
    * Use super(p) with the pigment given
    */
    pure nothrow @nogc @safe this(
        Pigment p = new UniformPigment(white), in float refl = 1.0
        )
    in (refl > 0.0)
    {
        super(p);
        reflectance = refl;
    }

    /**
    * Build a DiffuseBRDF
    * Params: reflectance = (float)
    *___
    * Use super(): the pigment is Uniform and white
    */
    pure nothrow @nogc @safe this(in float refl)
    in (refl > 0.0)
    {
        reflectance = refl;
    }

    /**
    * Evaluate the Color in a 2D point (u, v) 
    * Params: 
    *   n = (Normal)
    *   inDir = (Vec)
    *   ourDir = (Vec)
    *   uv = (Vec2d)
    * Return: Color
    */
    override pure nothrow @nogc @safe Color eval(
        in Normal n, in Vec inDir, in Vec outDir, in Vec2d uv
        ) const
    {
        return pigment.getColor(uv) * (reflectance / PI);
    }

    /**
    * Return the Ray that is diffuse by an object
    * Params: 
    *   pcg = (PCG)
    *   incomingDir = (Vec)
    *   interactionPoint = (Point),
    *   n = (Normal)
    *   depth = (int)
    * Return: Ray
    */
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

    /**
    * Convert a DiffuseBRDF to a string
    */
    override @trusted void toString(
        scope void delegate(scope const(char)[]) @safe sink
        ) const
    {
        sink("Diffuse: ");
        super.toString(sink);
    }
}

// ************************* SpecularBRDF *************************
/**
* Class of a Specular BRDF for mirror sufaces
*/
class SpecularBRDF : BRDF
{
    float thresholdAngleRad = PI / 1800.0;

    /**
    * Build a SpecularBRDF
    * Params: 
    *   p = (Pigment) 
    *   threshold  = (float) angle [rad]
    * ___
    * Use super(p) with the pigment given
    */
    pure nothrow @nogc @safe this(
        Pigment p = new UniformPigment(white), in float threshold = PI / 1800.0
        )
    in (threshold > 0.0)
    {
        super(p);
        thresholdAngleRad = threshold;
    }

    /**
    * Build a SpecularBRDF
    * Params: 
    *   threshold = (float) angle [rad]
    * ___
    * Use super(): the pigment is Uniform and white
    */
    pure nothrow @nogc @safe this(in float threshold)
    in (threshold > 0.0)
    {
        thresholdAngleRad = threshold;
    }

    /**
    * Evaluate the Color in a 2D point (u, v)
    * Params: 
    *   n = (Normal)
    *   inDir = (Vec)
    *   ourDir = (Vec)
    *   uv = (Vec2d)
    * Return: Color
    */
    override pure nothrow @nogc @safe Color eval(
        in Normal n, in Vec inDir, in Vec outDir, in Vec2d uv
        ) const
    {
        immutable float thetaIn = acos(n * inDir), thetaOut = acos(n * outDir);
        return abs(thetaIn - thetaOut) < thresholdAngleRad ?
            pigment.getColor(uv) : black;
    }

    /**
    * Return the Ray that is diffuse by an object
    * Params:
    *   pcg = (PCG)
    *   incomingDir = (Vec)
    *   interactionPoint = (Point),
    *   n = (Normal)
    *   depth = (int)
    * Return: Ray
    */
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

    /** 
    * Convert a SpecularBRDF to a string 
    */
    override @trusted void toString(
        scope void delegate(scope const(char)[]) @safe sink
        ) const
    {
        sink("Specular: ");
        super.toString(sink);
    }
}

// ************************* Material *************************
/**
* Stucture representing a Material
* Members: 
*   brdf = (BRDF)
*   emittedRadiance = (Pigment)
*/
struct Material
{
    BRDF brdf = new DiffuseBRDF();
    Pigment emittedRadiance = new UniformPigment();

    @trusted void toString(
        scope void delegate(scope const(char)[]) @safe sink
        ) const
    {
        sink("1) ");
        brdf.toString(sink);
        sink("\n2) ");
        emittedRadiance.toString(sink);
    }
}