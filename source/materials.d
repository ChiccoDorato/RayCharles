module materials;

import geometry : createONBFromZ, Normal, Point, Vec, Vec2d;
import hdrimage : black, Color, HDRImage, white;
import pcg : PCG;
import ray : Ray;
import std.math : cos, floor, PI, sin, sqrt;

immutable(bool) validParm(in float coordinate)
{
    return coordinate >= 0 && coordinate <= 1;
}

class Pigment
{
    abstract Color getColor(in Vec2d uv) const
    in (validParm(uv.u) && validParm(uv.v));
}

class UniformPigment : Pigment
{
    Color color;

    this(in Color col)
    {
        color = col;
    }

    override Color getColor(in Vec2d uv) const
    in (validParm(uv.u) && validParm(uv.v))
    {
        return color;
    }
}

unittest
{
    Color c = {1.0, 2.0, 3.0};
    Pigment p = new UniformPigment(c);

    assert(p.getColor(Vec2d(0.0, 0.0)).colorIsClose(c));
    assert(p.getColor(Vec2d(1.0, 0.0)).colorIsClose(c));
    assert(p.getColor(Vec2d(0.0, 1.0)).colorIsClose(c));
    assert(p.getColor(Vec2d(1.0, 1.0)).colorIsClose(c));
}

class CheckeredPigment : Pigment
{
    Color color1, color2;
    int numberOfSteps = 10;

    this(in Color c1, in Color c2)
    {
        color1 = c1;
        color2 = c2;
    }

    this(in Color c1, in Color c2, in int nSteps)
    in (nSteps >= 0)
    {
        this(c1, c2);
        numberOfSteps = nSteps;
    }

    override Color getColor(in Vec2d uv) const
    in (validParm(uv.u) && validParm(uv.v))
    {
        immutable int u = cast(int)(floor(uv.u * numberOfSteps));
        immutable int v = cast(int)(floor(uv.v * numberOfSteps));

        return (u % 2) == (v % 2) ? color1 : color2;
    }
}

unittest
{
    Color c1 = {1.0, 2.0, 3.0};
    Color c2 = {10.0, 20.0, 30.0};

    Pigment p = new CheckeredPigment(c1, c2, 2);

    assert(p.getColor(Vec2d(0.25, 0.25)).colorIsClose(c1));
    assert(p.getColor(Vec2d(0.75, 0.25)).colorIsClose(c2));
    assert(p.getColor(Vec2d(0.25, 0.75)).colorIsClose(c2));
    assert(p.getColor(Vec2d(0.75, 0.75)).colorIsClose(c1));
}

class ImagePigment : Pigment
{
    HDRImage image;

    this(HDRImage img)
    {
        image = img;
    }

    override Color getColor(in Vec2d uv) const
    in (validParm(uv.u) && validParm(uv.v))
    {
        int col = cast(int)(uv.u * image.width);
        int row = cast(int)(uv.v * image.height);

        if (col >= image.width) col = image.width - 1;
        if (row >= image.height) row = image.height - 1;

        return image.getPixel(col, row);
    }
}

unittest
{
    HDRImage img = new HDRImage(2, 2);

    img.setPixel(0, 0, Color(1.0, 2.0, 3.0));
    img.setPixel(1, 0, Color(2.0, 3.0, 1.0));
    img.setPixel(0, 1, Color(2.0, 1.0, 3.0));
    img.setPixel(1, 1, Color(3.0, 2.0, 1.0));

    Pigment p = new ImagePigment(img);

    assert(p.getColor(Vec2d(0.0, 0.0)).colorIsClose(Color(1.0, 2.0, 3.0)));
    assert(p.getColor(Vec2d(1.0, 0.0)).colorIsClose(Color(2.0, 3.0, 1.0)));
    assert(p.getColor(Vec2d(0.0, 1.0)).colorIsClose(Color(2.0, 1.0, 3.0)));
    assert(p.getColor(Vec2d(1.0, 1.0)).colorIsClose(Color(3.0, 2.0, 1.0)));
}

class BRDF
{
    Pigment pigment;

    this(Pigment p = new UniformPigment(white))
    {
        pigment = p;
    }

    abstract Color eval(in Normal n, in Vec inDir, in Vec outDir, in Vec2d uv) const;

    abstract Ray scatterRay(PCG pcg,
        in Vec incomingDir,
        in Point interactionPoint,
        in Normal n,
        in int depth) const;
}

class DiffuseBRDF : BRDF
{
    float reflectance = 1.0;

    this(Pigment p = new UniformPigment(white))
    {
        super(p);
    }

    this(Pigment p = new UniformPigment(white), in float refl = 1.0)
    in (refl > 0.0)
    {
        this(p);
        reflectance = refl;
    }

    override Color eval(in Normal n, in Vec inDir, in Vec outDir, in Vec2d uv) const
    {
        return pigment.getColor(uv) * (reflectance / PI);
    }

    override Ray scatterRay(PCG pcg,
        in Vec incomingDir,
        in Point interactionPoint,
        in Normal n,
        in int depth) const
    {
        immutable(Vec[3]) e = createONBFromZ(n);
        immutable(float) cosThetaSq = pcg.randomFloat;
        immutable(float) cosTheta = sqrt(cosThetaSq), sinTheta = sqrt(1.0 - cosThetaSq);
        immutable(float) phi = 2.0 * PI * pcg.randomFloat;
        return Ray(interactionPoint,
            e[0] * cos(phi) * cosTheta + e[1] * sin(phi) * cosTheta + e[2] * sinTheta,
            1e-3,
            float.infinity,
            depth);
    }
}

struct Material
{
    BRDF brdf = new DiffuseBRDF();
    Pigment emittedRadiance = new UniformPigment(black);
}