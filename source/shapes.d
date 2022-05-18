module shapes;

import std.algorithm : max, min, swap;
import geometry : Normal, Point, Vec, Vec2d, vecX, vecY, vecZ;
import hdrimage : areClose;
import materials : Material;
import ray;
import std.math : acos, atan2, floor, PI, sqrt;
import std.typecons : Nullable;
import transformations : Transformation, translation, rotationY;

struct HitRecord
{
    Point worldPoint;
    Normal normal;
    Vec2d surfacePoint;
    float t;
    Ray ray;
    Shape shape;

    immutable(bool) recordIsClose(in HitRecord hit) const
    {
        return worldPoint.xyzIsClose(hit.worldPoint) && normal.xyzIsClose(hit.normal) &&
        surfacePoint.uvIsClose(hit.surfacePoint) && areClose(t, hit.t) && ray.rayIsClose(hit.ray);
    }
}

class Shape
{
    Transformation transf;
    Material material;

    this(in Transformation t = Transformation(), Material m = Material())
    {
        transf = t;
        material = m;
    }

    abstract Nullable!HitRecord rayIntersection(in Ray r);

    abstract bool quickRayIntersection(in Ray r) const;
}

class Sphere : Shape
{
    this(in Transformation t = Transformation(), Material m = Material())
    {
        super(t, m);
    }

    immutable(Vec2d) sphereUVPoint(in Point p) const
    {   
        float z = p.z;
        if (z < -1 && z > -1.001) z = -1;
        if (z > 1 && z < 1.001) z = 1;

        float u = atan2(p.y, p.x) / (2.0 * PI);
        if (u < 0) ++u;
        return immutable Vec2d(u, acos(z) / PI);
    }

    immutable(Normal) sphereNormal(in Point p, in Vec v) const
    {
        immutable Normal n = Normal(p.x, p.y, p.z);
        return p.convert * v < 0 ? n : -n;
    }

    override Nullable!HitRecord rayIntersection(in Ray r)
    {
        immutable Ray invR = transf.inverse * r;
        immutable Vec originVec = invR.origin.convert;
        immutable float halfB = originVec * invR.dir;
        immutable float a = invR.dir.squaredNorm;
        immutable float c = originVec.squaredNorm - 1.0;
        immutable float reducedDelta = halfB * halfB - a * c;

        Nullable!HitRecord hit;
        if (reducedDelta < 0) return hit;

        immutable float t1 = (-halfB - sqrt(reducedDelta)) / a;
        immutable float t2 = (-halfB + sqrt(reducedDelta)) / a;

        float firstHit;
        if (t1 > invR.tMin && t1 < invR.tMax) firstHit = t1;
        else if (t2 > invR.tMin && t2 < invR.tMax) firstHit = t2;
        else return hit;

        immutable Point hitPoint = invR.at(firstHit);
        hit = HitRecord(
            transf * hitPoint,
            transf * sphereNormal(hitPoint, invR.dir),
            sphereUVPoint(hitPoint),
            firstHit,
            r,
            this);
        return hit;
    }

    override bool quickRayIntersection(in Ray r) const
    {
        immutable Ray invR = transf.inverse * r;
        immutable Vec originVec = invR.origin.convert;
        immutable float halfB = originVec * invR.dir;
        immutable float a = invR.dir.squaredNorm;
        immutable float c = originVec.squaredNorm - 1.0;

        immutable float reducedDelta = halfB * halfB - a * c;
        if (reducedDelta <= 0.0) return false;

        immutable float t1 = (-halfB - sqrt(reducedDelta)) / a;
        immutable float t2 = (-halfB + sqrt(reducedDelta)) / a;

        return (t1 > invR.tMin && t1 < invR.tMax) || (t2 > invR.tMin && t2 < invR.tMax);
    }
}

unittest
{   
    Sphere s = new Sphere();

    assert(s.rayIntersection(Ray(Point(0.0, 10.0, 2.0), -vecZ)).isNull);

    Ray r1 = {Point(0.0, 0.0, 2.0), -vecZ};
    HitRecord h1 = s.rayIntersection(r1).get(HitRecord());
    assert(HitRecord(
        Point(0.0, 0.0, 1.0),
        Normal(0.0, 0.0, 1.0),
        Vec2d(0.0, 0.0),
        1.0,
        r1).recordIsClose(h1));

    Ray r2 = {Point(3.0, 0.0, 0.0), -vecX};
    HitRecord h2 = s.rayIntersection(r2).get(HitRecord());
    assert(HitRecord(
        Point(1.0, 0.0, 0.0),
        Normal(1.0, 0.0, 0.0),
        Vec2d(0.0, 0.5),
        2.0,
        r2).recordIsClose(h2));

    Ray r3 = {Point(0.0, 0.0, 0.0), vecX};
    HitRecord h3 = s.rayIntersection(r3).get(HitRecord());
    assert(HitRecord(
        Point(1.0, 0.0, 0.0),
        Normal(-1.0, 0.0, 0.0),
        Vec2d(0.0, 0.5),
        1.0,
        r3).recordIsClose(h3));
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
        r1).recordIsClose(h1));
    
    Ray r2 = {Point(13.0, 0.0, 0.0), -vecX};
    HitRecord h2 = s.rayIntersection(r2).get(HitRecord());
    assert(HitRecord(
        Point(11.0, 0.0, 0.0),
        Normal(1.0, 0.0, 0.0),
        Vec2d(0.0, 0.5),
        2.0,
        r2).recordIsClose(h2));
}

// A 3D infinite plane parallel to the x and y axis and passing through the origin.
class Plane : Shape
{
    this(in Transformation t = Transformation(), Material m = Material())
    {
        super(t, m);
    }

    override Nullable!HitRecord rayIntersection(in Ray r)
    {
        Nullable!HitRecord hit;

        immutable Ray invR = transf.inverse * r;
        if (areClose(invR.dir.z, 0)) return hit;

        immutable float t = -invR.origin.z / invR.dir.z;
        if (t <= invR.tMin || t >= invR.tMax) return hit;

        immutable Point hitPoint = invR.at(t);
        hit = HitRecord(transf * hitPoint,
            transf * Normal(0.0, 0.0, invR.dir.z < 0 ? 1.0 : -1.0),
            Vec2d(hitPoint.x - floor(hitPoint.x), hitPoint.y - floor(hitPoint.y)),
            t,
            r,
            this);
        return hit;
    }

    override bool quickRayIntersection(in Ray r) const
    {
        Ray invR = transf.inverse * r;
        if (areClose(invR.dir.z, 0)) return false;

        float t = -invR.origin.z / invR.dir.z;
        if (t < invR.tMin || t > invR.tMax) return false; 

        return true;
    }
}

unittest
{
    Plane p = new Plane();

    Ray r1 = {Point(0.0, 0.0, 1.0), -vecZ};
    HitRecord h1 = p.rayIntersection(r1).get(HitRecord());
    assert(HitRecord(
        Point(0.0, 0.0, 0.0),
        Normal(0.0, 0.0, 1.0),
        Vec2d(0.0, 0.0),
        1.0,
        r1).recordIsClose(h1));

    Ray r2 = {Point(0.0, 0.0, 1.0), vecZ};
    Nullable!HitRecord h2 = p.rayIntersection(r2);
    assert(h2.isNull);

    Ray r3 = {Point(0.0, 0.0, 1.0), vecX};
    Nullable!HitRecord h3 = p.rayIntersection(r3);
    assert(h3.isNull);

    Ray r4 = {Point(0.0, 0.0, 1.0), vecY};
    Nullable!HitRecord h4 = p.rayIntersection(r4);
    assert(h4.isNull);
}

 unittest
{
    Plane p = new Plane(rotationY(90.0));

    Ray r1 = {Point(1.0, 0.0, 0.0), -vecX};
    HitRecord h1 = p.rayIntersection(r1).get(HitRecord());
    assert(HitRecord(
        Point(0.0, 0.0, 0.0),
        Normal(1.0, 0.0, 0.0),
        Vec2d(0.0, 0.0),
        1.0,
        r1).recordIsClose(h1));

    Ray r2 = {Point(0.0, 0.0, 1.0), vecZ};
    Nullable!HitRecord h2 = p.rayIntersection(r2);
    assert(h2.isNull);

    Ray r3 = {Point(0.0, 0.0, 1.0), vecX};
    Nullable!HitRecord h3 = p.rayIntersection(r3);
    assert(h3.isNull);

    Ray r4 = {Point(0.0, 0.0, 1.0), vecY};
    Nullable!HitRecord h4 = p.rayIntersection(r4);
    assert(h4.isNull);
}

unittest
{
    Plane p = new Plane();

    Ray r1 = {Point(0.0, 0.0, 1.0), -vecZ};
    HitRecord h1 = p.rayIntersection(r1).get;
    assert(h1.surfacePoint.uvIsClose(Vec2d(0.0, 0.0)));

    Ray r2 = {Point(0.25, 0.75, 1), -vecZ};
    HitRecord h2 = p.rayIntersection(r2).get;
    assert(h2.surfacePoint.uvIsClose(Vec2d(0.25, 0.75)));

    Ray r3 = {Point(4.25, 7.75, 1), -vecZ};
    HitRecord h3 = p.rayIntersection(r3).get;
    assert(h3.surfacePoint.uvIsClose(Vec2d(0.25, 0.75)));
}

class AABox : Shape
{
    Point pMin, pMax;

    this(in Transformation t = Transformation(), Material m = Material())
    {
        super(t, m);

        pMin = t * Point(0.0, 0.0, 0.0);
        pMax = t * Point(1.0, 1.0, 1.0);
        if (pMin.x > pMax.x) swap(pMin.x, pMax.x);
        if (pMin.y > pMax.y) swap(pMin.y, pMax.y);
        if (pMin.z > pMax.z) swap(pMin.y, pMax.y);
    }

    float[2] intersections(in Ray r) const
    {
        float tx1 = pMin.x - r.origin.x / r.dir.x;
        float tx2 = pMax.x - r.origin.x / r.dir.x;
        if (r.dir.x < 0) swap(tx1, tx2);

        float ty1 = pMin.y - r.origin.y / r.dir.y;
        float ty2 = pMax.y - r.origin.y / r.dir.y;
        if (r.dir.y < 0) swap(ty1, ty2);

        float tz1 = pMin.z - r.origin.z / r.dir.z;
        float tz2 = pMax.z - r.origin.z / r.dir.z;
        if (r.dir.z < 0) swap(tz1, tz2);
        return [max(tx1, ty1, tz1), min(tx2, ty2, tz2)];
    }

    override Nullable!HitRecord rayIntersection(in Ray r)
    {
        Nullable!HitRecord hit;

        immutable Ray invR = transf.inverse * r;
        if (areClose(invR.dir.x, 0) || areClose(invR.dir.y, 0) || areClose(invR.dir.z, 0))
            return hit;

        immutable float[2] t = intersections(invR);
        float firstHit;
        if (t[0] > t[1]) return hit;
        if (t[0] > invR.tMin && t[0] < invR.tMax) firstHit = t[0];
        else if (t[1] > invR.tMin && t[1] < invR.tMax) firstHit = t[1];
        else return hit;

        // immutable Point hitPoint = invR.at(firstHit);
        // hit = HitRecord(transf * hitPoint,
        //     transf * Normal(0.0, 0.0, invR.dir.z < 0 ? 1.0 : -1.0),
        //     Vec2d(hitPoint.x - floor(hitPoint.x), hitPoint.y - floor(hitPoint.y)),
        //     t,
        //     r,
        //     this);

        return hit;
    }

    override bool quickRayIntersection(in Ray r) const
    {
        immutable Ray invR = transf.inverse * r;
        if (areClose(invR.dir.x, 0) || areClose(invR.dir.y, 0) || areClose(invR.dir.z, 0))
            return false;

        immutable float[2] t = intersections(invR);
        return (invR.tMin < t[0] && t[0] < t[1] && t[1] < invR.tMax) ? true : false;
    }
}

struct World
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

    Nullable!HitRecord rayIntersection(in Ray ray)
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

    immutable(bool) isPointVisible(in Point point, in Point obsPos)
    {
        immutable Vec direction = point - obsPos;
        immutable Ray ray = {obsPos, direction, 1e-2 / direction.norm, 1.0};

        foreach (Shape s; shapes) if (s.quickRayIntersection(ray)) return false;

        return true;
    }
}

unittest
{
    World world;

    Sphere s1 = new Sphere(translation(vecX * 2.0));
    Sphere s2 = new Sphere(translation(vecX * 8.0));
    world.addShape(s1);
    world.addShape(s2);

    Nullable!HitRecord intersection1 = world.rayIntersection(Ray(Point(0.0, 0.0, 0.0), vecX));
    assert(!intersection1.isNull);
    assert(intersection1.get.worldPoint.xyzIsClose(Point(1.0, 0.0, 0.0)));
    
    Nullable!HitRecord intersection2 = world.rayIntersection(Ray(Point(10.0, 0.0, 0.0), -vecX));
    assert(!intersection2.isNull);
    assert(intersection2.get.worldPoint.xyzIsClose(Point(9.0, 0.0, 0.0)));
}

unittest
{
    World world;

    Sphere s1 = new Sphere(translation(vecX * 2.0));
    Sphere s2 = new Sphere(translation(vecX * 8.0));
    world.addShape(s1);
    world.addShape(s2);

    assert(!world.isPointVisible(Point(10.0, 0.0, 0.0), Point(0.0, 0.0, 0.0)));
    assert(!world.isPointVisible(Point(5.0, 0.0, 0.0), Point(0.0, 0.0, 0.0)));
    assert(world.isPointVisible(Point(5.0, 0.0, 0.0), Point(4.0, 0.0, 0.0)));
    assert(world.isPointVisible(Point(0.5, 0.0, 0.0), Point(0.0, 0.0, 0.0)));
    assert(world.isPointVisible(Point(0.0, 10.0, 0.0), Point(0.0, 0.0, 0.0)));
    assert(world.isPointVisible(Point(0.0, 0.0, 10.0), Point(0.0, 0.0, 0.0)));
}