module shapes;

import std.algorithm : max, min, swap;
import geometry : Normal, Point, Vec, Vec2d, vecX, vecY, vecZ;
import hdrimage : areClose;
import materials : Material;
import ray;
import std.math : abs, acos, atan2, floor, PI, sqrt;
import std.typecons : Nullable;
import transformations : scaling, Transformation, translation, rotationX, rotationY, rotationZ;

///******************** HitRecord ********************
/// Struct HitRecord to keep in memory infos about intersection of a ray with an object 
struct HitRecord
{
    Point worldPoint;
    Normal normal;
    Vec2d surfacePoint;
    float t;
    Ray ray;
    Shape shape;

    /// Check if two HitRecord are close by calling the fuction areClose for every member
    pure nothrow @nogc @safe bool recordIsClose(in HitRecord hit) const
    {
        return worldPoint.xyzIsClose(hit.worldPoint) && normal.xyzIsClose(hit.normal) &&
        surfacePoint.uvIsClose(hit.surfacePoint) && areClose(t, hit.t) && ray.rayIsClose(hit.ray);
    }
}

///******************** Shape ********************
/// Abstract class for a generic Shape
class Shape
{
    Transformation transf;
    Material material;

    pure nothrow @safe this(in Transformation t = Transformation(), Material m = Material())
    {
        transf = t;
        material = m;
    }

    /// Abstract method - Check and record an intersection between a Ray and a Shape
    abstract pure nothrow @safe Nullable!HitRecord rayIntersection(in Ray r);
    /// Abstract method - Look up quickly for intersection between a Ray and a Shape
    abstract pure nothrow @nogc @safe bool quickRayIntersection(in Ray r) const;
}

///******************** Sphere ********************
/// Class for a 3D Sphere centered in the origin of the axis
class Sphere : Shape
{
    /// Build a sphere - also with a tranformation and a material
    pure nothrow @safe this(in Transformation t = Transformation(), Material m = Material())
    {
        super(t, m);
    }

    /// Convert a 3D point (x, y, z) on the Sphere in a 2D point (u, v) on the screen/Image
    pure nothrow @nogc @safe Vec2d sphereUVPoint(in Point p) const
    {
        float z = p.z;
        if (z < -1 && z > -1.001) z = -1;
        if (z > 1 && z < 1.001) z = 1;

        immutable float u = atan2(p.y, p.x) / (2.0 * PI);
        return Vec2d(u < 0 ? u + 1 : u, acos(z) / PI);
    }

    /// Create a Normal to a Vector in a Point of the Sphere
    pure nothrow @nogc @safe Normal sphereNormal(in Point p, in Vec v) const
    {
        immutable Normal n = Normal(p.x, p.y, p.z);
        return p.convert * v < 0 ? n : -n;
    }

    /// Check and record an intersection between a Ray and a Sphere
    override pure nothrow @safe Nullable!HitRecord rayIntersection(in Ray r)
    {
        immutable Ray invR = transf.inverse * r;
        immutable Vec originVec = invR.origin.convert;

        immutable float halfB = originVec * invR.dir;
        immutable float a = invR.dir.squaredNorm;
        immutable float c = originVec.squaredNorm - 1.0;
        immutable float reducedDelta = halfB * halfB - a * c;

        Nullable!HitRecord hit;
        if (reducedDelta < 0.0) return hit;

        immutable float t1 = (-halfB - sqrt(reducedDelta)) / a;
        immutable float t2 = (-halfB + sqrt(reducedDelta)) / a;

        float firstHit;
        if (t1 > invR.tMin && t1 < invR.tMax) firstHit = t1;
        else if (t2 > invR.tMin && t2 < invR.tMax) firstHit = t2;
        else return hit;

        immutable Point hitPoint = invR.at(firstHit);
        hit = HitRecord(transf * hitPoint,
            transf * sphereNormal(hitPoint, invR.dir),
            sphereUVPoint(hitPoint),
            firstHit,
            r,
            this);
        return hit;
    }

    /// Look up quickly for intersection between a Ray and a Shape
    override pure nothrow @nogc @safe bool quickRayIntersection(in Ray r) const
    {
        immutable Ray invR = transf.inverse * r;
        immutable Vec originVec = invR.origin.convert;

        immutable float halfB = originVec * invR.dir;
        immutable float a = invR.dir.squaredNorm;
        immutable float c = originVec.squaredNorm - 1.0;
        immutable float reducedDelta = halfB * halfB - a * c;

        if (reducedDelta < 0.0) return false;

        immutable float t1 = (-halfB - sqrt(reducedDelta)) / a;
        immutable float t2 = (-halfB + sqrt(reducedDelta)) / a;
        return (t1 > invR.tMin && t1 < invR.tMax) || (t2 > invR.tMin && t2 < invR.tMax);
    }
}

///
unittest
{
    Sphere s = new Sphere();

    // rayIntersection with the Sphere
    assert(s.rayIntersection(Ray(Point(0.0, 10.0, 2.0), -vecZ)).isNull);

    Ray r1 = {Point(0.0, 0.0, 2.0), -vecZ};
    HitRecord h1 = s.rayIntersection(r1).get(HitRecord());

    // recordIsClose
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

/// 
unittest
{
    Sphere s = new Sphere(translation(Vec(10.0, 0.0, 0.0)));

    // Verify if the Sphere is correctly translated
    assert(s.rayIntersection(Ray(Point(0.0, 0.0, 2.0), -vecZ)).isNull);
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

///******************** Plane ********************
/// Class for a 3D infinite plane parallel to the x and y axis and passing through the origin
class Plane : Shape
{
    /// Build a plane - also with a tranformation and a material
    pure nothrow @safe this(in Transformation t = Transformation(), Material m = Material())
    {
        super(t, m);
    }

    /// Check and record an intersection between a Ray and a Plane
    override pure nothrow @safe Nullable!HitRecord rayIntersection(in Ray r)
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

    /// Look up quickly for an intersection between a Ray and a Plane
    override pure nothrow @nogc @safe bool quickRayIntersection(in Ray r) const
    {
        Ray invR = transf.inverse * r;
        if (areClose(invR.dir.z, 0)) return false;

        float t = -invR.origin.z / invR.dir.z;
        if (t < invR.tMin || t > invR.tMax) return false; 

        return true;
    }
}

///
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

    // rayIntersection with the Plane
    assert(h2.isNull);

    Ray r3 = {Point(0.0, 0.0, 1.0), vecX};
    Nullable!HitRecord h3 = p.rayIntersection(r3);
    assert(h3.isNull);

    Ray r4 = {Point(0.0, 0.0, 1.0), vecY};
    Nullable!HitRecord h4 = p.rayIntersection(r4);
    assert(h4.isNull);
}

///
unittest
{
    Plane p = new Plane(rotationY(90.0));

    Ray r1 = {Point(1.0, 0.0, 0.0), -vecX};
    HitRecord h1 = p.rayIntersection(r1).get(HitRecord());

    // Verify if the Plane is correctly rotated
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

///
unittest
{
    Plane p = new Plane();

    Ray r1 = {Point(0.0, 0.0, 1.0), -vecZ};
    HitRecord h1 = p.rayIntersection(r1).get;

    // uvIsClose 
    assert(h1.surfacePoint.uvIsClose(Vec2d(0.0, 0.0)));

    Ray r2 = {Point(0.25, 0.75, 1), -vecZ};
    HitRecord h2 = p.rayIntersection(r2).get;
    assert(h2.surfacePoint.uvIsClose(Vec2d(0.25, 0.75)));

    Ray r3 = {Point(4.25, 7.75, 1), -vecZ};
    HitRecord h3 = p.rayIntersection(r3).get;
    assert(h3.surfacePoint.uvIsClose(Vec2d(0.25, 0.75)));
}

///******************** AABox ********************
/// Class for a 3D Axis Aligned Box
class AABox : Shape
{
    /// Build an AABox - also with a transformation and a material
    pure nothrow @safe this(in Transformation t = Transformation(), Material m = Material())
    {
        super(t, m);
    }

    pure nothrow @safe this(in Point min, in Point max,
        in float xAngleInDegrees = 0.0, in float yAngleInDegrees = 0.0,
        in float zAngleInDegrees = 0.0, Material m = Material())
    {
        Transformation scale = scaling(max - min);
        Transformation transl = translation(min.convert);

        Transformation rotation;
        if (xAngleInDegrees % 360 != 0) rotation = rotationX(xAngleInDegrees) * rotation;
        if (yAngleInDegrees % 360 != 0) rotation = rotationY(yAngleInDegrees) * rotation;
        if (zAngleInDegrees % 360 != 0) rotation = rotationZ(zAngleInDegrees) * rotation;

        transf = transl * rotation * scale;
        material = m;
    }

    pure nothrow @nogc @safe float[2] box1DIntersections(in float origin, in float direction) const 
    {
        if(areClose(direction, 0))
            return (origin >= 0) && (origin <= 1) ?
                [-float.infinity, float.infinity] : [float.infinity, -float.infinity];

        float t1, t2;
        if (direction > 0)
        {
            t1 = -origin / direction;
            t2 = (1 - origin) / direction;
        }
        else
        {
            t1 = (1 - origin) / direction;
            t2 = -origin / direction;
        }
        return [t1, t2];
    }

    pure nothrow @nogc @safe float[2] boxIntersections(in Ray r) const
    {
        float[2] tX = box1DIntersections(r.origin.x, r.dir.x);
        float[2] tY = box1DIntersections(r.origin.y, r.dir.y);
        float[2] tZ = box1DIntersections(r.origin.z, r.dir.z);
        return [max(tX[0], tY[0], tZ[0]), min(tX[1], tY[1], tZ[1])];
    }

    pure nothrow @nogc @safe Vec2d boxUVPoint(in Point p) const
    {
        if (areClose(p.x, 0)) return Vec2d((1 + p.y) / 3, (2 + p.z) / 4);
        else if (areClose(p.x, 1.0)) return Vec2d((1 + p.y) / 3, (1 - p.z) / 4);
        else if (areClose(p.y, 0.0)) return Vec2d((1 - p.x) / 3, (2 + p.z) / 4);
        else if (areClose(p.y, 1.0)) return Vec2d((2 + p.x) / 3, (2 + p.z) / 4);
        else if (areClose(p.z, 0.0)) return Vec2d((1 + p.y) / 3, (2 - p.x) / 4);
        else
        {
            assert(areClose(p.z, 1.0));
            return Vec2d((1 + p.y) / 3, (3 + p.x) / 4);
        }
    }

    pure nothrow @nogc @safe Normal boxNormal(in Point p, in Vec v) const
    {
        if (areClose(p.x, 0) || areClose(p.x, 1))
            return Normal(v.x < 0 ? 1.0 : -1.0, 0.0, 0.0);
        else if (areClose(p.y, 0) || areClose(p.y, 1))
            return Normal(0.0, v.y < 0 ? 1.0 : -1.0, 0.0);
        else
        {
            assert(areClose(p.z, 0) || areClose(p.z, 1));
            return Normal(0.0, 0.0, v.z < 0 ? 1.0 : -1.0);
        }
    }

    override pure nothrow @safe Nullable!HitRecord rayIntersection(in Ray r)
    {
        Nullable!HitRecord hit;

        immutable Ray invR = transf.inverse * r;
        immutable float[2] t = boxIntersections(invR);

        float firstHit;
        if (t[0] > t[1]) return hit;
        if (t[0] > invR.tMin && t[0] < invR.tMax) firstHit = t[0];
        else if (t[1] > invR.tMin && t[1] < invR.tMax) firstHit = t[1];
        else return hit;

        immutable Point hitPoint = invR.at(firstHit);
        hit = HitRecord(transf * hitPoint,
            transf * boxNormal(hitPoint, invR.dir),
            boxUVPoint(hitPoint),
            firstHit,
            r,
            this);

        return hit;
    }

    override pure nothrow @nogc @safe bool quickRayIntersection(in Ray r) const
    {
        immutable Ray invR = transf.inverse * r;
        immutable float[2] t = boxIntersections(invR);
        if (t[0] > t[1] || t[0] >= invR.tMax || t[1] <= invR.tMin) return false;
        return (t[0] > invR.tMin) || (t[1] < invR.tMax) ? true : false;
    }
}

unittest
{
    Vec translVec = {1.0, 2.0, 4.0}, scaleVec = {-2.0, 3.0, 1.0};
    Transformation scale = scaling(scaleVec);
    Transformation rotY = rotationY(-30.0);
    Transformation transl = translation(translVec);

    Point p1 = {1.0, 2.0, 4.0}, p2 = {-1.0, 5.0, 5.0};
    AABox pointsConstructorBox = new AABox(p1, p2, 0.0, 330.0, 0.0);
    assert(pointsConstructorBox.transf.transfIsClose(transl * rotY * scale));
}

unittest
{
    AABox box = new AABox();

    Ray r1 = {Point(-2.0, 0.5, 0.0), -vecX};
    assert(!box.quickRayIntersection(r1));
    Nullable!HitRecord h1 = box.rayIntersection(r1);
    assert(h1.isNull);

    Ray r2 = {Point(0.0, 0.3, 0.7), vecY};
    assert(box.quickRayIntersection(r2));
    HitRecord h2 = box.rayIntersection(r2).get(HitRecord());
    assert(HitRecord(
        Point(0.0, 1.0, 0.7),
        Normal(-1.0, 0.0, 0.0),
        Vec2d(2.0 / 3.0, 0.675),
        0.7,
        r2,
        box).recordIsClose(h2));

    Ray r3 = {Point(-4.0, -1.0, -2.0), 8.0 * vecX + 3.0 * vecY + 6.0 * vecZ};
    assert(box.quickRayIntersection(r3));
    HitRecord h3 = box.rayIntersection(r3).get(HitRecord());
    assert(HitRecord(
        Point(0.0, 0.5, 1.0),
        Normal(-1.0, 0.0, 0.0),
        Vec2d(0.5, 0.75),
        0.5,
        r3,
        box).recordIsClose(h3));
}

unittest
{
    Vec translVec = {-1.0, 2.0, 4.0}, scaleVec = {2.0, 3.0, -0.8};
    Transformation scale = scaling(scaleVec);
    Transformation rotY = rotationY(-30.0);
    Transformation transl = translation(translVec);
    
    AABox box = new AABox(transl * rotY * scale);
    float z = 4.0 - sqrt(3.0) / 3.0;

    Point p1 = {-1.0, 2.0, 4.0}, p2 = {1.0, 5.0, 3.2};
    AABox pointsConstructorBox = new AABox(p1, p2, 0.0, -30.0, 0.0);
    assert(pointsConstructorBox.transf.transfIsClose(box.transf));

    Ray r1 = {Point(-1.0, 8.0, z), -vecY};
    assert(!box.quickRayIntersection(r1));
    Nullable!HitRecord h1 = box.rayIntersection(r1);
    assert(h1.isNull);

    Ray r2 = {Point(-0.66667, 8.0, z), -vecY};
    assert(!box.quickRayIntersection(r2));
    Nullable!HitRecord h2 = box.rayIntersection(r2);
    assert(h2.isNull);

    Ray r3 = {Point(-2.0 / 3.0, 8.0, z), -vecY};
    assert(box.quickRayIntersection(r3));
    HitRecord h3 = box.rayIntersection(r3).get(HitRecord());
    assert(HitRecord(
        Point(-2.0 / 3.0, 5.0, z),
        0.5 * Normal(-sqrt(3.0) / 2.0, 0.0, -0.5),
        Vec2d(2.0 / 3.0, 17.0 / 24.0),
        3.0,
        r3,
        box).recordIsClose(h3));

    Ray r4 = {Point(-0.5, 8.0, z), -vecY};
    assert(box.quickRayIntersection(r4));
    HitRecord h4 = box.rayIntersection(r4).get(HitRecord());
    assert(HitRecord(
        Point(-0.5, 5.0, z),
        (1.0 / 3.0) * Normal(0.0, 1.0, 0.0),
        Vec2d((48.0 + sqrt(3.0)) / 72.0, 47.0 / 64.0),
        3.0,
        r4,
        box).recordIsClose(h4));

    Ray r5 = {Point(-2.0 / 5.0, 0.0, z), vecY};
    assert(box.quickRayIntersection(r5));
    HitRecord h5 = box.rayIntersection(r5).get(HitRecord());
    assert(HitRecord(
        Point(-0.4, 2.0, z),
        (1.0 / 3.0) * Normal(0.0, -1.0, 0.0),
        Vec2d((15.0 - sqrt(3.0)) / 45.0, 0.75),
        2.0,
        r5,
        box).recordIsClose(h5));

    Ray r6 = {Point(0.40001, 8.0, z), -vecY};
    assert(!box.quickRayIntersection(r6));
    Nullable!HitRecord h6 = box.rayIntersection(r6);
    assert(h6.isNull);

    Ray r7 = {Point(1.0, 8.0, z), -vecY};
    assert(!box.quickRayIntersection(r7));
    Nullable!HitRecord h7 = box.rayIntersection(r7);
    assert(h7.isNull);

    Ray vertical1 = {Point(sqrt(3.0) / 4.0 - 1.0, 3.8, 4.5), -vecZ};
    assert(box.quickRayIntersection(vertical1));
    HitRecord hVert1 = box.rayIntersection(vertical1).get(HitRecord());
    assert(HitRecord(
        Point(sqrt(3.0) / 4.0 - 1.0, 3.8, 4.25),
        1.25 * Normal(-0.5, 0.0, sqrt(3.0) / 2.0),
        Vec2d(8.0 / 15.0, 0.4375),
        0.25,
        vertical1,
        box).recordIsClose(hVert1));

    Ray vertical2 = {Point(sqrt(3.0) - 0.9, 3.0, 5.0 + 0.9 * sqrt(3.0)), -vecZ};
    assert(box.quickRayIntersection(vertical2));
    HitRecord hVert2 = box.rayIntersection(vertical2).get(HitRecord());
    assert(HitRecord(
        Point(sqrt(3.0) - 0.9, 3.0, 5.0 - 0.1 * sqrt(3.0)),
        0.5 * Normal(sqrt(3.0) / 2.0, 0.0, 0.5),
        Vec2d(4.0 / 9.0, 0.1875),
        sqrt(3.0),
        vertical2,
        box).recordIsClose(hVert2));
}

// ******************** CylinderShell ********************
/// Class for a 3D Cylinder shell (lateral suface) aligned with the z axis
class CylinderShell : Shape
{
    /// Build a Cylinder shell - also with a tranformation and a material
    pure nothrow @safe this(in Transformation t = Transformation(), Material m = Material())
    {
        super(t, m);
    }

    pure nothrow @safe this(in float radius, in Point minCenter,
        in Point maxCenter, Material m = Material())
    in (!areClose(radius, 0.0))
    in (!minCenter.xyzIsClose(maxCenter))
    {
        immutable float length = (maxCenter - minCenter).norm;
        Transformation scale = scaling(Vec(radius, radius, length));
        Transformation transl = translation(minCenter.convert);

        Transformation rotation;
        immutable float colatCosine = (maxCenter.z - minCenter.z) / length;
        if (!areClose(colatCosine, 1.0))
        {
            immutable float colatSine = 1.0 - colatCosine * colatCosine;
            rotation = rotationY(colatCosine, colatSine) * rotation;

            immutable float longCosine = (maxCenter.x - minCenter.x) / (length * colatSine);
            if (!areClose(longCosine, 1.0))
            {
                immutable float longSine = 1.0 - longCosine * longCosine;
                rotation = rotationZ(longCosine, longSine) * rotation;
            }
        }

        transf = transl * rotation * scale;
        material = m;
    }

    pure nothrow @safe this(in float radius, in float length, in Vec translVec = Vec(),
        in float xAngleInDegrees = 0.0, in float yAngleInDegrees = 0.0,
        in float zAngleInDegrees = 0.0, Material m = Material())
    in (!areClose(radius, 0.0))
    in (!areClose(length, 0.0))
    {
        Transformation scale = scaling(Vec(radius, radius, length));
        Transformation transl = translation(translVec);

        Transformation rotation;
        if (xAngleInDegrees % 360 != 0) rotation = rotationX(xAngleInDegrees) * rotation;
        if (yAngleInDegrees % 360 != 0) rotation = rotationY(yAngleInDegrees) * rotation;
        if (zAngleInDegrees % 360 != 0) rotation = rotationZ(zAngleInDegrees) * rotation;

        transf = transl * rotation * scale;
        material = m;
    }

    /// Convert a 3D point (x, y, z) on the Cylinder in a 2D point (u, v) on the screen/Image
    pure nothrow @nogc @safe Vec2d cylShellUVPoint(in Point p) const
    {
        immutable float u = atan2(p.y, p.x) / (2.0 * PI);
        return Vec2d(u < 0 ? u + 1 : u, p.z);
    }

    /// Create a Normal to a Vector in a Point of the Cylinder surface
    pure nothrow @nogc @safe Normal cylShellNormal(in Point p, in Vec v) const
    {
        immutable Normal n = Normal(p.x, p.y, 0.0);
        return p.x * v.x + p.y * v.y < 0 ? n : -n;
    }

    /// Check and record an intersection between a Ray and a Cylinder
    override pure nothrow @safe Nullable!HitRecord rayIntersection(in Ray ray)
    {
        immutable Ray invR = transf.inverse * ray;
        immutable Vec originVec = invR.origin.convert;
        Nullable!HitRecord hit;

        immutable float a = invR.dir.x * invR.dir.x + invR.dir.y * invR.dir.y;
        if (areClose(a, 0.0, 1e-10)) return hit;

        immutable float halfB = originVec.x * invR.dir.x + originVec.y * invR.dir.y;
        immutable float c = originVec.x * originVec.x + originVec.y * originVec.y - 1.0;
        immutable float reducedDelta = halfB * halfB - a * c;

        if (reducedDelta < 0.0) return hit;

        immutable float t1 = (-halfB - sqrt(reducedDelta)) / a;
        immutable float z1Hit = originVec.z + t1 * invR.dir.z;
        immutable float t2 = (-halfB + sqrt(reducedDelta)) / a;
        immutable float z2Hit = originVec.z + t2 * invR.dir.z;

        float firstHit;
        if (t1 > invR.tMin && t1 < invR.tMax && z1Hit >= 0.0 && z1Hit <= 1.0)
            firstHit = t1;
        else if (t2 > invR.tMin && t2 < invR.tMax && z2Hit >= 0.0 && z2Hit <= 1.0)
            firstHit = t2;
        else return hit;

        immutable Point hitPoint = invR.at(firstHit);
        hit = HitRecord(transf * hitPoint,
            transf * cylShellNormal(hitPoint, invR.dir),
            cylShellUVPoint(hitPoint),
            firstHit,
            ray,
            this);
        return hit;
    }

   /// Look up quickly for intersection between a Ray and a Cylinder
    override pure nothrow @nogc @safe bool quickRayIntersection(in Ray ray) const
    {
        immutable Ray invR = transf.inverse * ray;
        immutable Vec originVec = invR.origin.convert;

        immutable float a = invR.dir.x * invR.dir.x + invR.dir.y * invR.dir.y;
        if (areClose(a, 0.0, 1e-10)) return false;

        immutable float halfB = originVec.x * invR.dir.x + originVec.y * invR.dir.y;
        immutable float c = originVec.x * originVec.x + originVec.y * originVec.y - 1.0;
        immutable float reducedDelta = halfB * halfB - a * c;

        if (reducedDelta < 0.0) return false;

        immutable float t1 = (-halfB - sqrt(reducedDelta)) / a;
        immutable float z1Hit = originVec.z + t1 * invR.dir.z;
        immutable float t2 = (-halfB + sqrt(reducedDelta)) / a;
        immutable float z2Hit = originVec.z + t2 * invR.dir.z;
        return (t1 > invR.tMin && t1 < invR.tMax && z1Hit >= 0.0 && z1Hit <= 1.0)
            || (t2 > invR.tMin && t2 < invR.tMax && z2Hit >= 0.0 && z2Hit <= 1.0);
    }
}

unittest
{
    import hdrimage : Color;
    import materials : DiffuseBRDF, Material, UniformPigment;
    immutable Color cylinderColor = {0.3, 0.4, 0.8};
    UniformPigment cylinderPig = new UniformPigment(cylinderColor);
    DiffuseBRDF cylinderBRDF = new DiffuseBRDF(cylinderPig);
    Material cylinderMaterial = Material(cylinderBRDF);

    Point pMin = {-2.0, 3.0, 0.0};
    CylinderShell c1 = new CylinderShell(translation(pMin.convert) * scaling(Vec(2.0, 2.0, 2.0)), cylinderMaterial);
    CylinderShell c2 = new CylinderShell(2.0, pMin, pMin + 2 * vecZ, cylinderMaterial);
    CylinderShell c3 = new CylinderShell(2.0, 2.0, Vec(), 0.0, 0.0, 0.0, cylinderMaterial);

    Vec2d uv1, uv2, uv3;
    uv1 = c1.cylShellUVPoint(Point(3.0, 2.0, 1.0));
    uv2 = c2.cylShellUVPoint(Point(3.0, 2.0, 1.0));
    uv3 = c3.cylShellUVPoint(Point(3.0, 2.0, 1.0));
    import std.stdio;
    writeln(uv1, "  ", uv2, "  ", uv3);
}

// ******************** Cylinder ********************
/// Class for a 3D Cylinder aligned with the z axis
class Cylinder : CylinderShell
{
    /// Convert a 3D point (x, y, z) on the Cylinder in a 2D point (u, v) on the screen/Image
    pure nothrow @nogc @safe Vec2d cylinderUVPoint(in Point p) const
    {
        if (!areClose(p.z, 0.0) || !areClose(p.z, 1.0)) return cylShellUVPoint(p);
        immutable float u = atan2(p.y, p.x) / (2.0 * PI); // WRONG
        return Vec2d(u < 0 ? u + 1 : u, p.z);
    }

    /// Create a Normal to a Vector in a Point of the Cylinder surface
    pure nothrow @nogc @safe Normal cylinderNormal(in Point p, in Vec v) const
    {
        if (!areClose(p.z, 0.0) || !areClose(p.z, 1.0)) return cylShellNormal(p, v);
        immutable Normal n = Normal(0.0, 0.0, 1.0); // WRONG
        return n * v < 0 ? n : -n;
    }

    /// Check and record an intersection between a Ray and a Cylinder
    override pure nothrow @safe Nullable!HitRecord rayIntersection(in Ray ray)
    {
        immutable Ray invR = transf.inverse * ray;
        immutable Vec originVec = invR.origin.convert;
        Nullable!HitRecord hit;

        immutable float a = invR.dir.x * invR.dir.x + invR.dir.y * invR.dir.y;
        if (areClose(a, 0.0, 1e-10))
        {
            if (originVec.x * originVec.x + originVec.y * originVec.y > 1.0) return hit;
            if ((originVec.z > 1.0 && invR.dir.z > 0.0) || (originVec.z < 0.0 && invR.dir.z < 0.0))
                return hit;

            float firstHit = -originVec.z / invR.dir.z;
            if (invR.dir.z < 0.0) firstHit += 1.0 / invR.dir.z;

            immutable Point hitPoint = invR.at(firstHit);
                hit = HitRecord(transf * hitPoint,
                transf * cylinderNormal(hitPoint, invR.dir),
                cylinderUVPoint(hitPoint),
                firstHit,
                ray,
                this);
            return hit;
        }

        immutable float halfB = originVec.x * invR.dir.x + originVec.y * invR.dir.y;
        immutable float c = originVec.x * originVec.x + originVec.y * originVec.y - 1.0;
        immutable float reducedDelta = halfB * halfB - a * c;

        if (reducedDelta < 0.0) return hit;

        immutable float t1 = (-halfB - sqrt(reducedDelta)) / a;
        immutable float z1Hit = originVec.z + t1 * invR.dir.z;
        immutable float t2 = (-halfB + sqrt(reducedDelta)) / a;
        immutable float z2Hit = originVec.z + t2 * invR.dir.z;

        float firstHit;
        if (t1 > invR.tMin && t1 < invR.tMax && z1Hit >= 0.0 && z1Hit <= 1.0)
            firstHit = t1;
        else if (t2 > invR.tMin && t2 < invR.tMax && z2Hit >= 0.0 && z2Hit <= 1.0)
            firstHit = t2;
        else return hit;

        immutable Point hitPoint = invR.at(firstHit);
        hit = HitRecord(transf * hitPoint,
            transf * cylinderNormal(hitPoint, invR.dir),
            cylinderUVPoint(hitPoint),
            firstHit,
            ray,
            this);
        return hit;
    }

   /// Look up quickly for intersection between a Ray and a Cylinder
    override pure nothrow @nogc @safe bool quickRayIntersection(in Ray ray) const
    {
        immutable Ray invR = transf.inverse * ray;
        immutable Vec originVec = invR.origin.convert;

        immutable float a = invR.dir.x * invR.dir.x + invR.dir.y * invR.dir.y;
        if (areClose(a, 0.0, 1e-10))
        {
            if (originVec.x * originVec.x + originVec.y * originVec.y > 1.0) return false;
            if ((originVec.z > 1.0 && invR.dir.z > 0.0) || (originVec.z < 0.0 && invR.dir.z < 0.0)) return false;
            return true;
        }
        immutable float halfB = originVec.x * invR.dir.x + originVec.y * invR.dir.y;
        immutable float c = originVec.x * originVec.x + originVec.y * originVec.y - 1.0;
        immutable float reducedDelta = halfB * halfB - a * c;

        if (reducedDelta < 0.0) return false;

        immutable float t1 = (-halfB - sqrt(reducedDelta)) / a;
        immutable float z1Hit = originVec.z + t1 * invR.dir.z;
        immutable float t2 = (-halfB + sqrt(reducedDelta)) / a;
        immutable float z2Hit = originVec.z + t2 * invR.dir.z;
        return (t1 > invR.tMin && t1 < invR.tMax && z1Hit >= 0.0 && z1Hit <= 1.0)
            || (t2 > invR.tMin && t2 < invR.tMax && z2Hit >= 0.0 && z2Hit <= 1.0);
    }
}

struct World
{
    Shape[] shapes;

    pure nothrow @safe this(Shape[] s)
    {
        shapes = s;
    }

    pure nothrow @safe void addShape(Shape s)
    {
        shapes ~= s;
    }

    pure nothrow @safe Nullable!HitRecord rayIntersection(in Ray ray)
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

    pure nothrow @nogc @safe bool isPointVisible(in Point point, in Point obsPos)
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