module shapes;

import geometry : Normal, Point, Vec2d;
import hdrimage : areClose;
import ray : Ray;
import std.math : sqrt;
import transformations : Transformation;
import typecons : Nullable;

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

        if (reducedDelta < 0) return Nullable!HitRecord;

        t1 = (- halfB - sqrt(reducedDelta)) / a;
        t2 = (- halfB + sqrt(reducedDelta)) / a;

        float firstHit;
        if (t1 > invR.tMin && t1 < invR.tMax) firstHit = t1;
        else if (t2 > invR.tMin && t2 < invR.tMax) firstHit = t2;
        else return Nullable!HitRecord;
    }
}