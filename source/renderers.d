module renderers;

import hdrimage : black, Color, white;
import materials : Material;
import pcg;
import ray;
import shapes : HitRecord, World;
import std.algorithm : max;
import std.math : isNaN;
import std.typecons : Nullable;

// ************************* Renderer *************************
/// Class representing a Renderer - Members: World, backgroundColor (Color)
class Renderer
{
    World world;
    Color backgroundColor;

    /// Build a Renderer - Parameter: World, Color
    pure nothrow @safe this(World w, in Color bgCol = black)
    {
        world = w;
        backgroundColor = bgCol;
    }

    /// Return a Color form a Ray that hit a shape in the World
    abstract pure nothrow @nogc @safe Color call(in Ray r);
}

// ************************* OnOffRenderer *************************
/// Class representing a OnOffRenderer
class OnOffRenderer : Renderer
{
    Color color = white;

    /// Build an OnOffRenderer - Parameter: World, 2 Colors (backgroundColor & color)
    ///
    /// Use super(World, backgroundColor)
    pure nothrow @safe this(
        World w, in Color bgCol = black, in Color col = white
        )
    {
        super(w, bgCol);
        color = col;
    }

    /// Return a Color form a Ray that hit a shape in the World
    ///
    /// The Color is the background one if there is no intersection
    override pure nothrow @nogc @safe Color call(in Ray r)
    {
        return world.rayIntersection(r).isNull ? backgroundColor : color;
    }
}

///
unittest
{
    import cameras : ImageTracer, OrthogonalCamera;
    import geometry : Vec;
    import hdrimage : HDRImage;
    import shapes : Sphere;
    import transformations : scaling, translation;

    auto transf = translation(Vec(2.0, 0.0, 0.0)) * scaling(Vec(0.2, 0.2, 0.2));
    auto sphere = new Sphere(transf);
    auto world = World([sphere]);

    auto image = new HDRImage(3, 3);
    auto camera = new OrthogonalCamera();
    auto tracer = ImageTracer(image, camera);

    auto renderer = new OnOffRenderer(world);
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
    /// Build a FlatRenderer - Parameter: World, backgroundColor (Color)
    ///
    /// Use super(World, backgroundColor)
    pure nothrow @safe this(World w, in Color bgCol = black)
    {
        super(w, bgCol);
    }

    /// Return a Color form a Ray that hit a shape in the World
    ///
    /// The Color is the background one if there is no intersection
    /// 
    /// The emitted radiance from the material of an object is taken into account
    override pure nothrow @nogc @safe Color call(in Ray r)
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
    import cameras : ImageTracer, OrthogonalCamera;
    import geometry : Vec, vecX;
    import hdrimage : HDRImage;
    import materials : DiffuseBRDF, Material, UniformPigment;
    import shapes : Sphere;
    import transformations : scaling, translation;

    auto transf = translation(2.0 * vecX) * scaling(Vec(0.2, 0.2, 0.2));
    auto spherePigment = new UniformPigment(Color(1.0, 2.0, 3.0));
    auto sphereMaterial = Material(new DiffuseBRDF(spherePigment));
    auto sphere = new Sphere(transf, sphereMaterial);
    auto world = World([sphere]);

    auto image = new HDRImage(3, 3);
    auto camera = new OrthogonalCamera();
    auto tracer = ImageTracer(image, camera);

    auto renderer = new FlatRenderer(world);
    tracer.fireAllRays((Ray r) => renderer.call(r));
    // call
    assert(image.getPixel(0, 0).colorIsClose(black));
    assert(image.getPixel(1, 0).colorIsClose(black));
    assert(image.getPixel(2, 0).colorIsClose(black));

    assert(image.getPixel(0, 1).colorIsClose(black));
    assert(image.getPixel(1, 1).colorIsClose(Color(1.0, 2.0, 3.0)));
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
    pure nothrow @safe this(
        World w,
        in Color bgCol = black,
        PCG randomGenerator = new PCG(),
        in int numOfRays = 10,
        in int depth = 2,
        in int RRLimit = 3
        )
    {
        super(w, bgCol);
        pcg = randomGenerator; // pcg = new PCG(randomGenerator);
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
    override pure nothrow @nogc @safe Color call(in Ray ray)
    {
        if (ray.depth > maxDepth) return black;

        // gdc throws error: get does not accept mutable parameters (makes no sense). Ok for dmd and ldc2.
        HitRecord hitRec = world.rayIntersection(ray).get(HitRecord());
        if (hitRec.t.isNaN) return backgroundColor;

        auto hitMat = hitRec.shape.material;
        Color hitCol = hitMat.brdf.pigment.getColor(hitRec.surfacePoint);
        immutable float hitColLum = max(hitCol.r, hitCol.g, hitCol.b);
        immutable Color emittedRadiance = hitMat.emittedRadiance.getColor(
            hitRec.surfacePoint
            );

        /// Russian Roulette Algorithm
        if (ray.depth >= russianRouletteLimit)
        {
            immutable float q = max(0.05, 1.0 - hitColLum);
            if (pcg.randomFloat > q) hitCol *= (1.0 / (1.0 - q));
            else return emittedRadiance;
        }

        Color cumRadiance;
        if (hitColLum > 0.0)
        {
            for (int i = 0; i < numberOfRays; ++i)
            {
                Ray newRay = hitMat.brdf.scatterRay(
                    pcg,
                    hitRec.ray.dir,
                    hitRec.worldPoint,
                    hitRec.normal,
                    ray.depth + 1
                    );
                Color newRadiance = this.call(newRay);
                cumRadiance += hitCol * newRadiance;
            }
        }

        return emittedRadiance + cumRadiance * (1.0 / numberOfRays);
    }
}

///
unittest
{
    import geometry : Point, vecX;
    import hdrimage : areClose;
    import materials : DiffuseBRDF;
    import materials : Material, UniformPigment;
    import shapes : Sphere;
    import transformations : Transformation;

    auto pcg = new PCG();
    for (ubyte i = 0; i < 5; ++i)
    {
        immutable float emittedRadiance = pcg.randomFloat;
        immutable float reflectance = pcg.randomFloat * 0.9;
        auto enclosureMaterial = Material(
            new DiffuseBRDF(new UniformPigment(white * reflectance)),
            new UniformPigment(white * emittedRadiance)
            );
        
        auto world = World([new Sphere(Transformation(), enclosureMaterial)]);
        // depth = 100, RRlimit = 101
        auto pathTracer = new PathTracer(world, black, pcg, 1, 100, 101);

        auto ray = Ray(Point(0.0, 0.0, 0.0), vecX);
        Color color = pathTracer.call(ray);
        // call
        immutable float expected = emittedRadiance / (1.0 - reflectance);
        assert(areClose(expected, color.r));
        assert(areClose(expected, color.g));
        assert(areClose(expected, color.b));
    }
}