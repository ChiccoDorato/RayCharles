module shapes;

import geometry : Normal, Point, Vec, Vec2d, vecX, vecZ;
import hdrimage : areClose;
import ray : Ray;
import std.math : abs, acos, atan2, PI, sqrt, floor;
import std.typecons : Nullable;
import transformations : Transformation, translation;

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

Vec2d sphereUVPoint(Point p)
{
    float u = atan2(p.y, p.x) / (2.0 * PI);
    if (u < 0) ++u;
    return Vec2d(u, acos(p.z) / PI);
}

Normal sphereNormal(Point p, Vec v)
{
    Normal n = Normal(p.x, p.y, p.z);
    return p.convert * v < 0 ? n : -n;
}

class Sphere : Shape
{
    this(Transformation t)
    {
        transf = t;
    }

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

        float t1 = (-halfB - sqrt(reducedDelta)) / a;
        float t2 = (-halfB + sqrt(reducedDelta)) / a;

        float firstHit;
        if (t1 > invR.tMin && t1 < invR.tMax) firstHit = t1;
        else if (t2 > invR.tMin && t2 < invR.tMax) firstHit = t2;
        else return hit;

        Point hitPoint = invR.at(firstHit);
        hit = HitRecord(
            transf * hitPoint,
            transf * sphereNormal(hitPoint, invR.dir),
            sphereUVPoint(hitPoint),
            firstHit,
            r
            );
        return hit;
    }
}

unittest
{   
    Sphere s = new Sphere(Transformation());

    assert(s.rayIntersection(Ray(Point(0.0, 10.0, 2.0), -vecZ)).isNull);

    // RAY 1
    Ray r1 = {Point(0.0, 0.0, 2.0), -vecZ};
    HitRecord h1 = s.rayIntersection(r1).get(HitRecord());
    assert(HitRecord(
        Point(0.0, 0.0, 1.0),
        Normal(0.0, 0.0, 1.0),
        Vec2d(0.0, 0.0),
        1.0,
        r1
        ).recordIsClose(h1));

    // RAY 2
    Ray r2 = {Point(3.0, 0.0, 0.0), -vecX};
    HitRecord h2 = s.rayIntersection(r2).get(HitRecord());
    assert(HitRecord(
        Point(1.0, 0.0, 0.0),
        Normal(1.0, 0.0, 0.0),
        Vec2d(0.0, 0.5),
        2.0,
        r2
        ).recordIsClose(h2));

    // RAY 3
    Ray r3 = {Point(0.0, 0.0, 0.0), vecX};
    HitRecord h3 = s.rayIntersection(r3).get(HitRecord());
    assert(HitRecord(
        Point(1.0, 0.0, 0.0),
        Normal(-1.0, 0.0, 0.0),
        Vec2d(0.0, 0.5),
        1.0,
        r3
        ).recordIsClose(h3));
}

unittest
{
    Sphere s = new Sphere(translation(Vec(10.0, 0.0, 0.0)));

    // Check if the sphere was actually translated by trying to hit the untrasformed shape.
    assert(s.rayIntersection(Ray(Point(0.0, 0.0, 2.0), -vecZ)).isNull);

    // Check if the inverse transformation was wrongly applied.
    assert(s.rayIntersection(Ray(Point(-10.0, 0.0, 0.0), -vecZ)).isNull);

    Ray r1 = {Point(10.0, 0.0, 2.0), -vecZ};
    HitRecord h1 = s.rayIntersection(r1).get(HitRecord());
    assert(HitRecord(
        Point(10.0, 0.0, 1.0),
        Normal(0.0, 0.0, 1.0),
        Vec2d(0.0, 0.0),
        1.0,
        r1
        ).recordIsClose(h1));
    
    Ray r2 = {Point(13.0, 0.0, 0.0), -vecX};
    HitRecord h2 = s.rayIntersection(r2).get(HitRecord());
    assert(HitRecord(
        Point(11.0, 0.0, 0.0),
        Normal(1.0, 0.0, 0.0),
        Vec2d(0.0, 0.5),
        2.0,
        r2
        ).recordIsClose(h2));
}

class World
{
    Shape[] shapes;

    this(Shape[] s)
    {
        shapes = s;
    }

    void addShape(Shape s)
    {
        shapes ~= s;
    }

    Nullable!HitRecord rayIntersection(Ray ray)
    {
        Nullable!HitRecord closest;
        Nullable!HitRecord intersection;

        foreach (Shape s; shapes)
        {
            intersection = s.rayIntersection(ray);
            if (intersection.isNull) continue;
            if (closest.isNull || intersection.get.t < closest.get.t) closest = intersection;
        }
        return closest;
    }
}

class Plane : Shape
{
    this(Transformation t)
    {
        transf = t;
    }

    override Nullable!HitRecord rayIntersection(Ray ray)
    {
        Nullable!HitRecord hit;
        Ray invR = transf.inverse * ray;
        Vec originVec = invR.origin.convert;
        if(abs(invR.dir.z < 1e-5)) return hit;

        float t = -originVec.z / invR.dir.z;
        if(t <= invR.tMin || t>= invR.tMax) return hit;

        Point hitPoint = invR.at(t);
        float z=1;
        if(invR.dir.z < 0.0)

        hit = HitRecord(transf*invR,
                    transf*Normal(0,0,z), 
                    Vec2d(hitPoint.x - floor(hitPoint.x), hitPoint.y - floor(hitPoint.y)),
                    t,
                    ray);
        return hit;


        float halfB = originVec * invR.dir;
        float a = invR.dir.squaredNorm;
        float c = originVec.squaredNorm - 1.0;
        float reducedDelta = halfB * halfB - a * c;

        if (reducedDelta < 0) return hit;

        float t1 = (-halfB - sqrt(reducedDelta)) / a;
        float t2 = (-halfB + sqrt(reducedDelta)) / a;

        float firstHit;
        if (t1 > invR.tMin && t1 < invR.tMax) firstHit = t1;
        else if (t2 > invR.tMin && t2 < invR.tMax) firstHit = t2;
        else return hit;

        Point hitPoint = invR.at(firstHit);
        hit = HitRecord(
            transf * hitPoint,
            transf * sphereNormal(hitPoint, invR.dir),
            sphereUVPoint(hitPoint),
            firstHit,
            r
            );
        return hit;
    }
}