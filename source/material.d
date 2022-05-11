module material;

import hdrimage : Color, HDRImage;
import geometry : Vec2d;
import std.math : floor, PI;

class Pigment
{
    abstract Color getColor(in Vec2d uv) const;
}

class UniformPigment : Pigment
{   
    Color color;

    this(in Color col)
    {
        color = col;
    }
    
    override Color getColor(in Vec2d uv) const
    {
        return color;
    }

}

class CheckeredPigment : Pigment
{   
    Color color1, color2;
    int numberOfSteps;

    this(in Color c1, in Color c2, in int n = 10)
    {
        color1 = c1;
        color2 = c2;
        numberOfSteps = n;
    }

    override Color getColor(in Vec2d uv) const
    {
        int u = cast(int)(floor(uv.u * numberOfSteps));
        int v = cast(int)(floor(uv.v * numberOfSteps));
        
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
    {
        int col = cast(int)(uv.u * image.width);
        int row = cast(int)(uv.v * image.height);
        
        if (col >= image.width) col = image.width - 1;
        if (row >= image.height) row = image.height -1;

        return image.getPixel(col, row);
    }
}
