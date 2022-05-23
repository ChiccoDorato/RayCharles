module renderer;

import cameras : ImageTracer, OrthogonalCamera, PerspectiveCamera;
import geometry : Vec;
import hdrimage : black, Color, HDRImage, white;
import materials : DiffuseBRDF, Material, UniformPigment;
import pcg : PCG;
import ray : Ray;
import shapes : HitRecord, Sphere, World;
import std.algorithm : max;
import std.math : isNaN;
import std.typecons : Nullable;
import transformations : scaling, Transformation, translation;

class Renderer
{
    World world;
    Color backgroundColor;

    this(World w)
    {
        world = w;
    }

    this(World w, in Color bgCol)
    {
        this(w);
        backgroundColor = bgCol;
    }

    abstract Color call(in Ray r);
}

class OnOffRenderer : Renderer
{
    Color color = white;

    this(World w)
    {
        super(w);
    }

    this(World w, in Color bgCol, in Color col)
    {
        super(w, bgCol);
        color = col;
    }

    override Color call(in Ray r)
    {
        return world.rayIntersection(r).isNull ? backgroundColor : color;
    }
}

unittest
{
    Transformation transf = translation(Vec(2.0, 0.0, 0.0)) * scaling(Vec(0.2, 0.2, 0.2));
    Sphere sphere = new Sphere(transf, Material());
    World world = World([sphere]);

    HDRImage image = new HDRImage(3, 3);
    OrthogonalCamera camera = new OrthogonalCamera();
    ImageTracer tracer = ImageTracer(image, camera);

    Renderer renderer = new OnOffRenderer(world);
    tracer.fireAllRays((Ray r) => renderer.call(r));

    assert(image.getPixel(0, 0).colorIsClose(black));
    assert(image.getPixel(1, 0).colorIsClose(black));
    assert(image.getPixel(2, 0).colorIsClose(black));

    assert(image.getPixel(0, 1).colorIsClose(black));
    assert(image.getPixel(1, 1).colorIsClose(white));
    assert(image.getPixel(2, 1).colorIsClose(black));

    assert(image.getPixel(0, 2).colorIsClose(black));
    assert(image.getPixel(1, 2).colorIsClose(black));
    assert(image.getPixel(2, 2).colorIsClose(black));   
}

class FlatRenderer : Renderer
{
    this(World w)
    {
        super(w);
    }

    this(World w, in Color bgCol)
    {
        super(w, bgCol);
    }

    override Color call(in Ray r)
    {
        Nullable!HitRecord hit = world.rayIntersection(r);
        if (hit.isNull) return backgroundColor;

        Material material = hit.get.shape.material;
        return material.brdf.pigment.getColor(hit.get.surfacePoint) + 
        material.emittedRadiance.getColor(hit.get.surfacePoint);
    }
}

unittest
{
    Transformation transf = translation(Vec(2.0, 0.0, 0.0)) * scaling(Vec(0.2, 0.2, 0.2));
    Color sphereColor = Color(1.0, 2.0, 3.0);
    Material material = Material(new DiffuseBRDF(new UniformPigment(sphereColor)));
    Sphere sphere = new Sphere(transf, material);
    World world = World([sphere]);

    HDRImage image = new HDRImage(3, 3);
    OrthogonalCamera camera = new OrthogonalCamera();
    ImageTracer tracer = ImageTracer(image, camera);

    Renderer renderer = new FlatRenderer(world);
    tracer.fireAllRays((Ray r) => renderer.call(r));

    assert(image.getPixel(0, 0).colorIsClose(black));
    assert(image.getPixel(1, 0).colorIsClose(black));
    assert(image.getPixel(2, 0).colorIsClose(black));

    assert(image.getPixel(0, 1).colorIsClose(black));
    assert(image.getPixel(1, 1).colorIsClose(sphereColor));
    assert(image.getPixel(2, 1).colorIsClose(black));

    assert(image.getPixel(0, 2).colorIsClose(black));
    assert(image.getPixel(1, 2).colorIsClose(black));
    assert(image.getPixel(2, 2).colorIsClose(black));   
}

class PathTracer : Renderer
{
    PCG pcg = new PCG();
    int numberOfRays = 10, maxDepth = 2, russianRouletteLimit = 3;

    this(World w, in Color bgCol, PCG randomGenerator, int numOfRays, int depth, int RRLimit)
    {
        super(w, bgCol);
        pcg = randomGenerator;
        numberOfRays = numOfRays;
        maxDepth = depth;
        russianRouletteLimit = RRLimit;
    }

    override Color call(in Ray ray)
    {
        if (ray.depth > maxDepth) return Color();

        HitRecord hitRec = world.rayIntersection(ray).get(HitRecord());
        if (hitRec.t.isNaN) return backgroundColor;

        Material hitMat = hitRec.shape.material;
        Color hitCol = hitMat.brdf.pigment.getColor(hitRec.surfacePoint);
        float hitColLum = max(hitCol.r, hitCol.g, hitCol.b);
        Color emittedRadiance = hitMat.emittedRadiance.getColor(hitRec.surfacePoint);

        if (ray.depth >= russianRouletteLimit)
        {
            float q = max(0.05, 1.0 - hitColLum);
            if (pcg.randomFloat > q) hitCol = hitCol * (1.0 / (1.0 - q));
            else return emittedRadiance;
        }

        Color cumRadiance;
        if (hitColLum > 0.0)
        {
            for (int i = 0; i < numberOfRays; ++i)
            {
                Ray newRay = hitMat.brdf.scatterRay(pcg,
                    hitRec.ray.dir,
                    hitRec.worldPoint,
                    hitRec.normal,
                    ray.depth + 1);
                Color newRadiance = call(newRay);
                cumRadiance = cumRadiance + hitCol * newRadiance;
            }
        }

        return emittedRadiance + cumRadiance * (1.0 / numberOfRays);
    }
}