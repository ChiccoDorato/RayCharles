module shapes;

import std.algorithm : max, maxIndex, min, minIndex;
import geometry : Normal, Point, Vec, Vec2d;
import hdrimage : areClose;
import materials : Material;
import ray;
import std.format : formattedWrite;
import std.math : acos, atan2, floor, isNaN, PI, sqrt;
import std.typecons : Nullable;
import transformations;

// ******************** HitRecord ********************
/**
* Struct HitRecord to keep in memory infos about 
* intersection of a Ray with an object 
* Params: 
*   worldPoint = (Point)
*   normal = (Normal)
*   surfacePoint = (Vec2d),
*   t = (float)
*   ray = (Ray)
*   shape = (Shape)
*/
struct HitRecord
{
    Point worldPoint;
    Normal normal;
    Vec2d surfacePoint;
    float t;
    Ray ray;
    Shape shape;

    /**
    * Check if two HitRecord are close by calling 
    * the fuction areClose for every member
    * Params: 
    *    hit = (HitRecord)
    * Return: true or false (bool)
    */
    pure nothrow @nogc @safe bool recordIsClose(in HitRecord hit) const
    {
        return worldPoint.xyzIsClose(hit.worldPoint) &&
            normal.xyzIsClose(hit.normal) &&
            surfacePoint.uvIsClose(hit.surfacePoint) &&
            areClose(t, hit.t) &&
            ray.rayIsClose(hit.ray);
    }

    /**
    * Print an HitRecord as a string
    */
    @safe void toString(
        scope void delegate(scope const(char)[]) @safe sink
        ) const
    {
        sink.formattedWrite!"P) %s\nN) %s\nUV) %s\nt) %s"(
            worldPoint, normal, surfacePoint, t
            );
    }
}

/**
* Find monodimentional intersection
* Return: an array [t1, t2] with the "time" of intersection
*/
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

/**
* Correct the boundary coordinates: 
* useful in order not to have defects on the borders of the shapes
* Params: 
*   coord = (float)
*   min = (float) = 0.0
*   max = (float) = 1.0
*   var = (float) = 1e-4 
*/
pure nothrow @nogc @safe float fixBoundary(
    in float coord, in float min = 0.0, in float max = 1.0, in float var = 1e-4
    )
{
    if (coord < min && coord > min - var) return min;
    if (coord > max && coord < max + var) return max;
    return coord;
}

struct AABB
{
    Point min, max;

    pure nothrow @nogc @safe bool isClose(in AABB aabb) const
    {
        return min.xyzIsClose(aabb.min) && max.xyzIsClose(aabb.max);
    }
}

// ******************** Shape ********************
/**
* Abstract class for a generic Shape
*/
class Shape
{
    Transformation transf;
    Material material;
    AABB aabb;

    /** 
     * Build a Shape
     * Params:
     *  t = (Transformation)
     *  m = (Material)
     */
    pure nothrow @nogc @safe this(
        in Transformation t = Transformation(), Material m = Material()
        )
    {
        transf = t;
        material = m;
    }

    /** 
     * Convert a Shape into a string
     */
    @safe void toString(
        scope void delegate(scope const(char)[]) @safe sink
        ) const
    {
        sink.formattedWrite!"%s"(transf);
    }

    /**
    * Abstract method - Convert a 3D point (x, y, z) on the Sphere
    * in a 2D point (u, v) on the screen/Image
    * Params: 
    *   p = Point
    * Return: Vec2d
    */
    abstract pure nothrow @nogc @safe Vec2d uv(in Point p) const;

    /**
    * Create a Normal to a Vector in a Point of the Sphere
    * Params: 
    *   p = (Point)
    *   v = (Vec)
    * Return: Normal
    */
    abstract pure nothrow @nogc @safe Normal normal(in Point p, in Vec v) const;

    /**
    * Check and record all the intersections between a Ray and a Shape
    * Params: 
    *   r = (Ray)
    * Return: Nullable!HitRecord
    */
    abstract pure nothrow @safe float[] allIntersections(in Ray r) const;

    /**
    * Check and record an intersection between a Ray and a Shape
    * Params: 
    *   r = (Ray)
    * Return: Nullable!HitRecord
    */
    abstract pure nothrow @safe Nullable!HitRecord rayIntersection(in Ray r);

    /**
    * Look up quickly for intersection between a Ray and a Shape
    * Params:
    *   r = (Ray)
    * Return: true or false (bool)
    */
    abstract pure nothrow @safe bool quickRayIntersection(in Ray r) const;

    final pure nothrow @nogc @safe AABB transformAABB() const
    {
        Point[8] vertices = [
            transf * aabb.min,
            transf * Point(aabb.max.x, aabb.min.y, aabb.min.z),
            transf * Point(aabb.max.x, aabb.max.y, aabb.min.z),
            transf * Point(aabb.min.x, aabb.max.y, aabb.min.z),
            transf * Point(aabb.min.x, aabb.min.y, aabb.max.z),
            transf * Point(aabb.max.x, aabb.min.y, aabb.max.z),
            transf * aabb.max,
            transf * Point(aabb.min.x, aabb.max.y, aabb.max.z)
            ];

        float xMin = vertices[0].x, xMax = xMin;
        float yMin = vertices[0].y, yMax = yMin;
        float zMin = vertices[0].z, zMax = zMin;
        foreach (Point p; vertices)
        {
            if (p.x < xMin) xMin = p.x;
            if (p.x > xMax) xMax = p.x;

            if (p.y < yMin) yMin = p.y;
            if (p.y > yMax) yMax = p.y;

            if (p.z < zMin) zMin = p.z;
            if (p.z > zMax) zMax = p.z;
        }

        return AABB(Point(xMin, yMin, zMin), Point(xMax, yMax, zMax));
    }

    abstract pure nothrow @nogc @safe bool isInside(in Point p) const;
}

// ******************** Sphere ********************
/**
* Class for a 3D Sphere centered in the origin of the axis (0, 0, 0)
*/
class Sphere : Shape
{
    /**
    * Build a sphere 
    * Params: 
    *   t = (Tranformation)
    *   m = (Material)
    */
    pure nothrow @nogc @safe this(
        in Transformation t = Transformation(), Material m = Material()
        )
    {
        super(t, m);
        aabb = AABB(Point(-1.0, -1.0, -1.0), Point(1.0, 1.0, 1.0));
    }

    /**
    * Method: Convert a 3D point (x, y, z) on the Sphere 
    * in a 2D point (u, v) on the screen/Image
    * Params: 
    *   p = (Point)
    * Return: Vec2d
    */
    override pure nothrow @nogc @safe Vec2d uv(in Point p) const
    {
        immutable float z = fixBoundary(p.z, -1.0, 1.0);
        immutable float u = atan2(p.y, p.x) / (2.0 * PI);
        return Vec2d(u < 0.0 ? u + 1.0 : u, acos(z) / PI);
    }

    /**
    * Create a Normal to a Vector in a Point of the Sphere
    * Params: 
    *   p = (Point)
    *   v = (Vec)
    * Return: Normal
    */
    override pure nothrow @nogc @safe Normal normal(in Point p, in Vec v) const
    {
        immutable n = Normal(p.x, p.y, p.z);
        return p.toVec * v < 0.0 ? n : -n;
    }

    pure nothrow @nogc @safe float[2] sphereIntersections(in Ray r) const
    {
        immutable Vec originVec = r.origin.toVec;

        immutable float halfB = originVec * r.dir;
        immutable float a = r.dir.squaredNorm;
        immutable float c = originVec.squaredNorm - 1.0;
        immutable float reducedDelta = halfB * halfB - a * c;

        if (reducedDelta < 0.0) return [float.init, float.init];
        return [(-halfB - sqrt(reducedDelta)) / a,
                (-halfB + sqrt(reducedDelta)) / a];
    }

    override pure nothrow @safe float[] allIntersections(in Ray r) const
    {
        immutable float[2] t = sphereIntersections(transf.inverse * r);
        if (t[0].isNaN) return [];
        return t.dup;
    }

    /**
    * Check and record an intersection between a Ray and a Sphere
    * Params: 
    *   r =  (Ray)
    * Return: Nullable!HitRecord
    */
    override pure nothrow @nogc @safe Nullable!HitRecord rayIntersection(
        in Ray r
        )
    {
        immutable Ray invR = transf.inverse * r;
        immutable float[2] t = sphereIntersections(invR);

        Nullable!HitRecord hit;
        if (t[0].isNaN) return hit;

        float firstHit;
        if (t[0] > invR.tMin && t[0] < invR.tMax) firstHit = t[0];
        else if (t[1] > invR.tMin && t[1] < invR.tMax) firstHit = t[1];
        else return hit;

        immutable Point hitPoint = invR.at(firstHit);
        hit = HitRecord(
            transf * hitPoint,
            transf * normal(hitPoint, invR.dir),
            uv(hitPoint),
            firstHit,
            r,
            this
            );
        return hit;
    }

    /**
    * Look up quickly for intersection between a Ray and a Shape
    * Params:
    *   r = (Ray)
    * Return: true or false (bool)
    */
    override pure nothrow @nogc @safe bool quickRayIntersection(in Ray r) const
    {
        immutable Ray invR = transf.inverse * r;
        immutable float[2] t = sphereIntersections(invR);

        if (t[0].isNaN) return false;
        return (t[0] > invR.tMin && t[0] < invR.tMax) ||
               (t[1] > invR.tMin && t[1] < invR.tMax);
    }

    override pure nothrow @nogc @safe bool isInside(in Point p) const
    {
        return p.x * p.x + p.y * p.y + p.z * p.z < 1.0;
    }
}

///
unittest
{
    import geometry : vecX, vecZ;

    auto s = new Sphere();

    assert(s.transformAABB.isClose(s.aabb));

    auto notHitRay = Ray(Point(0.0, 10.0, 2.0), -vecZ);
    assert(!s.quickRayIntersection(notHitRay));
    assert(s.rayIntersection(notHitRay).isNull);

    auto r1 = Ray(Point(0.0, 0.0, 2.0), -vecZ);
    assert(s.quickRayIntersection(r1));
    HitRecord h1 = s.rayIntersection(r1).get;
    assert(HitRecord(
        Point(0.0, 0.0, 1.0),
        Normal(0.0, 0.0, 1.0),
        Vec2d(0.0, 0.0),
        1.0,
        r1
        ).recordIsClose(h1));

    auto r2 = Ray(Point(3.0, 0.0, 0.0), -vecX);
    assert(s.quickRayIntersection(r2));
    HitRecord h2 = s.rayIntersection(r2).get;
    assert(HitRecord(
        Point(1.0, 0.0, 0.0),
        Normal(1.0, 0.0, 0.0),
        Vec2d(0.0, 0.5),
        2.0,
        r2
        ).recordIsClose(h2));

    auto r3 = Ray(Point(0.0, 0.0, 0.0), vecX);
    assert(s.quickRayIntersection(r3));
    HitRecord h3 = s.rayIntersection(r3).get;
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

    auto translVec = Vec(10.0, 0.0, 0.0);
    auto s = new Sphere(translation(translVec));

    auto minPoint = s.aabb.min + Vec(10.0, 0.0, 0.0);
    auto maxPoint = s.aabb.max + Vec(10.0, 0.0, 0.0);
    assert(s.transformAABB.isClose(AABB(minPoint, maxPoint)));

    auto notHitRay1 = Ray(Point(0.0, 0.0, 2.0), -vecZ);
    assert(!s.quickRayIntersection(notHitRay1));
    assert(s.rayIntersection(notHitRay1).isNull);

    auto notHitRay2 = Ray(Point(-10.0, 0.0, 0.0), -vecZ);
    assert(!s.quickRayIntersection(notHitRay2));
    assert(s.rayIntersection(notHitRay2).isNull);

    auto r1 = Ray(Point(10.0, 0.0, 2.0), -vecZ);
    assert(s.quickRayIntersection(r1));
    HitRecord h1 = s.rayIntersection(r1).get;
    assert(HitRecord(
        Point(10.0, 0.0, 1.0),
        Normal(0.0, 0.0, 1.0),
        Vec2d(0.0, 0.0),
        1.0,
        r1
        ).recordIsClose(h1));

    auto r2 = Ray(Point(13.0, 0.0, 0.0), -vecX);
    assert(s.quickRayIntersection(r2));
    HitRecord h2 = s.rayIntersection(r2).get;
    assert(HitRecord(
        Point(11.0, 0.0, 0.0),
        Normal(1.0, 0.0, 0.0),
        Vec2d(0.0, 0.5),
        2.0,
        r2
        ).recordIsClose(h2));
}

// ************************* Plane *************************
/**
* Class for a 3D infinite plane parallel to the x and y axis
* and passing through the origin (0, 0, 0)
*/
class Plane : Shape
{
    
    /**
    * Build a plane
    * Params: 
    *   t = (Tranformation)
    *   m = (Material)
    */
    pure nothrow @nogc @safe this(
        in Transformation t = Transformation(), Material m = Material()
        )
    {
        super(t, m);
        aabb = AABB(
            Point(-float.infinity, -float.infinity, 0.0),
            Point(float.infinity, float.infinity, 0.0)
            );
    }

    override pure nothrow @nogc @safe Vec2d uv(in Point p) const
    {
        return Vec2d(p.x - floor(p.x), p.y - floor(p.y));
    }

    override pure nothrow @nogc @safe Normal normal(in Point p, in Vec v) const
    {
        return Normal(0.0, 0.0, v.z < 0.0 ? 1.0 : -1.0);
    }

    override pure nothrow @safe float[] allIntersections(in Ray r) const
    {
        immutable Ray invR = transf.inverse * r;
        if (areClose(invR.dir.z, 0.0)) return [];
        return [-invR.origin.z / invR.dir.z];
    }

    /**
    * Check and record an intersection between a Ray and a Plane
    * Params: 
    *   r = (Ray)
    * Return: Nullable!HitRecord
    */
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
            uv(hitPoint),
            t,
            r,
            this
            );
        return hit;
    }

    /**
    * Look up quickly for an intersection between a Ray and a Plane
    * Params:
    *   r = (Ray)
    * Return: true or false (bool)
    */
    override pure nothrow @nogc @safe bool quickRayIntersection(in Ray r) const
    {
        immutable Ray invR = transf.inverse * r;
        if (areClose(invR.dir.z, 0.0)) return false;

        float t = -invR.origin.z / invR.dir.z;
        return t > invR.tMin && t < invR.tMax;
    }

    override pure nothrow @nogc @safe bool isInside(in Point p) const
    {
        return p.z > 0.0;
    }
}

///
unittest
{
    import geometry : vecX, vecY, vecZ;

    auto p = new Plane();

    //assert(p.transformAABB.isClose(p.aabb));

    auto r1 = Ray(Point(0.0, 0.0, 1.0), -vecZ);
    assert(p.quickRayIntersection(r1));
    HitRecord h1 = p.rayIntersection(r1).get;
    assert(HitRecord(
        Point(0.0, 0.0, 0.0),
        Normal(0.0, 0.0, 1.0),
        Vec2d(0.0, 0.0),
        1.0,
        r1
        ).recordIsClose(h1));

    auto r2 = Ray(Point(0.0, 0.0, 1.0), vecZ);
    assert(!p.quickRayIntersection(r2));
    Nullable!HitRecord h2 = p.rayIntersection(r2);
    assert(h2.isNull);

    auto r3 = Ray(Point(0.0, 0.0, 1.0), vecX);
    assert(!p.quickRayIntersection(r3));
    Nullable!HitRecord h3 = p.rayIntersection(r3);
    assert(h3.isNull);

    auto r4 = Ray(Point(0.0, 0.0, 1.0), vecY);
    assert(!p.quickRayIntersection(r4));
    Nullable!HitRecord h4 = p.rayIntersection(r4);
    assert(h4.isNull);
}

///
unittest
{
    import geometry : vecX, vecY, vecZ;

    auto p = new Plane(rotationY(90.0));

    //assert(p.transformAABB.isClose(p.aabb));

    auto r1 = Ray(Point(1.0, 0.0, 0.0), -vecX);
    assert(p.quickRayIntersection(r1));
    HitRecord h1 = p.rayIntersection(r1).get;
    assert(HitRecord(
        Point(0.0, 0.0, 0.0),
        Normal(1.0, 0.0, 0.0),
        Vec2d(0.0, 0.0),
        1.0,
        r1
        ).recordIsClose(h1));

    auto r2 = Ray(Point(0.0, 0.0, 1.0), vecZ);
    assert(!p.quickRayIntersection(r2));
    Nullable!HitRecord h2 = p.rayIntersection(r2);
    assert(h2.isNull);

    auto r3 = Ray(Point(0.0, 0.0, 1.0), vecX);
    assert(!p.quickRayIntersection(r3));
    Nullable!HitRecord h3 = p.rayIntersection(r3);
    assert(h3.isNull);

    auto r4 = Ray(Point(0.0, 0.0, 1.0), vecY);
    assert(!p.quickRayIntersection(r4));
    Nullable!HitRecord h4 = p.rayIntersection(r4);
    assert(h4.isNull);
}

///
unittest
{
    import geometry : vecZ;

    auto p = new Plane();

    auto r1 = Ray(Point(0.0, 0.0, 1.0), -vecZ);
    assert(p.quickRayIntersection(r1));
    HitRecord h1 = p.rayIntersection(r1).get;
    assert(h1.surfacePoint.uvIsClose(Vec2d(0.0, 0.0)));

    auto r2 = Ray(Point(0.25, 0.75, 1.0), -vecZ);
    assert(p.quickRayIntersection(r2));
    HitRecord h2 = p.rayIntersection(r2).get;
    assert(h2.surfacePoint.uvIsClose(Vec2d(0.25, 0.75)));

    auto r3 = Ray(Point(4.25, 7.75, 1.0), -vecZ);
    assert(p.quickRayIntersection(r3));
    HitRecord h3 = p.rayIntersection(r3).get;
    assert(h3.surfacePoint.uvIsClose(Vec2d(0.25, 0.75)));
}

// ************************* AABox *************************
/**
* Class for a 3D Axis Aligned Box
*/
class AABox : Shape
{
    /**
    * Build an AABox
    * Params:
    *   t = (Transformation)
    *   m = (Material)
    */
    pure nothrow @nogc @safe this(
        in Transformation t = Transformation(), Material m = Material()
        )
    {
        super(t, m);
        aabb = AABB(Point(0.0, 0.0, 0.0), Point(1.0, 1.0, 1.0));
    }

    /**
    * Build an AABox
    * Params:
    *   max = (Point)
    *   min = (Point)
    *   xDegreesAngle = (float)
    *   yDegreesAngle = (float)
    *   zDegreesAngle = (float)
    *   m = (Material)
    */
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
        aabb = AABB(Point(0.0, 0.0, 0.0), Point(1.0, 1.0, 1.0));
    }

    /**
    * Method: Convert a 3D point (x, y, z) on the AABox 
    * in a 2D point (u, v) on the screen/Image
    * Params: 
    *   p = (Point)
    * Return: Vec2d
    */
    override pure nothrow @nogc @safe Vec2d uv(in Point p) const
    {
        float uBox, vBox;
        if (areClose(p.x, 0.0, 1e-4))
            uBox = (1.0 + p.y) / 3.0, vBox = (2.0 + p.z) / 4.0;
        else if (areClose(p.x, 1.0, 1e-4))
            uBox = (1.0 + p.y) / 3.0, vBox = (1.0 - p.z) / 4.0;
        else if (areClose(p.y, 0.0, 1e-4))
            uBox = (1.0 - p.x) / 3.0, vBox = (2.0 + p.z) / 4.0;
        else if (areClose(p.y, 1.0, 1e-4))
            uBox = (2.0 + p.x) / 3.0, vBox = (2.0 + p.z) / 4.0;
        else if (areClose(p.z, 0.0, 1e-4))
            uBox = (1.0 + p.y) / 3.0, vBox = (2.0 - p.x) / 4.0;
        else
        {
            assert(areClose(p.z, 1.0, 1e-4));
            uBox = (1.0 + p.y) / 3.0, vBox = (3.0 + p.x) / 4.0;
        }

        return Vec2d(fixBoundary(uBox), fixBoundary(vBox));
    }

    /**
    * Create a Normal to a Vector in a Point of the AABox
    * Params: 
    *   p = (Point)
    *   v = (Vec)
    * Return: Normal
    */
    override pure nothrow @nogc @safe Normal normal(in Point p, in Vec v) const
    {
        if (areClose(p.x, 0.0, 1e-4) || areClose(p.x, 1.0, 1e-4))
            return Normal(v.x < 0.0 ? 1.0 : -1.0, 0.0, 0.0);
        else if (areClose(p.y, 0.0, 1e-4) || areClose(p.y, 1.0, 1e-4))
            return Normal(0.0, v.y < 0.0 ? 1.0 : -1.0, 0.0);
        else
        {
            assert(areClose(p.z, 0.0, 1e-4) || areClose(p.z, 1.0, 1e-4));
            return Normal(0.0, 0.0, v.z < 0.0 ? 1.0 : -1.0);
        }
    }

    /**
    * Find and record the intersections with the box
    * passing by each dimension x,y,z
    * Params: 
    *   r = (Ray)
    * Return: float[2]
    */
    pure nothrow @nogc @safe float[2] boxIntersections(in Ray r) const
    {
        immutable float[2] tX = oneDimIntersections(r.origin.x, r.dir.x);
        immutable float[2] tY = oneDimIntersections(r.origin.y, r.dir.y);
        immutable float[2] tZ = oneDimIntersections(r.origin.z, r.dir.z);
        return [max(tX[0], tY[0], tZ[0]), min(tX[1], tY[1], tZ[1])];
    }

    override pure nothrow @safe float[] allIntersections(in Ray r) const
    {
        immutable float[2] t = boxIntersections(transf.inverse * r);
        return t[0] > t[1] ? [] : t.dup;
    }

    /**
    * Check and record an intersection between a Ray and an AABOX
    * Params:
    *   r = (Ray)
    * Return: Nullable!HitRecord
    */
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
            transf * normal(hitPoint, invR.dir),
            uv(hitPoint),
            firstHit,
            r,
            this
            );
        return hit;
    }

    /**
    * Look up quickly for an intersection between a Ray and a Plane
    * Params:
    *   r = (Ray)
    * Return: true or false (bool)
    */
    override pure nothrow @nogc @safe bool quickRayIntersection(in Ray r) const
    {
        immutable Ray invR = transf.inverse * r;
        immutable float[2] t = boxIntersections(invR);

        if (t[0] > t[1] || t[0] >= invR.tMax || t[1] <= invR.tMin) return false;
        return t[0] > invR.tMin || t[1] < invR.tMax;
    }

    override pure nothrow @nogc @safe bool isInside(in Point p) const
    {
        return p.x > 0.0 && p.x < 1.0 &&
               p.y > 0.0 && p.y < 1.0 &&
               p.z > 0.0 && p.z < 1.0;
    }
}

///
unittest
{
    auto p1 = Point(1.0, 2.0, 4.0), p2 = Point(-1.0, 5.0, 5.0);
    auto box = new AABox(p1, p2, 0.0, 330.0, 0.0);

    auto minPoint = Point(0.5 - sqrt(3.0), 2.0, 3.0);
    auto maxPoint = Point(1.0, 5.0, 4.0 + sqrt(3.0) / 2.0);
    assert(box.transformAABB.isClose(AABB(minPoint, maxPoint)));

    auto scale = scaling(Vec(-2.0, 3.0, 1.0));
    auto rotY = rotationY(-30.0);
    auto transl = translation(Vec(1.0, 2.0, 4.0));
    assert(box.transf.transfIsClose(transl * rotY * scale));
}

///
unittest
{
    import geometry : vecX, vecY;

    auto box = new AABox();

    assert(box.transformAABB.isClose(box.aabb));

    auto r1 = Ray(Point(-2.0, 0.5, 0.0), -vecX);
    assert(!box.quickRayIntersection(r1));
    Nullable!HitRecord h1 = box.rayIntersection(r1);
    assert(h1.isNull);

    auto r2 = Ray(Point(0.0, 0.3, 0.7), vecY);
    assert(box.quickRayIntersection(r2));
    HitRecord h2 = box.rayIntersection(r2).get;
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
    HitRecord h3 = box.rayIntersection(r3).get;
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

    auto box = new AABox(transl * rotY * scale);

    auto minPoint = Point(-1.0, 2.0, 4.0 - 0.4 * sqrt(3.0));
    auto maxPoint = Point(-0.6 + sqrt(3.0), 5.0, 5.0);
    assert(box.transformAABB.isClose(AABB(minPoint, maxPoint)));

    auto p1 = Point(-1.0, 2.0, 4.0), p2 = Point(1.0, 5.0, 3.2);
    auto pointsConstructorBox = new AABox(p1, p2, 0.0, -30.0, 0.0);

    assert(pointsConstructorBox.transf.transfIsClose(box.transf));
    assert(pointsConstructorBox.transformAABB.isClose(box.transformAABB));

    float z = 4.0 - sqrt(3.0) / 3.0;

    auto r1 = Ray(Point(-1.0, 8.0, z), -vecY);
    assert(!box.quickRayIntersection(r1));
    Nullable!HitRecord h1 = box.rayIntersection(r1);
    assert(h1.isNull);

    auto r2 = Ray(Point(-0.66667, 8.0, z), -vecY);
    assert(!box.quickRayIntersection(r2));
    Nullable!HitRecord h2 = box.rayIntersection(r2);
    assert(h2.isNull);

    auto r3 = Ray(Point(-2.0 / 3.0, 8.0, z), -vecY);
    assert(box.quickRayIntersection(r3));
    HitRecord h3 = box.rayIntersection(r3).get;
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
    HitRecord h4 = box.rayIntersection(r4).get;
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
    HitRecord h5 = box.rayIntersection(r5).get;
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

    auto vert1 = Ray(Point(sqrt(3.0) / 4.0 - 1.0, 3.8, 4.5), -vecZ);
    assert(box.quickRayIntersection(vert1));
    HitRecord hVert1 = box.rayIntersection(vert1).get;
    assert(HitRecord(
        Point(sqrt(3.0) / 4.0 - 1.0, 3.8, 4.25),
        1.25 * Normal(-0.5, 0.0, sqrt(3.0) / 2.0),
        Vec2d(8.0 / 15.0, 0.4375),
        0.25,
        vert1,
        box
        ).recordIsClose(hVert1));

    auto vert2 = Ray(
        Point(sqrt(3.0) - 0.9, 3.0, 5.0 + 0.9 * sqrt(3.0)),
        -vecZ
        );
    assert(box.quickRayIntersection(vert2));
    HitRecord hVert2 = box.rayIntersection(vert2).get;
    assert(HitRecord(
        Point(sqrt(3.0) - 0.9, 3.0, 5.0 - 0.1 * sqrt(3.0)),
        0.5 * Normal(sqrt(3.0) / 2.0, 0.0, 0.5),
        Vec2d(4.0 / 9.0, 0.1875),
        sqrt(3.0),
        vert2,
        box
        ).recordIsClose(hVert2));
}

// ************************* CylinderShell *************************
/**
* Class for a 3D Cylinder shell (lateral suface) aligned with the z axis
*/
class CylinderShell : Shape
{
    /**
    * Build a CylinderShell 
    * Params: 
    *   t = (Tranformation)
    *   m = (Material)
    */
    pure nothrow @nogc @safe this(
        in Transformation t = Transformation(), Material m = Material()
        )
    {
        super(t, m);
        aabb = AABB(Point(-1.0, -1.0, 0.0), Point(1.0, 1.0, 1.0));
    }

    /**
    * Build a CylinderShell 
    * Params: 
    *   r = (float) radius 
    *   max = (Point) center of upper face
    *   min = (Point) center of lower face
    *   m = (Material)
    */
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
        aabb = AABB(Point(-1.0, -1.0, 0.0), Point(1.0, 1.0, 1.0));
    }

    /**
    * Build a CylinderShell 
    * Params: 
    *   r = (float) radius
    *   h = (float) lenght  
    *   trasl = (Vec) translation Vector
    *   m = (Material)
    */
    pure nothrow @nogc @safe this(
        in float r, in float h, in Vec transl = Vec(), Material m = Material()
        )
    in (!areClose(r, 0.0))
    in (!areClose(h, 0.0))
    {
        transf = translation(transl) * scaling(Vec(r, r, h));
        material = m;
        aabb = AABB(Point(-1.0, -1.0, 0.0), Point(1.0, 1.0, 1.0));
    }

    /**
    * Build a CylinderShell 
    * Params: 
    *   r = (float) radius
    *   h = (float) lenght  
    *   traslVec = (Vec) translation Vector
    *   xDegreesAngle = (float)
    *   yDegreesAngle = (float)
    *   zDegreesAngle = (float)
    *   m = (Material)
    */
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
        aabb = AABB(Point(-1.0, -1.0, 0.0), Point(1.0, 1.0, 1.0));
    }

    /**
    * Convert a 3D point (x, y, z) on the CylinderShell
    * in a 2D point (u, v) on the screen/Image
    * Params:
    *   p = (Point)
    * Return: Vec2d
    */
    override pure nothrow @nogc @safe Vec2d uv(in Point p) const
    {
        immutable float z = fixBoundary(p.z);
        immutable float u = atan2(p.y, p.x) / (2.0 * PI);
        return Vec2d(u < 0.0 ? u + 1.0 : u, z);
    }

    /**
    * Create a Normal to a Vector in a Point of the CylinderShell surface
    * Params:
    *   p = (Point)
    *   v = (Vec)
    * Return: n (Normal)
    */
    override pure nothrow @nogc @safe Normal normal(in Point p, in Vec v) const
    {
        immutable Normal n = Normal(p.x, p.y, 0.0);
        return p.x * v.x + p.y * v.y < 0.0 ? n : -n;
    }

    /**
    * Find and record the intersections with the infinite shell
    * passing by each dimension x, y, z
    * Params: 
    *    r = (Ray)
    * Return: float[2]
    */
    pure nothrow @nogc @safe float[2] shellIntersections(
        in Ray r
        ) const
    {
        immutable float c = r.origin.x * r.origin.x +
                            r.origin.y * r.origin.y -
                            1.0;
        if (areClose(r.dir.x, 0.0) && areClose(r.dir.y, 0.0))
        // Cylindershell will not be hit by a vertical ray:
        // this differentiation is useful only for Cylinder.
            return c <= 0.0 ? [-float.infinity, float.infinity] :
                              [float.infinity, -float.infinity];

        immutable float halfB = r.origin.x * r.dir.x + r.origin.y * r.dir.y;
        immutable float a = r.dir.x * r.dir.x + r.dir.y * r.dir.y;
        immutable float reducedDelta = halfB * halfB - a * c;

        if (reducedDelta < 0.0) return [float.infinity, -float.infinity];
        return [(-halfB - sqrt(reducedDelta)) / a,
                (-halfB + sqrt(reducedDelta)) / a];
    }

    override pure nothrow @safe float[] allIntersections(in Ray r) const
    {
        immutable Ray invR = transf.inverse * r;
        immutable float[2] tShell = shellIntersections(invR);
        immutable float[2] tZ = oneDimIntersections(invR.origin.z, invR.dir.z);

        if (tShell[0] > tZ[1] || tShell[1] < tZ[0]) return [];
        if (tShell[0] < tZ[0])
        {
            if (tShell[1] > tZ[1]) return [];
            return [tShell[1]];
        }
        if (tShell[1] > tZ[1]) return [tShell[0]];
        return tShell.dup;
    }

    /**
    * Check and record an intersection between a Ray and a CylinderShell
    * Params:
    *   r = (Ray) 
    * Return: Nullable!Hitrecord
    */
    override pure nothrow @nogc @safe Nullable!HitRecord rayIntersection(
        in Ray r
        )
    {
        Nullable!HitRecord hit;
        immutable Ray invR = transf.inverse * r;

        immutable float[2] tShell = shellIntersections(invR);
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
            transf * normal(hitPoint, invR.dir),
            uv(hitPoint),
            firstHit,
            r,
            this
            );
        return hit;
    }

    /**
    * Look up quickly for intersection between a Ray and a CylinderShell
    * Params:
    *   r = (Ray)
    * Return: true or false (bool)
    */
    override pure nothrow @nogc @safe bool quickRayIntersection(in Ray r) const
    {
        immutable Ray invR = transf.inverse * r;

        immutable float[2] tShell = shellIntersections(invR);
        if(tShell[0] >= invR.tMax || tShell[1] <= invR.tMin) return false;

        immutable float[2] tZ = oneDimIntersections(invR.origin.z, invR.dir.z);
        if (tShell[0] > tZ[1] || tShell[1] < tZ[0]) return false;

        return (tShell[0] >= tZ[0] && tShell[0] > invR.tMin)
            || (tShell[1] <= tZ[1] && tShell[1] < invR.tMax);
    }

    override pure nothrow @nogc @safe bool isInside(in Point p) const
    {
        return false;
    }
}

///
unittest
{
    import geometry : vecX;

    auto shell = new CylinderShell(
        translation(Vec(1.0, 1.0, 0.0)) * scaling(Vec(1.0, 1.0, 2.0)),
        );

    auto minPoint = Point(0.0, 0.0, 0.0);
    auto maxPoint = Point(2.0, 2.0, 2.0);
    assert(shell.transformAABB.isClose(AABB(minPoint, maxPoint)));

    auto r1 = Ray(Point(-1.0, 1.0, 1.2), vecX);
    assert(shell.quickRayIntersection(r1));
    HitRecord h1 = shell.rayIntersection(r1).get;
    assert(HitRecord(
        Point(0.0, 1.0, 1.2),
        Normal(-1.0, 0.0, 0.0),
        Vec2d(0.5, 0.6),
        1.0,
        r1,
        shell
        ).recordIsClose(h1));

    auto r2 = Ray(Point(-1.0, 1.0, 0.0), Vec(1.0, 0.5, 0.0));
    assert(shell.quickRayIntersection(r2));
    HitRecord h2 = shell.rayIntersection(r2).get;
    assert(HitRecord(
        Point(0.2, 1.6, 0.0),
        Normal(-0.8, 0.6, 0.0),
        Vec2d(0.5 - acos(0.8) / (2 * PI), 0.0),
        1.2,
        r2,
        shell
        ).recordIsClose(h2));

    auto r3 = Ray(Point(-1.0, 1.0, -1e-10), vecX);
    assert(!shell.quickRayIntersection(r3));
    Nullable!HitRecord h3 = shell.rayIntersection(r3);
    assert(h3.isNull);

    auto r4 = Ray(Point(1.0, 1.0, 3.0), Vec(0.0, 0.5, -1.0));
    assert(shell.quickRayIntersection(r4));
    HitRecord h4 = shell.rayIntersection(r4).get;
    assert(HitRecord(
        Point(1.0, 2.0, 1.0),
        Normal(0.0, -1.0, 0.0),
        Vec2d(0.25, 0.5),
        2.0,
        r4,
        shell
        ).recordIsClose(h4));

    immutable float halfRayX = 1.0 + sqrt(3.0) / 2.0;
    auto r5 = Ray(Point(halfRayX, 1.0, 3.0), Vec(0.0, 0.5, -1.0));
    assert(!shell.quickRayIntersection(r5));
    Nullable!HitRecord h5 = shell.rayIntersection(r5);
    assert(h5.isNull);
}

///
unittest
{
    import geometry : vecY;

    auto shellTransf = translation(vecY) *
                       rotationX(45.0) *
                       scaling(Vec(1.0, 1.0, sqrt(2.0)));

    auto shell1 = new CylinderShell(shellTransf);

    auto minPoint = Point(-1.0, -sqrt(2.0) / 2.0, -sqrt(2.0) / 2.0);
    auto maxPoint = Point(1.0, 1.0 + sqrt(2.0) / 2.0, 1.0 + sqrt(2.0) / 2.0);
    assert(shell1.transformAABB.isClose(AABB(minPoint, maxPoint)));

    auto shell2 = new CylinderShell(
        1.0, Point(0.0, 1.0, 0.0), Point(0.0, 0.0, 1.0)
        );

    assert(shell2.transformAABB.isClose(shell1.transformAABB));

    auto ray1 = Ray(Point(0.0, 3.0, 0.0), -vecY);

    assert(shell1.quickRayIntersection(ray1));
    HitRecord h1 = shell1.rayIntersection(ray1).get;
    assert(HitRecord(
        Point(0.0, 1.0 - sqrt(2.0), 0.0),
        Normal(0.0, sqrt(2.0) / 2.0, sqrt(2.0) / 2.0),
        Vec2d(0.75, sqrt(2.0) / 2.0),
        2.0 + sqrt(2.0),
        ray1,
        shell1
        ).recordIsClose(h1));

    assert(shell2.quickRayIntersection(ray1));
    HitRecord h2 = shell2.rayIntersection(ray1).get;
    assert(HitRecord(
        Point(0.0, 1.0 - sqrt(2.0), 0.0),
        Normal(0.0, sqrt(2.0) / 2.0, sqrt(2.0) / 2.0),
        Vec2d(0.0, sqrt(2.0) / 2.0),
        2.0 + sqrt(2.0),
        ray1,
        shell2
        ).recordIsClose(h2));

    auto ray2 = Ray(Point(0.0, -1.0, 2.0), Vec(0.0, 1.0, -1.0));

    assert(!shell1.quickRayIntersection(ray2));
    Nullable!HitRecord notH1 = shell1.rayIntersection(ray2);
    assert(notH1.isNull);

    assert(!shell2.quickRayIntersection(ray2));
    Nullable!HitRecord notH2 = shell2.rayIntersection(ray2);
    assert(notH2.isNull);
}

// ************************* Cylinder *************************
/**
* Class for a 3D Cylinder aligned with the z axis
*/
class Cylinder : CylinderShell
{
    /**
    * Build a Cylinder 
    * Params: 
    *   t = (Tranformation)
    *   m = (Material)
    */
    pure nothrow @nogc @safe this(
        in Transformation t = Transformation(), Material m = Material()
        )
    {
        super(t, m);
    }

    /**
    * Build a Cylinder 
    * Params: 
    *   radius r (float)
    *   max = (Point) center of upper face
    *   min = (Point) center of lower face
    *   m = (Material)
    */
    pure nothrow @nogc @safe this(
        in float r, in Point min, in Point max, Material m = Material()
        )
    {
        super(r, min, max, m);
    }
    
    /**
    * Build a Cylinder
    * Params: 
    *   r = (float) radius
    *   h = (float) lenght
    *   t = (Transformation)
    *   m = (Material)
    */
    pure nothrow @nogc @safe this(
        in float r, in float h, in Vec transl = Vec(), Material m = Material()
        )
    {
        super(r, h, transl, m);
    }

    /** 
    * Build a Cylinder
    * Params: 
    *   r = (float) radius
    *   h = (float) lenght  
    *   trasl = (Vec) translation Vector
    *   xDegreesAngle = (float)
    *   yDegreesAngle = (float)
    *   zDegreesAngle = (float)
    *   m = (Material)
    */
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

    /**
    * Convert a 3D point (x, y, z) on the Cylinder 
    * in a 2D point (u, v) on the screen/Image
    * Params:
    *   p = (Point)
    * @Ŗeturns: Vec2d
    */
    override pure nothrow @nogc @safe Vec2d uv(in Point p) const
    {
        float u = atan2(p.y, p.x) / (2.0 * PI);
        if (u < 0.0) ++u;
        immutable float quarterRho = 0.25 * sqrt(p.x * p.x + p.y * p.y);

        if (areClose(p.z, 0.0)) return Vec2d(u, quarterRho);
        if (areClose(p.z, 1.0)) return Vec2d(u, 1.0 - quarterRho);
        return Vec2d(u, 0.25 + 0.5 * p.z);
    }

    /**
    * Create a Normal to a Vector in a Point of the Cylinder surface
    * Params:
    *   p = (Point)
    *   v = (Vec)
    * Return: Normal
    */
    override pure nothrow @nogc @safe Normal normal(in Point p, in Vec v) const
    {
        if (!areClose(p.z, 0.0) && !areClose(p.z, 1.0))
            return super.normal(p, v);
        immutable n = Normal(0.0, 0.0, 1.0);
        return v.z < 0.0 ? n : -n;
    }

    pure nothrow @nogc @safe float[2] cylinderIntersections(in Ray r) const
    {
        immutable float[2] tShell = shellIntersections(r);
        immutable float[2] tZ = oneDimIntersections(r.origin.z, r.dir.z);
        return [max(tShell[0], tZ[0]), min(tShell[1], tZ[1])];
    }

    override pure nothrow @safe float[] allIntersections(in Ray r) const
    {
        immutable float[2] t = cylinderIntersections(transf.inverse * r);
        return t[0] > t[1] ? [] : t.dup;
    }

    /**
    * Check and record an intersection between a Ray and a Cylinder
    * Params:
    *   r = (Ray)
    * Return: Nullable!HitRecord
    */
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
            transf * normal(hitPoint, invR.dir),
            uv(hitPoint),
            firstHit,
            r,
            this
            );
        return hit;
    }

    /**
    * Look up quickly for intersection between a Ray and a Cylinder
    * Params:
    *   r = (Ray)
    * Return: true or false (bool)
    */
    override pure nothrow @nogc @safe bool quickRayIntersection(in Ray r) const
    {
        immutable Ray invR = transf.inverse * r;
        immutable float[2] t = cylinderIntersections(invR);

        if (t[0] > t[1] || t[0] >= invR.tMax || t[1] <= invR.tMin) return false;
        return (t[0] > invR.tMin) || (t[1] < invR.tMax);
    }

    override pure nothrow @nogc @safe bool isInside(in Point p) const
    {
        immutable radius = p.x * p.x + p.y * p.y;
        return p.z > 0.0 && p.z < 1.0 && radius > 0.0 && radius < 1.0;
    }
}

///
unittest
{
    import geometry : vecX, vecZ;

    auto cyl = new Cylinder(
        translation(Vec(1.0, 1.0, 0.0)) * scaling(Vec(1.0, 1.0, 2.0)),
        );

    auto r1 = Ray(Point(-1.0, 1.0, 1.2), vecX);
    assert(cyl.quickRayIntersection(r1));
    HitRecord h1 = cyl.rayIntersection(r1).get;
    assert(HitRecord(
        Point(0.0, 1.0, 1.2),
        Normal(-1.0, 0.0, 0.0),
        Vec2d(0.5, 0.55),
        1.0,
        r1,
        cyl
        ).recordIsClose(h1));

    auto r2 = Ray(Point(-1.0, 1.0, 0.0), Vec(1.0, 0.5, 0.0));
    assert(cyl.quickRayIntersection(r2));
    HitRecord h2 = cyl.rayIntersection(r2).get;
    assert(HitRecord(
        Point(0.2, 1.6, 0.0),
        Normal(0.0, 0.0, -0.5),
        Vec2d(0.5 - acos(0.8) / (2 * PI), 0.25),
        1.2,
        r2,
        cyl
        ).recordIsClose(h2));

    auto r3 = Ray(Point(-1.0, 1.0, -1e-10), vecX);
    assert(!cyl.quickRayIntersection(r3));
    Nullable!HitRecord h3 = cyl.rayIntersection(r3);
    assert(h3.isNull);
    
    auto r4 = Ray(Point(1.0, 1.0, 3.7), -vecZ);
    assert(cyl.quickRayIntersection(r4));
    HitRecord h4 = cyl.rayIntersection(r4).get;
    assert(HitRecord(
        Point(1.0, 1.0, 2.0),
        0.5 * Normal(0.0, 0.0, 1.0),
        Vec2d(0.0, 1.0),
        1.7,
        r4,
        cyl
        ).recordIsClose(h4));

    auto r5 = Ray(Point(1.0, 1.0, 3.0), Vec(0.0, 0.5, -1.0));
    assert(cyl.quickRayIntersection(r5));
    HitRecord h5 = cyl.rayIntersection(r5).get;
    assert(HitRecord(
        Point(1.0, 1.5, 2.0),
        0.5 * Normal(0.0, 0.0, 1.0),
        Vec2d(0.25, 0.875),
        1.0,
        r5,
        cyl
    ).recordIsClose(h5));

    float halfRayX = 1.0 + sqrt(3.0) / 2.0;
    auto r6 = Ray(Point(halfRayX, 1.0, 3.0), Vec(0.0, 0.5, -1.0));
    assert(!cyl.quickRayIntersection(r6));
    Nullable!HitRecord h6 = cyl.rayIntersection(r6);
    assert(h6.isNull);
}

///
unittest
{
    import geometry : vecY, vecZ;

    auto cylTransf = translation(vecY) * rotationX(45.0);
    auto cyl1 = new Cylinder(cylTransf);

    immutable cos45 = sqrt(2.0) / 2.0;
    auto cyl2 = new Cylinder(
        1.0,
        Point(0.0, 1.0, 0.0),
        Point(0.0, 1.0 - cos45, cos45)
        );

    auto ray1 = Ray(Point(0.0, 3.0, 0.01), -vecY);

    assert(cyl1.quickRayIntersection(ray1));
    HitRecord orizzontalHit1 = cyl1.rayIntersection(ray1).get;
    assert(HitRecord(
        Point(0.0, 1.01, 0.01),
        Normal(0.0, cos45, -cos45),
        Vec2d(0.25, 0.0025 * sqrt(2.0)),
        1.99,
        ray1,
        cyl1
        ).recordIsClose(orizzontalHit1));

    assert(cyl2.quickRayIntersection(ray1));
    HitRecord orizzontalHit2 = cyl2.rayIntersection(ray1).get;
    assert(HitRecord(
        Point(0.0, 1.01, 0.01),
        Normal(0.0, cos45, -cos45),
        Vec2d(0.5, 0.0025 * sqrt(2.0)),
        1.99,
        ray1,
        cyl2
        ).recordIsClose(orizzontalHit2));

    immutable float zBelow = 2.0 - sqrt(2.0) - 1e-6;
    auto ray2 = Ray(Point(0.0, -1.0, zBelow), Vec(0.0, 1.0, -1.0));

    assert(!cyl1.quickRayIntersection(ray2));
    Nullable!HitRecord notHit1 = cyl1.rayIntersection(ray2);
    assert(notHit1.isNull);

    assert(!cyl2.quickRayIntersection(ray2));
    Nullable!HitRecord notHit2 = cyl2.rayIntersection(ray2);
    assert(notHit2.isNull);

    auto ray3 = Ray(Point(0.0, 0.0, 0.0), -vecZ);

    assert(cyl1.quickRayIntersection(ray3));
    HitRecord downHit1 = cyl1.rayIntersection(ray3).get;
    assert(HitRecord(
        Point(0.0, 0.0, 1.0 - sqrt(2.0)),
        Normal(0.0, cos45, cos45),
        Vec2d(0.75, 0.25 + 0.5 * (sqrt(2.0) - 1.0)),
        sqrt(2.0) - 1.0,
        ray3,
        cyl1
        ).recordIsClose(downHit1));

    assert(cyl2.quickRayIntersection(ray3));
    HitRecord downHit2 = cyl2.rayIntersection(ray3).get;
    assert(HitRecord(
        Point(0.0, 0.0, 1.0 - sqrt(2.0)),
        Normal(0.0, cos45, cos45),
        Vec2d(0.0, 0.25 + 0.5 * (sqrt(2.0) - 1.0)),
        sqrt(2.0) - 1.0,
        ray3,
        cyl2
        ).recordIsClose(downHit2));
    
    auto ray4 = Ray(Point(0.0, 0.0, 0.0), vecZ);

    assert(cyl1.quickRayIntersection(ray4));
    HitRecord upHit1 = cyl1.rayIntersection(ray4).get;
    assert(HitRecord(
        Point(0.0, 0.0, sqrt(2.0) - 1.0),
        Normal(0.0, cos45, -cos45),
        Vec2d(0.75, 1.0 - 0.25 * (sqrt(2.0) - 1.0)),
        sqrt(2.0) - 1.0,
        ray4,
        cyl1
        ).recordIsClose(upHit1));

    assert(cyl2.quickRayIntersection(ray4));
    HitRecord upHit2 = cyl2.rayIntersection(ray4).get;
    assert(HitRecord(
        Point(0.0, 0.0, sqrt(2.0) - 1.0),
        Normal(0.0, cos45, -cos45),
        Vec2d(0.0, 1.0 - 0.25 * (sqrt(2.0) - 1.0)),
        sqrt(2.0) - 1.0,
        ray4,
        cyl2
        ).recordIsClose(upHit2));
}

// ************************* World *************************
/**
* Struct for a 3D World where to put all the shapes of the image
*/
struct World
{
    Shape[] shapes;
    
    /**
    * Build a World from an array of Shapes
    * Params:
    *   s = (Shape[])
    */
    pure nothrow @nogc @safe this(Shape[] s)
    {
        shapes = s;
    }

    /**
    * Add a Shape to the list of the World
    * Params:
    *   s = (Shape)
    */
    pure nothrow @safe void addShape(Shape s)
    {
        shapes ~= s;
    }

    /**
    * Check and record an intersection between a Ray and each Shape of the World 
    * by calling their specific rayIntersection
    * Params:
    *   ray = (Ray)
    * Return: Nullable!HitRecord
    */
    pure nothrow @safe Nullable!HitRecord rayIntersection(in Ray ray)
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

    /**
    * Return if a Point of the World is visible or not
    * from the observer put in obsPos
    * Params:
    *   point = (Point)
    *   obsPos = (Point)
    * Return: true or false (bool)
    */
    pure nothrow @safe bool isPointVisible(
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

    assert(!world.isPointVisible(Point(10.0, 0.0, 0.0), Point(0.0, 0.0, 0.0)));
    assert(!world.isPointVisible(Point(5.0, 0.0, 0.0), Point(0.0, 0.0, 0.0)));
    assert(world.isPointVisible(Point(5.0, 0.0, 0.0), Point(4.0, 0.0, 0.0)));
    assert(world.isPointVisible(Point(0.5, 0.0, 0.0), Point(0.0, 0.0, 0.0)));
    assert(world.isPointVisible(Point(0.0, 10.0, 0.0), Point(0.0, 0.0, 0.0)));
    assert(world.isPointVisible(Point(0.0, 0.0, 10.0), Point(0.0, 0.0, 0.0)));
}