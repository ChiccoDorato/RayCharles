module renderers;

import cameras : ImageTracer, OrthogonalCamera, PerspectiveCamera;
import geometry : Point, Vec, vecX;
import hdrimage : areClose, black, Color, HDRImage, white;
import materials : DiffuseBRDF, Material, UniformPigment;
import pcg;
import ray;
import shapes : HitRecord, Sphere, World;
import std.algorithm : max;
import std.math : isNaN;
import std.typecons : Nullable;
import transformations : scaling, Transformation, translation;

// ************************* Renderer *************************
/// Class representing a Renderer - Members: World, backgroundColor (Color)
class Renderer
{
    World world;
    Color backgroundColor;

    /// Build a Renderer - Parameter: World
    pure nothrow @safe this(World w)
    {
        world = w;
    }

    /// Build a Renderer - Parameter: World, Color
    pure nothrow @safe this(World w, in Color bgCol)
    {
        this(w);
        backgroundColor = bgCol;
    }

    /// Return a Color form a Ray that hit a shape in the World
    abstract pure nothrow Color call(in Ray r);
}

// ************************* OnOffRenderer *************************
/// Class representing a OnOffRenderer
class OnOffRenderer : Renderer
{
    Color color = white;

    /// Build an OnOffRenderer - Parameter: World
    ///
    /// Use super(World)
    pure nothrow @safe this(World w)
    {
        super(w);
    }

    /// Build an OnOffRenderer - Parameter: World, 2 Colors (backgroundColor & color)
    ///
    /// Use super(World, backgroundColor)
    pure nothrow @safe this(World w, in Color bgCol, in Color col)
    {
        super(w, bgCol);
        color = col;
    }

    /// Return a Color form a Ray that hit a shape in the World
    ///
    /// The Color is the background one if there is no intersection
    override pure nothrow @safe Color call(in Ray r)
    {
        return world.rayIntersection(r).isNull ? backgroundColor : color;
    }
}

///
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
    // call
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

// ************************* FlatRenderer *************************
/// Class representing a FlatRenderer
class FlatRenderer : Renderer
{
    /// Build an FlatRenderer - Parameter: World
    ///
    /// Use super(World)
    pure nothrow @safe this(World w)
    {
        super(w);
    }

    /// Build an OnOffRenderer - Parameter: World, backgroundColor (Color)
    ///
    /// Use super(World, backgroundColor)
    pure nothrow @safe this(World w, in Color bgCol)
    {
        super(w, bgCol);
    }

    /// Return a Color form a Ray that hit a shape in the World
    ///
    /// The Color is the background one if there is no intersection
    /// 
    /// The emitted radiance from the material of an object is taken into account
    override pure nothrow @safe Color call(in Ray r)
    {
        Nullable!HitRecord hit = world.rayIntersection(r);
        if (hit.isNull) return backgroundColor;

        Material material = hit.get.shape.material;
        return material.brdf.pigment.getColor(hit.get.surfacePoint) + 
        material.emittedRadiance.getColor(hit.get.surfacePoint);
    }
}

///
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
    // call
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

// ************************* PathTracer *************************
/// Class representing a PathTracer - Professional Renderer with new members:
/// PCG, number of rays (int), max depth (int), russianRouletteLimit (int) 
class PathTracer : Renderer
{
    PCG pcg = new PCG();
    int numberOfRays = 10, maxDepth = 2, russianRouletteLimit = 3;

    /// Build a PathTracer - Parameters: World, backgroundColor (Color), PCG, 
    /// number of rays (int), max depth (int), russianRouletteLimit (int) 
    ///
    /// Use super(World, backgroundColor)
    pure nothrow @safe this(World w, in Color bgCol = black, PCG randomGenerator = new PCG(),
        in int numOfRays = 10, in int depth = 2, in int RRLimit = 3)
    {
        super(w, bgCol);
        pcg = randomGenerator;
        numberOfRays = numOfRays;
        maxDepth = depth;
        russianRouletteLimit = RRLimit;
    }

    /// Return a Color form a Ray that hit a shape in the World
    ///
    /// The Color is the background one if there is no intersection
    /// 
    /// The emitted radiance from the material of an object is taken into account
    ///
    /// Use the Russian Roulette Algorithm if the depth of the Ray is bigger than the limit set
    override pure nothrow @safe Color call(in Ray ray)
    {
        if (ray.depth > maxDepth) return black;

        // gdc throws error: get does not accept mutable parameters (makes no sense). Ok for dmd and ldc2.
        HitRecord hitRec = world.rayIntersection(ray).get(HitRecord());
        if (hitRec.t.isNaN) return backgroundColor;

        Material hitMat = hitRec.shape.material;
        Color hitCol = hitMat.brdf.pigment.getColor(hitRec.surfacePoint);
        immutable float hitColLum = max(hitCol.r, hitCol.g, hitCol.b);
        immutable Color emittedRadiance = hitMat.emittedRadiance.getColor(hitRec.surfacePoint);

        /// Russian Roulette Algorithm
        if (ray.depth >= russianRouletteLimit)
        {
            immutable float q = max(0.05, 1.0 - hitColLum);
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
                Color newRadiance = this.call(newRay);
                cumRadiance = cumRadiance + hitCol * newRadiance;
            }
        }

        return emittedRadiance + cumRadiance * (1.0 / numberOfRays);
    }
}

///
unittest
{
    PCG pcg = new PCG();
    for (ubyte i = 0; i < 5; ++i)
    {
        float emittedRadiance = pcg.randomFloat;
        float reflectance = pcg.randomFloat * 0.9;
        Material enclosureMaterial = Material(
            new DiffuseBRDF(new UniformPigment(white * reflectance)),
            new UniformPigment(white * emittedRadiance));
        
        World world = World([new Sphere(Transformation(), enclosureMaterial)]);
        // depth = 100, RRlimit = 101
        PathTracer pathTracer = new PathTracer(world, black, pcg, 1, 100, 101);

        Ray ray = {Point(0.0, 0.0, 0.0), vecX};
        Color color = pathTracer.call(ray);
        // call
        float expected = emittedRadiance / (1.0 - reflectance);
        assert(areClose(expected, color.r));
        assert(areClose(expected, color.g));
        assert(areClose(expected, color.b));
    }
}