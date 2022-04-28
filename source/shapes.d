module shapes;

import geometry : Normal, Point, Vec, Vec2d, vecX, vecZ;
import hdrimage : areClose;
import ray : Ray;
import std.math : atan2, acos, PI, sqrt;
import std.typecons : Nullable;
import transformations : Transformation;

struct HitRecord
{
    Point worldPoint;
    Normal normal;
    Vec2d surfacePoint;
    float t;
    Ray ray;

    bool recordIsClose(HitRecord hit)
    {
        return worldPoint.xyzIsClose(hit.worldPoint) && normal.xyzIsClose(hit.normal) &&
        surfacePoint.uvIsClose(hit.surfacePoint) && areClose(t, hit.t) && ray.rayIsClose(hit.ray);
    }
}

class Shape
{
    Transformation transf;

    abstract Nullable!HitRecord rayIntersection(Ray r);
}

class Sphere : Shape
{
    override Nullable!HitRecord rayIntersection(Ray r)
    {
        Ray invR = transf.inverse * r;
        Vec originVec = invR.origin.convert;
        float halfB = originVec * invR.dir;
        float a = invR.dir.squaredNorm;
        float c = originVec.squaredNorm - 1.0;
        float reducedDelta = halfB * halfB - a * c;

        Nullable!HitRecord hit;
        if (reducedDelta < 0) return hit;

        float t1 = (- halfB - sqrt(reducedDelta)) / a;
        float t2 = (- halfB + sqrt(reducedDelta)) / a;

        float firstHit;
        if (t1 > invR.tMin && t1 < invR.tMax) firstHit = t1;
        else if (t2 > invR.tMin && t2 < invR.tMax) firstHit = t2;
        else return hit;

        return hit;
    }
}

/* unittest
{   
    Sphere s = new Sphere;
// RAY 1
    Ray r1 = {Point(0.0, 0.0, 2.0), -vecZ};
    HitRecord h1 = HitRecord(s.rayIntersection(r1));

    Point p1 = Point(0.0, 0.0, 1.0);
    assert(p1.xyzIsClose(h1.worldPoint));

    Normal n1 = vecZ.convert;
    assert(n1.xyzIsClose(h1.normal));

    Vec2d uv1 = Vec2d(atan2(0.0,0.0)/(2*PI), acos(1.0)/PI);
    assert(uv1.uvIsClose(h1.surfacePoint));

    float t1 = 1.0;
    assert(areClose(t1, h1.t));
// RAY 2
    Ray r2 = {Point(3.0, 0.0, 0.0), -vecX};
    HitRecord h2 = HitRecord(s.rayIntersection(r2));

    Point p2 = Point(0.0, 0.0, 0.0);
    assert(p1.xyzIsClose(h2.worldPoint));

    Normal n2 = vecZ.convert;
    assert(n2.xyzIsClose(h2.normal));

    Vec2d uv2 = Vec2d(atan2(0.0,0.0)/(2*PI), acos(0.0)/PI);
    assert(uv1.uvIsClose(h2.surfacePoint));

    float t2 = 2.0;
    assert(areClose(t2, h2.t));
// RAY 3
    Ray ray3 = {Point(3.0, 0.0, 0.0), vecX};
    HitRecord h3 = HitRecord(s.rayIntersection(r3));

    Point p3 = Point(1.0, 0.0, 0.0);
    assert(p3.xyzIsClose(h3.worldPoint));

    Normal n3 = vecZ.convert;
    assert(n3.xyzIsClose(h3.normal));

    Vec2d uv3 = Vec2d(atan2(0.0,1.0)/(2*PI), acos(0.0)/PI);
    assert(uv3.uvIsClose(h3.surfacePoint));

    float t3 = 1.0;
    assert(areClose(t3, h3.t));
} */