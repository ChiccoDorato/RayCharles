module shapes;

import std.algorithm : max, min;
import geometry : Normal, Point, Vec, Vec2d;
import hdrimage : areClose;
import materials : Material;
import ray;
import std.format : formattedWrite;
import std.math : acos, atan2, floor, PI, sqrt;
import std.typecons : Nullable;
import transformations;

// ******************** HitRecord ********************
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
        return worldPoint.xyzIsClose(hit.worldPoint) &&
            normal.xyzIsClose(hit.normal) &&
            surfacePoint.uvIsClose(hit.surfacePoint) &&
            areClose(t, hit.t) &&
            ray.rayIsClose(hit.ray);
    }

    @safe void toString(
        scope void delegate(scope const(char)[]) @safe sink
        ) const
    {
        sink.formattedWrite!"P) %s\nN) %s\nUV) %s\nt) %s"
            (worldPoint, normal, surfacePoint, t);
    }
}

pure nothrow @nogc @safe float[2] oneDimIntersections(
    in float origin, in float direction
    ) 
{
    if (areClose(direction, 0.0))
        return (origin >= 0.0) && (origin <= 1.0) ?
            [-float.infinity, float.infinity] :
            [float.infinity, -float.infinity];

    float t1, t2;
    if (direction > 0.0)
    {
        t1 = -origin / direction;
        t2 = (1.0 - origin) / direction;
    }
    else
    {
        t1 = (1.0 - origin) / direction;
        t2 = -origin / direction;
    }
    return [t1, t2];
}

pure nothrow @nogc @safe float fixBoundary(
    in float coord, in float min = 0.0, in float max = 1.0, in float var = 1e-4
    )
{
    if (coord < min && coord > min - var) return min;
    if (coord > max && coord < max + var) return max;
    return coord;
}

// ******************** Shape ********************
/// Abstract class for a generic Shape
class Shape
{
    Transformation transf;
    Material material;

    pure nothrow @nogc @safe this(
        in Transformation t = Transformation(), Material m = Material()
        )
    {
        transf = t;
        material = m;
    }

    @safe void toString(
        scope void delegate(scope const(char)[]) @safe sink
        ) const
    {
        sink.formattedWrite!"%s"(transf);
    }

    /// Abstract method - Check and record an intersection between a Ray and a Shape
    abstract pure nothrow @nogc @safe Nullable!HitRecord rayIntersection(
        in Ray r
        );

    /// Abstract method - Look up quickly for intersection between a Ray and a Shape
    abstract pure nothrow @nogc @safe bool quickRayIntersection(in Ray r) const;
}

// ******************** Sphere ********************
/// Class for a 3D Sphere centered in the origin of the axis
class Sphere : Shape
{
    /// Build a sphere - Parameters: Tranformation and Material
    pure nothrow @nogc @safe this(
        in Transformation t = Transformation(), Material m = Material()
        )
    {
        super(t, m);
    }

    /// Convert a 3D point (x, y, z) on the Sphere in a 2D point (u, v) on the screen/Image
    pure nothrow @nogc @safe Vec2d sphereUVPoint(in Point p) const
    {
        immutable float z = fixBoundary(p.z, -1.0, 1.0);
        immutable float u = atan2(p.y, p.x) / (2.0 * PI);
        return Vec2d(u < 0.0 ? u + 1.0 : u, acos(z) / PI);
    }

    /// Create a Normal to a Vector in a Point of the Sphere
    pure nothrow @nogc @safe Normal sphereNormal(in Point p, in Vec v) const
    {
        immutable n = Normal(p.x, p.y, p.z);
        return p.toVec * v < 0.0 ? n : -n;
    }

    /// Check and record an intersection between a Ray and a Sphere
    override pure nothrow @nogc @safe Nullable!HitRecord rayIntersection(
        in Ray r
        )
    {
        immutable Ray invR = transf.inverse * r;
        immutable Vec originVec = invR.origin.toVec;

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
        hit = HitRecord(
            transf * hitPoint,
            transf * sphereNormal(hitPoint, invR.dir),
            sphereUVPoint(hitPoint),
            firstHit,
            r,
            this
            );
        return hit;
    }

    /// Look up quickly for intersection between a Ray and a Shape
    override pure nothrow @nogc @safe bool quickRayIntersection(in Ray r) const
    {
        immutable Ray invR = transf.inverse * r;
        immutable Vec originVec = invR.origin.toVec;

        immutable float halfB = originVec * invR.dir;
        immutable float a = invR.dir.squaredNorm;
        immutable float c = originVec.squaredNorm - 1.0;
        immutable float reducedDelta = halfB * halfB - a * c;

        if (reducedDelta < 0.0) return false;

        immutable float t1 = (-halfB - sqrt(reducedDelta)) / a;
        immutable float t2 = (-halfB + sqrt(reducedDelta)) / a;
        return (t1 > invR.tMin && t1 < invR.tMax) ||
               (t2 > invR.tMin && t2 < invR.tMax);
    }
}

///
unittest
{
    import geometry : vecX, vecZ;

    auto s = new Sphere();

    // rayIntersection with the Sphere
    assert(s.rayIntersection(Ray(Point(0.0, 10.0, 2.0), -vecZ)).isNull);

    auto r1 = Ray(Point(0.0, 0.0, 2.0), -vecZ);
    HitRecord h1 = s.rayIntersection(r1).get(HitRecord());
    // recordIsClose
    assert(HitRecord(
        Point(0.0, 0.0, 1.0),
        Normal(0.0, 0.0, 1.0),
        Vec2d(0.0, 0.0),
        1.0,
        r1
        ).recordIsClose(h1));

    auto r2 = Ray(Point(3.0, 0.0, 0.0), -vecX);
    HitRecord h2 = s.rayIntersection(r2).get(HitRecord());
    assert(HitRecord(
        Point(1.0, 0.0, 0.0),
        Normal(1.0, 0.0, 0.0),
        Vec2d(0.0, 0.5),
        2.0,
        r2
        ).recordIsClose(h2));

    auto r3 = Ray(Point(0.0, 0.0, 0.0), vecX);
    HitRecord h3 = s.rayIntersection(r3).get(HitRecord());
    assert(HitRecord(
        Point(1.0, 0.0, 0.0),
        Normal(-1.0, 0.0, 0.0),
        Vec2d(0.0, 0.5),
        1.0,
        r3
        ).recordIsClose(h3));
}

/// 
unittest
{
    import geometry : vecX, vecZ;

    auto s = new Sphere(translation(Vec(10.0, 0.0, 0.0)));

    // Verify if the Sphere is correctly translated
    assert(s.rayIntersection(Ray(Point(0.0, 0.0, 2.0), -vecZ)).isNull);
    assert(s.rayIntersection(Ray(Point(-10.0, 0.0, 0.0), -vecZ)).isNull);

    auto r1 = Ray(Point(10.0, 0.0, 2.0), -vecZ);
    HitRecord h1 = s.rayIntersection(r1).get(HitRecord());
    assert(HitRecord(
        Point(10.0, 0.0, 1.0),
        Normal(0.0, 0.0, 1.0),
        Vec2d(0.0, 0.0),
        1.0,
        r1
        ).recordIsClose(h1));

    auto r2 = Ray(Point(13.0, 0.0, 0.0), -vecX);
    HitRecord h2 = s.rayIntersection(r2).get(HitRecord());
    assert(HitRecord(
        Point(11.0, 0.0, 0.0),
        Normal(1.0, 0.0, 0.0),
        Vec2d(0.0, 0.5),
        2.0,
        r2
        ).recordIsClose(h2));
}

// ************************* Plane *************************
/// Class for a 3D infinite plane parallel to the x and y axis and passing through the origin
class Plane : Shape
{
    /// Build a plane - Parameters: Tranformation and Material
    pure nothrow @nogc @safe this(
        in Transformation t = Transformation(), Material m = Material()
        )
    {
        super(t, m);
    }

    /// Check and record an intersection between a Ray and a Plane
    override pure nothrow @nogc @safe Nullable!HitRecord rayIntersection(
        in Ray r
        )
    {
        Nullable!HitRecord hit;
        immutable Ray invR = transf.inverse * r;
        if (areClose(invR.dir.z, 0.0)) return hit;

        immutable float t = -invR.origin.z / invR.dir.z;
        if (t <= invR.tMin || t >= invR.tMax) return hit;

        immutable Point hitPoint = invR.at(t);
        hit = HitRecord(
            transf * hitPoint,
            transf * Normal(0.0, 0.0, invR.dir.z < 0.0 ? 1.0 : -1.0),
            Vec2d(hitPoint.x - floor(hitPoint.x), hitPoint.y - floor(hitPoint.y)),
            t,
            r,
            this
            );
        return hit;
    }

    /// Look up quickly for an intersection between a Ray and a Plane
    override pure nothrow @nogc @safe bool quickRayIntersection(in Ray r) const
    {
        immutable Ray invR = transf.inverse * r;
        if (areClose(invR.dir.z, 0.0)) return false;

        float t = -invR.origin.z / invR.dir.z;
        return t > invR.tMin && t < invR.tMax;
    }
}

///
unittest
{
    import geometry : vecX, vecY, vecZ;

    auto p = new Plane();

    auto r1 = Ray(Point(0.0, 0.0, 1.0), -vecZ);
    HitRecord h1 = p.rayIntersection(r1).get(HitRecord());
    assert(HitRecord(
        Point(0.0, 0.0, 0.0),
        Normal(0.0, 0.0, 1.0),
        Vec2d(0.0, 0.0),
        1.0,
        r1
        ).recordIsClose(h1));

    auto r2 = Ray(Point(0.0, 0.0, 1.0), vecZ);
    Nullable!HitRecord h2 = p.rayIntersection(r2);
    // rayIntersection with the Plane
    assert(h2.isNull);

    auto r3 = Ray(Point(0.0, 0.0, 1.0), vecX);
    Nullable!HitRecord h3 = p.rayIntersection(r3);
    assert(h3.isNull);

    auto r4 = Ray(Point(0.0, 0.0, 1.0), vecY);
    Nullable!HitRecord h4 = p.rayIntersection(r4);
    assert(h4.isNull);
}

///
unittest
{
    import geometry : vecX, vecY, vecZ;

    auto p = new Plane(rotationY(90.0));

    auto r1 = Ray(Point(1.0, 0.0, 0.0), -vecX);
    HitRecord h1 = p.rayIntersection(r1).get(HitRecord());
    // Verify if the Plane is correctly rotated
    assert(HitRecord(
        Point(0.0, 0.0, 0.0),
        Normal(1.0, 0.0, 0.0),
        Vec2d(0.0, 0.0),
        1.0,
        r1
        ).recordIsClose(h1));

    auto r2 = Ray(Point(0.0, 0.0, 1.0), vecZ);
    Nullable!HitRecord h2 = p.rayIntersection(r2);
    assert(h2.isNull);

    auto r3 = Ray(Point(0.0, 0.0, 1.0), vecX);
    Nullable!HitRecord h3 = p.rayIntersection(r3);
    assert(h3.isNull);

    auto r4 = Ray(Point(0.0, 0.0, 1.0), vecY);
    Nullable!HitRecord h4 = p.rayIntersection(r4);
    assert(h4.isNull);
}

///
unittest
{
    import geometry : vecZ;

    auto p = new Plane();

    auto r1 = Ray(Point(0.0, 0.0, 1.0), -vecZ);
    HitRecord h1 = p.rayIntersection(r1).get;
    // uvIsClose 
    assert(h1.surfacePoint.uvIsClose(Vec2d(0.0, 0.0)));

    auto r2 = Ray(Point(0.25, 0.75, 1.0), -vecZ);
    HitRecord h2 = p.rayIntersection(r2).get;
    assert(h2.surfacePoint.uvIsClose(Vec2d(0.25, 0.75)));

    auto r3 = Ray(Point(4.25, 7.75, 1.0), -vecZ);
    HitRecord h3 = p.rayIntersection(r3).get;
    assert(h3.surfacePoint.uvIsClose(Vec2d(0.25, 0.75)));
}

// ************************* AABox *************************
/// Class for a 3D Axis Aligned Box
class AABox : Shape
{
    /// Build an AABox - Parameters: transformation, material
    pure nothrow @nogc @safe this(
        in Transformation t = Transformation(), Material m = Material()
        )
    {
        super(t, m);
    }

    /// Build an AABox - Parameters: 
    /// 2 point (max and min of the box), 3 angles (rotation in disrespect to x,y,z axis), material
    pure nothrow @nogc @safe this(
        in Point min,
        in Point max,
        in float xDegreesAngle = 0.0,
        in float yDegreesAngle = 0.0,
        in float zDegreesAngle = 0.0,
        Material m = Material()
        )
    {
        auto scale = scaling(max - min);
        auto transl = translation(min.toVec);

        Transformation rotation;
        if (xDegreesAngle % 360 != 0) rotation *= rotationX(xDegreesAngle);
        if (yDegreesAngle % 360 != 0) rotation *= rotationY(yDegreesAngle);
        if (zDegreesAngle % 360 != 0) rotation *= rotationZ(zDegreesAngle);

        transf = transl * rotation * scale;
        material = m;
    }

    /// Find and record the intersections with the box passing by each dimension x,y,z
    pure nothrow @nogc @safe float[2] boxIntersections(in Ray r) const
    {
        immutable float[2] tX = oneDimIntersections(r.origin.x, r.dir.x);
        immutable float[2] tY = oneDimIntersections(r.origin.y, r.dir.y);
        immutable float[2] tZ = oneDimIntersections(r.origin.z, r.dir.z);
        return [max(tX[0], tY[0], tZ[0]), min(tX[1], tY[1], tZ[1])];
    }

    /// Convert a 3D point (x, y, z) on the AABox in a 2D point (u, v) on the screen/Image
    pure nothrow @nogc @safe Vec2d boxUVPoint(in Point p) const
    {
        float uBox, vBox;
        if (areClose(p.x, 0.0))
            uBox = (1.0 + p.y) / 3.0, vBox = (2.0 + p.z) / 4.0;
        else if (areClose(p.x, 1.0))
            uBox = (1.0 + p.y) / 3.0, vBox = (1.0 - p.z) / 4.0;
        else if (areClose(p.y, 0.0))
            uBox = (1.0 - p.x) / 3.0, vBox = (2.0 + p.z) / 4.0;
        else if (areClose(p.y, 1.0))
            uBox = (2.0 + p.x) / 3.0, vBox = (2.0 + p.z) / 4.0;
        else if (areClose(p.z, 0.0))
            uBox = (1.0 + p.y) / 3.0, vBox = (2.0 - p.x) / 4.0;
        else
        {
            assert(areClose(p.z, 1.0));
            uBox = (1.0 + p.y) / 3.0, vBox = (3.0 + p.x) / 4.0;
        }

        return Vec2d(fixBoundary(uBox), fixBoundary(vBox));
    }

    /// Create a Normal to a Vector in a Point of the AABox
    pure nothrow @nogc @safe Normal boxNormal(in Point p, in Vec v) const
    {
        if (areClose(p.x, 0.0) || areClose(p.x, 1.0))
            return Normal(v.x < 0.0 ? 1.0 : -1.0, 0.0, 0.0);
        else if (areClose(p.y, 0.0) || areClose(p.y, 1.0))
            return Normal(0.0, v.y < 0.0 ? 1.0 : -1.0, 0.0);
        else
        {
            assert(areClose(p.z, 0.0) || areClose(p.z, 1.0));
            return Normal(0.0, 0.0, v.z < 0.0 ? 1.0 : -1.0);
        }
    }

    /// Check and record an intersection between a Ray and an AABOX
    override pure nothrow @nogc @safe Nullable!HitRecord rayIntersection(
        in Ray r
        )
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
        hit = HitRecord(
            transf * hitPoint,
            transf * boxNormal(hitPoint, invR.dir),
            boxUVPoint(hitPoint),
            firstHit,
            r,
            this
            );
        return hit;
    }

    /// Look up quickly for an intersection between a Ray and a Plane
    override pure nothrow @nogc @safe bool quickRayIntersection(in Ray r) const
    {
        immutable Ray invR = transf.inverse * r;
        immutable float[2] t = boxIntersections(invR);
        if (t[0] > t[1] || t[0] >= invR.tMax || t[1] <= invR.tMin) return false;
        return t[0] > invR.tMin || t[1] < invR.tMax;
    }
}

///
unittest
{
    auto p1 = Point(1.0, 2.0, 4.0), p2 = Point(-1.0, 5.0, 5.0);
    auto pointsConstructorBox = new AABox(p1, p2, 0.0, 330.0, 0.0);

    // checking the constructor
    auto scale = scaling(Vec(-2.0, 3.0, 1.0));
    auto rotY = rotationY(-30.0);
    auto transl = translation(Vec(1.0, 2.0, 4.0));
    assert(pointsConstructorBox.transf.transfIsClose(transl * rotY * scale));
}

///
unittest
{
    import geometry : vecX, vecY;

    // Default constructor
    auto box = new AABox();

    // rayIntersection
    auto r1 = Ray(Point(-2.0, 0.5, 0.0), -vecX);
    assert(!box.quickRayIntersection(r1));
    Nullable!HitRecord h1 = box.rayIntersection(r1);
    assert(h1.isNull);

    // recordIsClose
    auto r2 = Ray(Point(0.0, 0.3, 0.7), vecY);
    assert(box.quickRayIntersection(r2));
    HitRecord h2 = box.rayIntersection(r2).get(HitRecord());
    assert(HitRecord(
        Point(0.0, 1.0, 0.7),
        Normal(-1.0, 0.0, 0.0),
        Vec2d(2.0 / 3.0, 0.675),
        0.7,
        r2,
        box
        ).recordIsClose(h2));

    auto r3 = Ray(Point(-4.0, -1.0, -2.0), Vec(8.0, 3.0, 6.0));
    assert(box.quickRayIntersection(r3));
    HitRecord h3 = box.rayIntersection(r3).get(HitRecord());
    assert(HitRecord(
        Point(0.0, 0.5, 1.0),
        Normal(-1.0, 0.0, 0.0),
        Vec2d(0.5, 0.75),
        0.5,
        r3,
        box
        ).recordIsClose(h3));
}

///
unittest
{
    import geometry : vecY, vecZ;

    auto scale = scaling(Vec(2.0, 3.0, -0.8));
    auto rotY = rotationY(-30.0);
    auto transl = translation(Vec(-1.0, 2.0, 4.0));
    // AABox with tranformation
    AABox box = new AABox(transl * rotY * scale);
    float z = 4.0 - sqrt(3.0) / 3.0;

    auto p1 = Point(-1.0, 2.0, 4.0), p2 = Point(1.0, 5.0, 3.2);
    auto pointsConstructorBox = new AABox(p1, p2, 0.0, -30.0, 0.0);
    // tranfIsClose
    assert(pointsConstructorBox.transf.transfIsClose(box.transf));

    auto r1 = Ray(Point(-1.0, 8.0, z), -vecY);
    // quickRayIntersection
    assert(!box.quickRayIntersection(r1));
    Nullable!HitRecord h1 = box.rayIntersection(r1);
    assert(h1.isNull);

    auto r2 = Ray(Point(-0.66667, 8.0, z), -vecY);
    assert(!box.quickRayIntersection(r2));
    Nullable!HitRecord h2 = box.rayIntersection(r2);
    assert(h2.isNull);

    auto r3 = Ray(Point(-2.0 / 3.0, 8.0, z), -vecY);
    assert(box.quickRayIntersection(r3));
    HitRecord h3 = box.rayIntersection(r3).get(HitRecord());
    assert(HitRecord(
        Point(-2.0 / 3.0, 5.0, z),
        0.5 * Normal(-sqrt(3.0) / 2.0, 0.0, -0.5),
        Vec2d(2.0 / 3.0, 17.0 / 24.0),
        3.0,
        r3,
        box
        ).recordIsClose(h3));

    auto r4 = Ray(Point(-0.5, 8.0, z), -vecY);
    assert(box.quickRayIntersection(r4));
    HitRecord h4 = box.rayIntersection(r4).get(HitRecord());
    assert(HitRecord(
        Point(-0.5, 5.0, z),
        (1.0 / 3.0) * Normal(0.0, 1.0, 0.0),
        Vec2d((48.0 + sqrt(3.0)) / 72.0, 47.0 / 64.0),
        3.0,
        r4,
        box
        ).recordIsClose(h4));

    auto r5 = Ray(Point(-2.0 / 5.0, 0.0, z), vecY);
    assert(box.quickRayIntersection(r5));
    HitRecord h5 = box.rayIntersection(r5).get(HitRecord());
    assert(HitRecord(
        Point(-0.4, 2.0, z),
        (1.0 / 3.0) * Normal(0.0, -1.0, 0.0),
        Vec2d((15.0 - sqrt(3.0)) / 45.0, 0.75),
        2.0,
        r5,
        box
        ).recordIsClose(h5));

    auto r6 = Ray(Point(0.40001, 8.0, z), -vecY);
    assert(!box.quickRayIntersection(r6));
    Nullable!HitRecord h6 = box.rayIntersection(r6);
    assert(h6.isNull);

    auto r7 = Ray(Point(1.0, 8.0, z), -vecY);
    assert(!box.quickRayIntersection(r7));
    Nullable!HitRecord h7 = box.rayIntersection(r7);
    assert(h7.isNull);

    auto vertical1 = Ray(Point(sqrt(3.0) / 4.0 - 1.0, 3.8, 4.5), -vecZ);
    assert(box.quickRayIntersection(vertical1));
    HitRecord hVert1 = box.rayIntersection(vertical1).get(HitRecord());
    assert(HitRecord(
        Point(sqrt(3.0) / 4.0 - 1.0, 3.8, 4.25),
        1.25 * Normal(-0.5, 0.0, sqrt(3.0) / 2.0),
        Vec2d(8.0 / 15.0, 0.4375),
        0.25,
        vertical1,
        box
        ).recordIsClose(hVert1));

    auto vertical2 = Ray(
        Point(sqrt(3.0) - 0.9, 3.0, 5.0 + 0.9 * sqrt(3.0)),
        -vecZ
        );
    assert(box.quickRayIntersection(vertical2));
    HitRecord hVert2 = box.rayIntersection(vertical2).get(HitRecord());
    assert(HitRecord(
        Point(sqrt(3.0) - 0.9, 3.0, 5.0 - 0.1 * sqrt(3.0)),
        0.5 * Normal(sqrt(3.0) / 2.0, 0.0, 0.5),
        Vec2d(4.0 / 9.0, 0.1875),
        sqrt(3.0),
        vertical2,
        box
        ).recordIsClose(hVert2));
}

// ************************* CylinderShell *************************
/// Class for a 3D Cylinder shell (lateral suface) aligned with the z axis
class CylinderShell : Shape
{
    /// Build a CylinderShell - Parameters: tranformation and material
    pure nothrow @nogc @safe this(
        in Transformation t = Transformation(), Material m = Material()
        )
    {
        super(t, m);
    }
    /// Build a CylinderShell - Parameters: the radius, the center point of the upper face and lower face and the material
    pure nothrow @nogc @safe this(
        in float r, in Point min, in Point max, Material m = Material()
        )
    in (!areClose(r, 0.0))
    in (!min.xyzIsClose(max))
    {
        immutable float h = (max - min).norm;
        auto scale = scaling(Vec(r, r, h));
        auto transl = translation(min.toVec);

        Transformation rotation;
        immutable float colatCosine = (max.z - min.z) / h;
        if (!areClose(colatCosine, 1.0))
        {
            immutable float colatSine = sqrt(1.0 - colatCosine * colatCosine);
            rotation *= rotationY(colatCosine, colatSine);

            immutable float longCosine = (max.x - min.x) / (h * colatSine);
            if (!areClose(longCosine, 1.0))
            {
                immutable float longSine = (max.y - min.y) / (h * colatSine);
                rotation *= rotationZ(longCosine, longSine);
            }
        }

        transf = transl * rotation * scale;
        material = m;
    }

    /// Build a CylinderShell - Parameters: the radius, the lenght, the translation Vector and the material
    pure nothrow @nogc @safe this(
        in float r, in float h, in Vec transl = Vec(), Material m = Material()
        )
    in (!areClose(r, 0.0))
    in (!areClose(h, 0.0))
    {
        transf = translation(transl) * scaling(Vec(r, r, h));
        material = m;
    }

    /// Build a CylinderShell - Parameters: the radius, the lenght, the translation Vector,
    /// 3 angles for a rotation (in disrespect to x,y and z axis) and the material
    pure nothrow @nogc @safe this(
        in float r,
        in float h,
        in Vec translVec = Vec(),
        in float xDegreesAngle = 0.0,
        in float yDegreesAngle = 0.0,
        in float zDegreesAngle = 0.0,
        Material m = Material()
        )
    in (!areClose(r, 0.0))
    in (!areClose(h, 0.0))
    {
        auto scale = scaling(Vec(r, r, h));
        auto transl = translation(translVec);

        Transformation rotation;
        if (xDegreesAngle % 360 != 0) rotation *= rotationX(xDegreesAngle);
        if (yDegreesAngle % 360 != 0) rotation *= rotationY(yDegreesAngle);
        if (zDegreesAngle % 360 != 0) rotation *= rotationZ(zDegreesAngle);

        transf = transl * rotation * scale;
        material = m;
    }

    /// Find and record the intersections with the CylinderShell passing by each dimension x,y,z
    pure nothrow @nogc @safe float[2] cylShellIntersections(in Ray r) const
    {
        immutable float c = r.origin.x * r.origin.x +
                            r.origin.y * r.origin.y -
                            1.0;
        if (areClose(r.dir.x, 0.0) && areClose(r.dir.y, 0.0))
            return (c <= 0.0) ?
                [-float.infinity, float.infinity] :
                [float.infinity, -float.infinity];

        immutable float halfB = r.origin.x * r.dir.x + r.origin.y * r.dir.y;
        immutable float a = r.dir.x * r.dir.x + r.dir.y * r.dir.y;
        immutable float reducedDelta = halfB * halfB - a * c;
        if (reducedDelta < 0.0) return [float.infinity, -float.infinity];

        immutable float t1 = (-halfB - sqrt(reducedDelta)) / a;
        immutable float t2 = (-halfB + sqrt(reducedDelta)) / a;
        return [t1, t2];
    }

    /// Convert a 3D point (x, y, z) on the CylinderShell in a 2D point (u, v) on the screen/Image
    pure nothrow @nogc @safe Vec2d cylShellUVPoint(in Point p) const
    {
        immutable float z = fixBoundary(p.z);
        immutable float u = atan2(p.y, p.x) / (2.0 * PI);
        return Vec2d(u < 0.0 ? u + 1.0 : u, z);
    }

    /// Create a Normal to a Vector in a Point of the CylinderShell surface
    pure nothrow @nogc @safe Normal cylShellNormal(in Point p, in Vec v) const
    {
        immutable Normal n = Normal(p.x, p.y, 0.0);
        return p.x * v.x + p.y * v.y < 0.0 ? n : -n;
    }

    /// Check and record an intersection between a Ray and a CylinderShell
    override pure nothrow @nogc @safe Nullable!HitRecord rayIntersection(
        in Ray r
        )
    {
        Nullable!HitRecord hit;
        immutable Ray invR = transf.inverse * r;

        immutable float[2] tShell = cylShellIntersections(invR);
        if(tShell[0] >= invR.tMax || tShell[1] <= invR.tMin) return hit;

        immutable float[2] tZ = oneDimIntersections(invR.origin.z, invR.dir.z);
        if (tShell[0] > tZ[1] || tShell[1] < tZ[0]) return hit;

        float firstHit;
        if (tShell[0] >= tZ[0] && tShell[0] > invR.tMin) firstHit = tShell[0];
        else if (tShell[1] <= tZ[1] && tShell[1] < invR.tMax)
            firstHit = tShell[1];
        else return hit;

        immutable Point hitPoint = invR.at(firstHit);
        hit = HitRecord(
            transf * hitPoint,
            transf * cylShellNormal(hitPoint, invR.dir),
            cylShellUVPoint(hitPoint),
            firstHit,
            r,
            this
            );
        return hit;
    }

   /// Look up quickly for intersection between a Ray and a CylinderShell
    override pure nothrow @nogc @safe bool quickRayIntersection(in Ray r) const
    {
        immutable Ray invR = transf.inverse * r;

        immutable float[2] tShell = cylShellIntersections(invR);
        if(tShell[0] >= invR.tMax || tShell[1] <= invR.tMin) return false;
        immutable float[2] tZ = oneDimIntersections(invR.origin.z, invR.dir.z);
        if (tShell[0] > tZ[1] || tShell[1] < tZ[0]) return false;

        return (tShell[0] >= tZ[0] && tShell[0] > invR.tMin)
            || (tShell[1] <= tZ[1] && tShell[1] < invR.tMax);
    }
}

///
unittest
{
    import geometry : vecX, vecZ;
    import hdrimage : Color;
    import materials : DiffuseBRDF, Material, UniformPigment;

    auto pMin = Point(1.0, 1.0, 0.0), pMax = pMin + 2.0 * vecZ;
    auto cylShellPig = new UniformPigment(Color(1.0, 0.0, 0.0));
    auto cylShellMaterial = Material(new DiffuseBRDF(cylShellPig));
    // Same behaviour for the three different CylinderShells
    auto c1 = new CylinderShell(
        translation(pMin.toVec) * scaling(pMax.toVec),
        cylShellMaterial
        );
    auto c2 = new CylinderShell(1.0, pMin, pMax, cylShellMaterial);
    auto c3 = new CylinderShell(1.0, 2.0, pMin.toVec, cylShellMaterial);

    Vec2d uv1 = c1.cylShellUVPoint(Point(0.0, 1.0, 0.0));
    Vec2d uv2 = c2.cylShellUVPoint(Point(0.0, 1.0, 0.0));
    Vec2d uv3 = c3.cylShellUVPoint(Point(0.0, 1.0, 0.0));

    assert(uv1.uvIsClose(uv2));
    assert(uv1.uvIsClose(uv3));
    assert(uv2.uvIsClose(uv3));

    auto r1 = Ray(Point(-1.0, 1.0, 1.0), vecX);
    assert(c1.quickRayIntersection(r1));
    HitRecord h1 = c1.rayIntersection(r1).get;
    assert(h1.worldPoint.xyzIsClose(Point(0.0, 1.0, 1.0)));

    auto r2 = Ray(Point(-1.0, 1.0, 0.0), Vec(1.0, 0.5, 0.0));
    assert(c1.quickRayIntersection(r2));

    auto r3 = Ray(Point(-1.0, 1.0, -1e-10), vecX);
    assert(!c1.quickRayIntersection(r3));

    auto r4 = Ray(Point(1.0, 1.0, 3.0), -vecZ);
    assert(!c1.quickRayIntersection(r4));
}

///
unittest
{
    import geometry : vecY;
    import hdrimage : Color;
    import materials : DiffuseBRDF, Material, UniformPigment;

    auto cylShellTransf = translation(vecY) *
                          rotationX(45.0) *
                          scaling(Vec(1.0, 1.0, sqrt(2.0)));
    auto cylShellPig = new UniformPigment(Color(1.0, 0.0, 0.0));
    auto cylShellMaterial = Material(new DiffuseBRDF(cylShellPig));
    // Rotation of a CylinderShell
    auto csRot1 = new CylinderShell(cylShellTransf, cylShellMaterial);
    // Constructor 2
    auto csRot2 = new CylinderShell(
        1.0,
        Point(0.0, 1.0, 0.0),
        Point(0.0, 0.0, 1.0),
        cylShellMaterial
        );

    auto ray1 = Ray(Point(0.0, 3.0, 0.0), -vecY);

    assert(csRot1.quickRayIntersection(ray1));
    HitRecord h1 = csRot1.rayIntersection(ray1).get(HitRecord());
    assert(HitRecord(
        Point(0.0, 1.0 - sqrt(2.0), 0.0),
        Normal(0.0, sqrt(2.0) / 2.0, sqrt(2.0) / 2.0),
        Vec2d(0.75, sqrt(2.0) / 2.0), // (0.75, 0.0) bad
        2.0 + sqrt(2.0),
        ray1,
        csRot1
        ).recordIsClose(h1));

    assert(csRot2.quickRayIntersection(ray1));
    HitRecord h2 = csRot2.rayIntersection(ray1).get(HitRecord());
    assert(HitRecord(
        Point(0.0, 1.0 - sqrt(2.0), 0.0),
        Normal(0.0, sqrt(2.0) / 2.0, sqrt(2.0) / 2.0),
        Vec2d(0.0, sqrt(2.0) / 2.0), // (0.75, 0.0) bad
        2.0 + sqrt(2.0),
        ray1,
        csRot2
        ).recordIsClose(h2));

    auto ray2 = Ray(Point(0.0, -1.0, 2.0), Vec(0.0, 1.0, -1.0));

    assert(!csRot1.quickRayIntersection(ray2));
    Nullable!HitRecord hit1 = csRot1.rayIntersection(ray2);
    assert(hit1.isNull);

    assert(!csRot2.quickRayIntersection(ray2));
    Nullable!HitRecord hit2 = csRot2.rayIntersection(ray2);
    assert(hit2.isNull);
}

// ************************* Cylinder *************************
/// Class for a 3D Cylinder aligned with the z axis
class Cylinder : CylinderShell
{
    /// Build a Cylinder - Parameters: tranformation and material
    pure nothrow @nogc @safe this(
        in Transformation t = Transformation(), Material m = Material()
        )
    {
        super(t, m);
    }

    /// Build a Cylinder - Parameters: the radius, the center point of the upper face and lower face and the material
    pure nothrow @nogc @safe this(
        in float r, in Point min, in Point max, Material m = Material()
        )
    {
        super(r, min, max, m);
    }
    /// Build a Cylinder - Parameters: the radius, the lenght, the transformation and the material
    pure nothrow @nogc @safe this(
        in float r, in float h, in Vec transl = Vec(), Material m = Material()
        )
    {
        super(r, h, transl, m);
    }

    /// Build a Cylinder - Parameters: the radius, the lenght, the translation Vector,
    /// 3 angles for a rotation (in disrespect to x,y and z axis) and the material
    pure nothrow @nogc @safe this(
        in float r,
        in float h,
        in Vec transl = Vec(),
        in float xDegreesAngle = 0.0,
        in float yDegreesAngle = 0.0,
        in float zDegreesAngle = 0.0,
        Material m = Material())
    {
        super(r, h, transl, xDegreesAngle, yDegreesAngle, zDegreesAngle, m);
    }

    pure nothrow @nogc @safe float[2] cylinderIntersections(in Ray r) const
    {
        immutable float[2] tShell = cylShellIntersections(r);
        immutable float[2] tZ = oneDimIntersections(r.origin.z, r.dir.z);
        return [max(tShell[0], tZ[0]), min(tShell[1], tZ[1])];
    }

    /// Convert a 3D point (x, y, z) on the Cylinder in a 2D point (u, v) on the screen/Image
    pure nothrow @nogc @safe Vec2d cylinderUVPoint(in Point p) const
    {
        float u = atan2(p.y, p.x) / (2.0 * PI);
        if (u < 0.0) ++u;
        immutable float quarterRho = 0.25 * (p.x * p.x + p.y * p.y);

        if (areClose(p.z, 0.0)) return Vec2d(u, quarterRho);
        if (areClose(p.z, 1.0)) return Vec2d(u, 1.0 - quarterRho);
        return Vec2d(u, 0.25 + 0.5 * p.z);
    }

    /// Create a Normal to a Vector in a Point of the Cylinder surface
    pure nothrow @nogc @safe Normal cylinderNormal(in Point p, in Vec v) const
    {
        if (!areClose(p.z, 0.0) && !areClose(p.z, 1.0))
            return cylShellNormal(p, v);
        immutable n = Normal(0.0, 0.0, 1.0);
        return v.z < 0.0 ? n : -n;
    }

    /// Check and record an intersection between a Ray and a Cylinder
    override pure nothrow @nogc @safe Nullable!HitRecord rayIntersection(
        in Ray r
        )
    {
        Nullable!HitRecord hit;
        immutable Ray invR = transf.inverse * r;
        immutable float[2] t = cylinderIntersections(invR);

        float firstHit;
        if (t[0] > t[1]) return hit;
        if (t[0] > invR.tMin && t[0] < invR.tMax) firstHit = t[0];
        else if (t[1] > invR.tMin && t[1] < invR.tMax) firstHit = t[1];
        else return hit;

        immutable Point hitPoint = invR.at(firstHit);
        hit = HitRecord(
            transf * hitPoint,
            transf * cylinderNormal(hitPoint, invR.dir),
            cylinderUVPoint(hitPoint),
            firstHit,
            r,
            this
            );
        return hit;
    }

   /// Look up quickly for intersection between a Ray and a Cylinder
    override pure nothrow @nogc @safe bool quickRayIntersection(in Ray r) const
    {
        immutable Ray invR = transf.inverse * r;
        immutable float[2] t = cylinderIntersections(invR);
        if (t[0] > t[1] || t[0] >= invR.tMax || t[1] <= invR.tMin) return false;
        return (t[0] > invR.tMin) || (t[1] < invR.tMax);
    }
}

///
unittest
{
    import geometry : vecX, vecZ;
    import hdrimage : Color;
    import materials : DiffuseBRDF, Material, UniformPigment;

    auto pMin = Point(1.0, 1.0, 0.0), pMax = pMin + 2.0 * vecZ;
    auto cylPigment = new UniformPigment(Color(1.0, 0.0, 0.0));
    auto cylMaterial = Material(new DiffuseBRDF(cylPigment));
    // Same behaviour for the three different Cylinders
    auto c1 = new Cylinder(
        translation(pMin.toVec) * scaling(pMax.toVec),
        cylMaterial
        );
    auto c2 = new Cylinder(1.0, pMin, pMax, cylMaterial);
    auto c3 = new Cylinder(1.0, 2.0, pMin.toVec, cylMaterial);

    Vec2d uv1 = c1.cylinderUVPoint(Point(0.0, 1.0, 0.0));
    Vec2d uv2 = c2.cylinderUVPoint(Point(0.0, 1.0, 0.0));
    Vec2d uv3 = c3.cylinderUVPoint(Point(0.0, 1.0, 0.0));

    assert(uv1.uvIsClose(uv2));
    assert(uv1.uvIsClose(uv3));
    assert(uv2.uvIsClose(uv3));

    auto r1 = Ray(Point(-1.0, 1.0, 1.0), vecX);
    assert(c1.quickRayIntersection(r1));
    HitRecord hit1 = c1.rayIntersection(r1).get(HitRecord());
    assert(HitRecord(
        Point(0.0, 1.0, 1.0),
        Normal(-1.0, 0.0, 0.0),
        Vec2d(0.5, 0.5),
        1.0,
        r1,
        c1
        ).recordIsClose(hit1));

    auto r2 = Ray(Point(-1.0, 1.0, 0.0), Vec(1.0, 0.5, 0.0));
    assert(c1.quickRayIntersection(r2));
    HitRecord hit2 = c1.rayIntersection(r2).get(HitRecord());
    assert(HitRecord(
        Point(0.2, 1.6, 0.0),
        Normal(0.0, 0.0, -0.5),
        Vec2d((PI - acos(0.8)) / (2.0 * PI), 0.25),
        1.2,
        r2,
        c1
        ).recordIsClose(hit2));

    auto r3 = Ray(Point(-1.0, 1.0, -1e-10), vecX);
    assert(!c1.quickRayIntersection(r3));
    Nullable!HitRecord hit3 = c1.rayIntersection(r3);
    assert(hit3.isNull);
    
    auto r4 = Ray(Point(1.0, 1.0, 3.0), -vecZ);
    assert(c1.quickRayIntersection(r4));
    HitRecord vertical = c1.rayIntersection(r4).get(HitRecord());
    assert(HitRecord(
        Point(1.0, 1.0, 2.0),
        Normal(0.0, 0.0, 0.5),
        Vec2d(0.0 , 1.0),
        1.0,
        r4,
        c1
        ).recordIsClose(vertical));
}

///
unittest
{
    import geometry : vecY, vecZ;
    import hdrimage : Color;
    import materials : DiffuseBRDF, Material, UniformPigment;

    auto cylPigment = new UniformPigment(Color(1.0, 0.0, 0.0));
    auto cylMaterial = Material(new DiffuseBRDF(cylPigment));
    // Rotation of a Cylinder
    // Constructor 1
    auto cRot1 = new Cylinder(
        translation(Vec(0.0, 1.0, 0.0)) * rotationX(45.0),
        cylMaterial
        );

    auto ray1 = Ray(Point(0.0, 3.0, 0.0), -vecY);
    assert(cRot1.quickRayIntersection(ray1));
    HitRecord hit1 = cRot1.rayIntersection(ray1).get(HitRecord());
    assert(HitRecord(
        Point(0.0, 1.0, 0.0),
        Normal(0.0, sqrt(2.0) / 2.0, -sqrt(2.0) / 2.0),
        Vec2d(0.0, 0.0),
        2.0,
        ray1,
        cRot1
        ).recordIsClose(hit1));

    auto ray2 = Ray(Point(0.0, 0.0, 1.0), -vecZ);
    assert(cRot1.quickRayIntersection(ray2));
    HitRecord hit2 = cRot1.rayIntersection(ray2).get(HitRecord());
    // import std.stdio;
    // writeln(hit2);
    assert(HitRecord(
        Point(0.0, 0.0, sqrt(2.0) - 1.0),
        Normal(0.0, -sqrt(2.0) / 2.0, sqrt(2.0) / 2.0),
        Vec2d(0.75, 0.957107), // (0.0, 0.25 + 0.5 * (sqrt(2.0) - 1.0))
        2.0 - sqrt(2.0),
        ray2,
        cRot1
        ).recordIsClose(hit2));

    auto ray3 = Ray(Point(0.0, -1.0, 2.0), Vec(0.0, 1.0, 1.0));
    assert(!cRot1.quickRayIntersection(ray3));
    Nullable!HitRecord hit3 = cRot1.rayIntersection(ray3);
    assert(hit3.isNull);

    // Constructor 2
    auto cRot2 = new CylinderShell(
        1.0,
        Point(0.0, 1.0, 0.0),
        Point(0.0, 0.0, 1.0),
        cylMaterial
        );

    assert(cRot2.quickRayIntersection(ray1));
    HitRecord h1 = cRot2.rayIntersection(ray1).get(HitRecord());
    assert(HitRecord(
        Point(0.0, 1 - sqrt(2.0), -1.78814e-07),
        Normal(-0.0, sqrt(2.0) / 2.0, sqrt(2.0) / 2.0),
        Vec2d(0.0, sqrt(2.0) / 2.0), // (1.0 - (PI / 2.0), (3.0 - 2 * sqrt(2.0)) / 4.0)
        2.0 + sqrt(2.0),
        ray1,
        cRot2
        ).recordIsClose(h1));

    assert(!cRot2.quickRayIntersection(ray3));
    Nullable!HitRecord h2 = cRot2.rayIntersection(ray3);
    assert(h2.isNull);
}

// ************************* World *************************
/// Struct for a 3D World where to put all the shapes of the image
struct World
{
    Shape[] shapes;
    
    /// Build a World from an array of Shapes
    pure nothrow @nogc @safe this(Shape[] s)
    {
        shapes = s;
    }

    /// Add a Shape to the list of the World
    pure nothrow @safe void addShape(Shape s)
    {
        shapes ~= s;
    }

    /// Check and record an intersection between a Ray and each Shape of the World by calling their specific rayIntersection
    pure nothrow @nogc @safe Nullable!HitRecord rayIntersection(in Ray ray)
    {
        Nullable!HitRecord closest;
        Nullable!HitRecord intersection;

        foreach (Shape s; shapes)
        {
            intersection = s.rayIntersection(ray);
            if (intersection.isNull) continue;
            if (closest.isNull || intersection.get.t < closest.get.t)
                closest = intersection;
        }
        return closest;
    }

    /// Return if a Point of the World is visible or not from the observer put in obsPos
    pure nothrow @nogc @safe bool isPointVisible(
        in Point point,
        in Point obsPos
        ) const
    {
        immutable Vec direction = point - obsPos;
        immutable ray = Ray(obsPos, direction, 1e-2 / direction.norm, 1.0);

        for (uint i = 0; i < shapes.length; ++i)
            if (shapes[i].quickRayIntersection(ray)) return false;
        return true;
    }
}

///
unittest
{
    import geometry : vecX;

    World world;
    auto s1 = new Sphere(translation(vecX * 2.0));
    auto s2 = new Sphere(translation(vecX * 8.0));
    world.addShape(s1);
    world.addShape(s2);
    
    // rayIntersection
    auto ray1 = Ray(Point(0.0, 0.0, 0.0), vecX);
    Nullable!HitRecord intersection1 = world.rayIntersection(ray1);
    assert(!intersection1.isNull);
    assert(intersection1.get.worldPoint.xyzIsClose(Point(1.0, 0.0, 0.0)));

    auto ray2 = Ray(Point(10.0, 0.0, 0.0), -vecX);
    Nullable!HitRecord intersection2 = world.rayIntersection(ray2);
    assert(!intersection2.isNull);
    assert(intersection2.get.worldPoint.xyzIsClose(Point(9.0, 0.0, 0.0)));
}

///
unittest
{
    import geometry : vecX;

    World world;
    auto s1 = new Sphere(translation(vecX * 2.0));
    auto s2 = new Sphere(translation(vecX * 8.0));
    world.addShape(s1);
    world.addShape(s2);

    // isPointVisible
    assert(!world.isPointVisible(Point(10.0, 0.0, 0.0), Point(0.0, 0.0, 0.0)));
    assert(!world.isPointVisible(Point(5.0, 0.0, 0.0), Point(0.0, 0.0, 0.0)));
    assert(world.isPointVisible(Point(5.0, 0.0, 0.0), Point(4.0, 0.0, 0.0)));
    assert(world.isPointVisible(Point(0.5, 0.0, 0.0), Point(0.0, 0.0, 0.0)));
    assert(world.isPointVisible(Point(0.0, 10.0, 0.0), Point(0.0, 0.0, 0.0)));
    assert(world.isPointVisible(Point(0.0, 0.0, 10.0), Point(0.0, 0.0, 0.0)));
}