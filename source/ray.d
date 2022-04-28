import geometry : Point, Vec, xyzIsClose; 
import transformations : rotationX, Transformation, translation;

struct Ray
{
    Point origin;
    Vec dir;
    float tMin = 1e-5, tMax = float.infinity; 
    int depth = 0;

    Point at(float t)
    {
        return origin + t * dir;
    }

    bool rayIsClose(Ray rhs)
    {
        return origin.xyzIsClose(rhs.origin) && dir.xyzIsClose(rhs.dir);
    }
}

unittest
{
    Ray r1 = {Point(1.0, 2.0, 3.0), Vec(5.0, 4.0, -1.0)};
    Ray r2 = {Point(1.0, 2.0, 3.0), Vec(5.0, 4.0, -1.0)};
    Ray r3 = {Point(5.0, 1.0, 4.0), Vec(3.0, 9.0, 4.0)};

    assert(r1.rayIsClose(r2));
    assert(!r1.rayIsClose(r3));

    Ray r4 = {Point(1.0, 2.0, 4.0), Vec(4.0, 2.0, 1.0)};
    assert(r4.at(0.0).xyzIsClose(r4.origin));
    assert(r4.at(1.0).xyzIsClose(Point(5.0, 4.0, 5.0)));
    assert(r4.at(2.0).xyzIsClose(Point(9.0, 6.0, 6.0)));
}

unittest
{
    Ray r = {Point(1.0, 2.0, 3.0), Vec(6.0, 5.0, 4.0)};
    Transformation t = translation(Vec(10.0, 11.0, 12.0)) * rotationX(90.0);
    Ray transformed = t * r;

    assert(transformed.origin.xyzIsClose(Point(11.0, 8.0, 14.0)));
    assert(transformed.dir.xyzIsClose(Vec(6.0, -4.0, 5.0)));
}