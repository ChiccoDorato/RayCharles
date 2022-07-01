module cameras;

import geometry : Point, Vec;
import hdrimage : Color, HDRImage;
import pcg;
import ray;
import transformations : Transformation;

// ************************* Camera *************************
/// Class representing a 3D observer
class Camera
{
    // Screen-observer distance
    float d; 
    float aspectRatio;
    Transformation transformation;  

    /// Abstract method: Shoot a rays in a given 2D Point (u, v) on the surface of the image 
    abstract pure nothrow @nogc @safe Ray fireRay(in float u, in float v) const;
}

// ******************** OrthogonalCamera ********************
/// Class representing a 3D observer with line of sight orthogonal to the surface observed
class OrthogonalCamera : Camera
{   
    /// Build an orthogonal camera - Default: unitary aspect ratio and Identity transformation applied
    pure nothrow @nogc @safe this(
        in float aspRat = 1.0, in Transformation transf = Transformation()
        )
    in (aspRat > 0.0)
    {
        aspectRatio = aspRat;
        transformation = transf;
    }

    /// Shoot a Ray in a given 2D Point (u, v) on the surface of the image
    override pure nothrow @nogc @safe Ray fireRay(in float u, in float v) const
    {
        auto r = Ray(
            Point(-1.0, (1.0 - 2 * u) * aspectRatio, 2.0 * v - 1.0),
            Vec(1.0, 0.0, 0.0)
            );
        r = transformation * r;
        r.tMin = 1.0;
        return r;
    }
}

///
unittest
{
    import hdrimage : areClose;

    auto cam = new OrthogonalCamera(2.0);
    Ray r1 = cam.fireRay(0.0, 0.0);
    Ray r2 = cam.fireRay(1.0, 0.0);
    Ray r3 = cam.fireRay(0.0, 1.0);
    Ray r4 = cam.fireRay(1.0, 1.0);

    // Verify that Rays are parallel: their cross product vanishes
    assert(areClose(0.0, (r1.dir ^ r2.dir).squaredNorm));
    assert(areClose(0.0, (r1.dir ^ r3.dir).squaredNorm));
    assert(areClose(0.0, (r1.dir ^ r4.dir).squaredNorm));

   // Verify that Rays hitting the corners have the right coordinates
    assert(r1.at(1.0).xyzIsClose(Point(0.0, 2.0, -1.0)));
    assert(r2.at(1.0).xyzIsClose(Point(0.0, -2.0, -1.0)));
    assert(r3.at(1.0).xyzIsClose(Point(0.0, 2.0, 1.0)));
    assert(r4.at(1.0).xyzIsClose(Point(0.0, -2.0, 1.0)));
}

///
unittest
{
    import geometry : vecY;
    import transformations : rotationZ, translation;

    auto cam = new OrthogonalCamera(
        1.0,
        translation(-vecY * 2.0) * rotationZ(90.0)
        );
    Ray r = cam.fireRay(0.5, 0.5);
    // fireRay
    assert(r.at(1.0).xyzIsClose(Point(0.0, -2.0, 0.0)));
}

// ************************* PerspectiveCamera *************************
/// Class representing a 3D observer with line of sight perspective
 class PerspectiveCamera : Camera 
{
    /// Build a perspective camera - Default: unitary aspect ratio and Identity transformation applied
    pure nothrow @nogc @safe this(
        in float dist = 1.0,
        in float aspRat = 1.0,
        in Transformation transf = Transformation()
        )
    in (dist > 0.0)
    in (aspRat > 0.0)
    {
        d = dist;
        aspectRatio = aspRat;
        transformation = transf;
    }

    /// Shoot a Ray in a given 2D Point (u, v) on the surface of the image
    override pure nothrow @nogc @safe Ray fireRay(in float u, in float v) const
    {
        auto r = Ray(
            Point(-d, 0.0, 0.0),
            Vec(d, (1.0 - 2.0 * u) * aspectRatio, 2.0 * v - 1.0)
            );
        r = transformation * r;
        r.tMin = 1.0;
        return r;
    }
}

///
unittest
{
    auto cam = new PerspectiveCamera(1.0, 2.0);
    Ray r1 = cam.fireRay(0.0, 0.0);
    Ray r2 = cam.fireRay(1.0, 0.0);
    Ray r3 = cam.fireRay(0.0, 1.0);
    Ray r4 = cam.fireRay(1.0, 1.0);

    // Verify if all the rays depart from the same point
    assert(r1.origin.xyzIsClose(r2.origin));
    assert(r1.origin.xyzIsClose(r3.origin));
    assert(r1.origin.xyzIsClose(r4.origin));

    // Verify if the ray hitting the corners have the right coordinates
    assert(r1.at(1.0).xyzIsClose(Point(0.0, 2.0, -1.0)));
    assert(r2.at(1.0).xyzIsClose(Point(0.0, -2.0, -1.0)));
    assert(r3.at(1.0).xyzIsClose(Point(0.0, 2.0, 1.0)));
    assert(r4.at(1.0).xyzIsClose(Point(0.0, -2.0, 1.0)));
}

///
unittest
{
    import geometry : vecY;
    import transformations : rotationZ, translation;

    auto cam = new PerspectiveCamera(
        1.0,
        1.0,
        translation(-vecY * 2.0) * rotationZ(90.0)
        );
    Ray r = cam.fireRay(0.5, 0.5);
    // fireRay
    assert(r.at(1.0).xyzIsClose(Point(0.0, -2.0, 0.0)));
}

// ************************* ImageTracer *************************
/// Class for an ImageTracer - create an image and solve the rendering equation
struct ImageTracer
{
    HDRImage image;
    Camera camera;
    int samplesPerSide;
    PCG pcg;

    /// Build an ImageTracer with the anti-aliasing to remove the Moire effect
    // when samplesPerPixel > 0 stratified sampling is applied to every pixel using the random generator
    pure nothrow @safe this(
        HDRImage img, Camera cam, in int samPerSide = 0, PCG randGen = new PCG()
        )
    {
        image = img;
        camera = cam;
        samplesPerSide = samPerSide;
        pcg = new PCG(randGen);
    }

    /// Shoot a Ray in a given 2D Point (u, v) on the surface of the image
    pure nothrow @nogc @safe Ray fireRay(
        in int col, in int row, in float uPixel = 0.5, in float vPixel = 0.5
        ) const
    in (col + uPixel >= 0 && col + uPixel <= image.width)
    in (row + vPixel >= 0 && row + vPixel <= image.height)
    {
        return camera.fireRay(
            (col + uPixel) / image.width,
            1.0 - (row + vPixel) / image.height
            );
    }

    /// Solve the rendering equation for a given pixel
    pure nothrow void coloringPixel(
        in uint col,
        in uint row,
        in Color delegate(Ray) pure nothrow solveRendering
        )
    {
        if (samplesPerSide > 0)
        {
            auto colSum = Color(0.0, 0.0, 0.0);
            for (uint pixelRow = 0; pixelRow < samplesPerSide; ++pixelRow)
            {
                for (uint pixelCol = 0; pixelCol < samplesPerSide; ++pixelCol)
                {
                    Ray r = fireRay(
                        col,
                        row,
                        (pixelCol + pcg.randomFloat) / samplesPerSide,
                        (pixelRow + pcg.randomFloat) / samplesPerSide
                        );
                    colSum = colSum + solveRendering(r);
                }
            }
            image.setPixel(
                col,
                row,
                colSum * (1.0 / (samplesPerSide * samplesPerSide))
                );
        }
        else
        {
            Ray r = fireRay(col, row);
            image.setPixel(col, row, solveRendering(r));
        }
    }

    /// Shoot a Ray in every 2D Point (u, v) on the surface of the image - Solve the rendering equation for every pixel
    pure nothrow void fireAllRays(
        in Color delegate(Ray) pure nothrow solveRendering
        )
    {
        for (uint row = 0; row < image.height; ++row)
            for (uint col = 0; col < image.width; ++col)
                coloringPixel(col, row, solveRendering);
    }
}

///
unittest
{
    auto image = new HDRImage(4, 2);
    auto camera = new PerspectiveCamera(1.0, 2.0);
    auto tracer = ImageTracer(image, camera);

    /// Test method "at" of the Tracer
    void testOrientation(in ImageTracer tracer)
    {
        immutable Ray topLeftRay = tracer.fireRay(0, 0, 0.0, 0.0);
        assert(Point(0.0, 2.0, 1.0).xyzIsClose(topLeftRay.at(1.0)));

        immutable Ray bottomRightRay = tracer.fireRay(3, 1, 1.0, 1.0);
        assert(Point(0.0, -2.0, -1.0).xyzIsClose(bottomRightRay.at(1.0)));
    }

    /// Test fireRay of the Tracer
    void testUVSubMapping(in ImageTracer tracer)
    {
        immutable Ray r1 = tracer.fireRay(0, 0, 2.5, 1.5);
        immutable Ray r2 = tracer.fireRay(2, 1, 0.5, 0.5);
        assert(r1.rayIsClose(r2));
    }

    /// Test fireAllRays of the Tracer
    void testImageCoverage(ImageTracer tracer)
    {
        tracer.fireAllRays(Ray => Color(1.0, 2.0, 3.0));
        for (uint row = 0; row < tracer.image.height; ++row)
            for (uint col = 0; col < tracer.image.width; ++col)
                assert(tracer.image.getPixel(col, row) == Color(1.0, 2.0, 3.0));
    }

    // xyzIsClose
    testOrientation(tracer);
    // fireRay
    testUVSubMapping(tracer);
    // fireAllRays
    testImageCoverage(tracer);
}