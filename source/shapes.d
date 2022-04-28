module shapes;

import geometry : Normal, Point, Vec, Vec2d;
import hdrimage : areClose;
import ray : Ray;
import std.math : acos, atan2, PI, sqrt;
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

Vec2d sphereUVPoint(Point p)
{
    float u = atan2(p.y, p.x) / (2.0 * PI);
    return Vec2d(u >= 0 ? u : u + 1.0, acos(p.z) / PI);
}

Normal sphereNormal(Point p, Vec v)
{
    Normal n = Normal(p.x, p.y, p.z);
    return p.convert * v < 0 ? n : -n;
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