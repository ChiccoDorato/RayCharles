module renderer;

import hdrimage : black, Color, white;
import materials : Material;
import ray : Ray;
import shapes : World, HitRecord;
import std.typecons : Nullable;

class Renderer
{
    World world;
    Color backgroundColor;

    this(World w)
    {
        world = w;
    }

    this(World w, in Color bgCol)
    {
        this(w);
        backgroundColor = bgCol;
    }

    abstract Color call(in Ray r);
}

class OnOffRenderer : Renderer
{
    Color color = white;

    this(World w)
    {
        super(w);
    }
    
    this(World w, in Color bgCol, in Color col)
    {
        super(w, bgCol);
        color = col;
    }

    override Color call(in Ray r)
    {
        return world.rayIntersection(r).isNull ? backgroundColor : color;
    }
}

class FlatRenderer : Renderer
{
    this(World w)
    {
        super(w);
    }

    this(World w, in Color bgCol)
    {
        super(w, bgCol);
    }

    override Color call(in Ray r)
    {
        Nullable!HitRecord hit = world.rayIntersection(r);
        if (hit.isNull) return backgroundColor;

        Material material = hit.get.shape.material;
        return material.brdf.pigment.getColor(hit.get.surfacePoint) + 
        material.emittedRadiance.getColor(hit.get.surfacePoint);   
    }
}
