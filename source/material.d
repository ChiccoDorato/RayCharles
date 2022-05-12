module material;

import geometry : Normal, Vec, Vec2d;
import hdrimage : black, Color, HDRImage, white;
import std.math : floor, PI;

immutable(bool) validParam(in float coordinate)
{
    return coordinate >= 0 && coordinate <= 1;
}

class Pigment
{
    abstract Color getColor(in Vec2d uv) const
    in (validParam(uv.u) && validParam(uv.v));
}

class UniformPigment : Pigment
{
    Color color;

    this(in Color col = black)
    {
        color = col;
    }

    override Color getColor(in Vec2d uv) const
    in (validParam(uv.u) && validParam(uv.v))
    {
        return color;
    }
}

class CheckeredPigment : Pigment
{
    Color color1, color2;
    int numberOfSteps;

    this(in Color c1, in Color c2, in int nSteps = 10)
    in (nSteps >= 0)
    {
        color1 = c1;
        color2 = c2;
        numberOfSteps = nSteps;
    }

    override Color getColor(in Vec2d uv) const
    in (validParam(uv.u) && validParam(uv.v))
    {
        immutable int u = cast(int)(floor(uv.u * numberOfSteps));
        immutable int v = cast(int)(floor(uv.v * numberOfSteps));

        return (u % 2) == (v % 2) ? color1 : color2;
    }
}

class ImagePigment : Pigment
{
    HDRImage image;

    this(HDRImage img)
    {
        image = img;
    }

    override Color getColor(in Vec2d uv) const
    in (validParam(uv.u) && validParam(uv.v))
    {
        int col = cast(int)(uv.u * image.width);
        int row = cast(int)(uv.v * image.height);

        if (col >= image.width) col = image.width - 1;
        if (row >= image.height) row = image.height - 1;

        return image.getPixel(col, row);
    }
}

class BRDF
{
    Pigment pigment;

    this(Pigment p = new UniformPigment(white))
    {
        pigment = p;
    }

    abstract Color eval(in Normal n, in Vec inDir, in Vec outDir, in Vec2d uv) const;
}

class DiffuseBRDF : BRDF
{
    float reflectance;

    this(Pigment p = new UniformPigment(white), in float refl = 1.0)
    in (refl > 0.0)
    {
        super(p);
        reflectance = refl;
    }

    override Color eval(in Normal n, in Vec inDir, in Vec outDir, in Vec2d uv) const
    {
        return pigment.getColor(uv) * (reflectance / PI);
    }
}

struct Material
{
    BRDF brdf = new DiffuseBRDF();
    Pigment emittedRadiance = new UniformPigment(black);
}