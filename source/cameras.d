import geometry;
import std.math;

struct Ray
{
    Point origin;
    Vec dir;
    float tMin = 1e-5;
    float tMax = float.infinity; 
    int depth = 0;

    Point at(float t)
    {
        return origin + t*dir;
    }

    bool isClose(Ray rhs, float epsilon = 1e-5)
    {
        return(origin.xyzIsClose(rhs.origin) && dir.xyzIsClose(rhs.dir));
    }
}

unittest
{
    Ray ray1 = Ray(Point(1.0, 2.0, 3.0), Vec(5.0, 4.0, -1.0));
    Ray ray2 = Ray(Point(1.0, 2.0, 3.0), Vec(5.0, 4.0, -1.0));
    Ray ray3 = Ray(Point(5.0, 1.0, 4.0), Vec(3.0, 9.0, 4.0));

    assert(ray1.isClose(ray2));
    assert(!ray1.isClose(ray3));

    
    Ray ray4 = Ray(Point(1.0, 2.0, 4.0), Vec(4.0, 2.0, 1.0));
    assert(ray4.at(0.0).xyzIsClose(ray4.origin));
    assert(ray4.at(1.0).xyzIsClose(Point(5.0, 4.0, 5.0)));
    assert(ray4.at(2.0).xyzIsClose(Point(9.0, 6.0, 6.0)));
}