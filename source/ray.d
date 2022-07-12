module ray;

import geometry : Point, Vec, xyzIsClose; 
import std.format : formattedWrite;

// ******************** Ray ********************
/** 
 * Struct of a 3D Ray
 * Params: 
 *  origin = (Point)
 *  dir = (Vec)
 *___
 * Default Params: 
 *  tMin = (float) = 1e-5
 *  tMax = (float) = infinity
 *  depth = (int) = 0
 */
struct Ray
{
    Point origin;
    Vec dir;
    float tMin = 1e-5, tMax = float.infinity; 
    int depth = 0;

    @safe void toString(
        scope void delegate(scope const(char)[]) @safe sink
        ) const
    {
        sink.formattedWrite!"Or:%s  Dir:%s  -  Depth: %s"(origin, dir, depth);
    }

    /**
    * Returns: the position of a Point at a given t = (Point)
    */
    pure nothrow @nogc @safe Point at(in float t) const
    {
        return origin + t * dir;
    }

    /**
    * Verify if two Ray are close
    *___
    * Params: 
    *   rhs = (Ray)
    * Returns: true or false (bool) 
    */
    pure nothrow @nogc @safe bool rayIsClose(in Ray rhs) const
    {
        return origin.xyzIsClose(rhs.origin) && dir.xyzIsClose(rhs.dir);
    }
}

///
unittest
{
    auto r1 = Ray(Point(1.0, 2.0, 3.0), Vec(5.0, 4.0, -1.0));
    auto r2 = Ray(Point(1.0, 2.0, 3.0), Vec(5.0, 4.0, -1.0));
    auto r3 = Ray(Point(5.0, 1.0, 4.0), Vec(3.0, 9.0, 4.0));

    assert(r1.rayIsClose(r2));
    assert(!r1.rayIsClose(r3));

    auto r4 = Ray(Point(1.0, 2.0, 4.0), Vec(4.0, 2.0, 1.0));

    assert(r4.at(0.0).xyzIsClose(r4.origin));
    assert(r4.at(1.0).xyzIsClose(Point(5.0, 4.0, 5.0)));
    assert(r4.at(2.0).xyzIsClose(Point(9.0, 6.0, 6.0)));
}

///
unittest
{
    import transformations : rotationX, translation;

    auto r = Ray(Point(1.0, 2.0, 3.0), Vec(6.0, 5.0, 4.0));
    auto t = translation(Vec(10.0, 11.0, 12.0)) * rotationX(90.0);
    Ray transformed = t * r;

    assert(transformed.origin.xyzIsClose(Point(11.0, 8.0, 14.0)));
    assert(transformed.dir.xyzIsClose(Vec(6.0, -4.0, 5.0)));
}