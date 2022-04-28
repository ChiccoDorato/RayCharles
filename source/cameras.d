module cameras;

import geometry : Point, Vec, vecX, vecY;
import hdrimage : areClose, Color, HDRImage;
import ray : Ray;
import transformations : rotationZ, Transformation, translation;

class Camera
{   
    float d; // Screen-observer distance
    float aspectRatio;
    Transformation transformation;  
     
    abstract Ray fireRay(float u, float v);
}

class OrthogonalCamera : Camera 
{
    this(float aspRat = 1.0, Transformation transf = Transformation())
    in (aspRat > 0)
    {
        aspectRatio = aspRat;
        transformation = transf;
    }

    override Ray fireRay(float u, float v)
    {
        Ray r = {Point(-1.0, (1.0 - 2 * u) * aspectRatio, 2 * v - 1), vecX};
        r = transformation * r;
        r.tMin = 1.0;
        return r;
    }
}

unittest
{
    OrthogonalCamera cam = new OrthogonalCamera(2.0);

    Ray r1 = cam.fireRay(0.0, 0.0);
    Ray r2 = cam.fireRay(1.0, 0.0);
    Ray r3 = cam.fireRay(0.0, 1.0);
    Ray r4 = cam.fireRay(1.0, 1.0);

    // Rays are parallel if their cross product vanishes
    assert(areClose(0.0, (r1.dir ^ r2.dir).squaredNorm));
    assert(areClose(0.0, (r1.dir ^ r3.dir).squaredNorm));
    assert(areClose(0.0, (r1.dir ^ r4.dir).squaredNorm));

   // Rays hitting the corners have the right coordinates
    assert(r1.at(1.0).xyzIsClose(Point(0.0, 2.0, -1.0)));
    assert(r2.at(1.0).xyzIsClose(Point(0.0, -2.0, -1.0)));
    assert(r3.at(1.0).xyzIsClose(Point(0.0, 2.0, 1.0)));
    assert(r4.at(1.0).xyzIsClose(Point(0.0, -2.0, 1.0)));
}

unittest
{
    Camera cam = new OrthogonalCamera(1.0, translation(-vecY * 2.0) * rotationZ(90));
    Ray r = cam.fireRay(0.5, 0.5);
    assert(r.at(1.0).xyzIsClose(Point(0.0, -2.0, 0.0)));
}

 class PerspectiveCamera : Camera 
{
    this(float dist = 1.0, float aspRat = 1.0, Transformation transf = Transformation())
    in (dist > 0 && aspRat > 0)
    {
        d = dist;
        aspectRatio = aspRat;
        transformation = transf;
    }

    override Ray fireRay(float u, float v)
    {
        Ray r = {Point(-d, 0.0, 0.0), Vec(d, (1.0 - 2 * u) * aspectRatio, 2 * v - 1)};
        r = transformation * r;
        r.tMin = 1.0;
        return r;
    }
}

unittest
{
    Camera cam = new PerspectiveCamera(1.0, 2.0);

    Ray r1 = cam.fireRay(0.0, 0.0);
    Ray r2 = cam.fireRay(1.0, 0.0);
    Ray r3 = cam.fireRay(0.0, 1.0);
    Ray r4 = cam.fireRay(1.0, 1.0);

    // All the rays depart from the same point
    assert(r1.origin.xyzIsClose(r2.origin));
    assert(r1.origin.xyzIsClose(r3.origin));
    assert(r1.origin.xyzIsClose(r4.origin));

    // The ray hitting the corners have the right coordinates
    assert(r1.at(1.0).xyzIsClose(Point(0.0, 2.0, -1.0)));
    assert(r2.at(1.0).xyzIsClose(Point(0.0, -2.0, -1.0)));
    assert(r3.at(1.0).xyzIsClose(Point(0.0, 2.0, 1.0)));
    assert(r4.at(1.0).xyzIsClose(Point(0.0, -2.0, 1.0)));
}

unittest
{
    Camera cam = new PerspectiveCamera(1.0, 1.0, translation(-vecY * 2.0) * rotationZ(90));
    Ray r = cam.fireRay(0.5, 0.5);
    assert(r.at(1.0).xyzIsClose(Point(0.0, -2.0, 0.0)));
}

class ImageTracer
{
    HDRImage image;
    Camera camera;

    this(HDRImage img, Camera cam)
    {
        image = img;
        camera = cam;
    }

    Ray fireRay(int col, int row, float uPixel = 0.5, float vPixel = 0.5)
    in (col + uPixel >= 0 && col + uPixel <= image.width)
    in (row + vPixel >= 0 && row + vPixel <= image.height)
    {
        float u = (col + uPixel) / image.width;
        float v = 1 - (row + vPixel) / image.height;
        return camera.fireRay(u, v);
    }

    void fireAllRays(Color function(Ray) solveRendering)
    {
        Ray ray;
        Color color;

        for (uint row = 0; row < image.height; ++row){
            for (uint col = 0; col < image.width; ++col){
                ray = fireRay(col, row);
                color = solveRendering(ray);
                image.setPixel(col, row, color);
            }
        }
    }
}

void testOrientation(ImageTracer tracer)
{
    Ray topLeftRay = tracer.fireRay(0, 0, 0, 0);
    assert(Point(0, 2, 1).xyzIsClose(topLeftRay.at(1)));

    Ray bottomRightRay = tracer.fireRay(3, 1, 1, 1);
    assert(Point(0, -2, -1).xyzIsClose(bottomRightRay.at(1)));
}

void testUVSubMapping(ImageTracer tracer)
{
    Ray r1 = tracer.fireRay(0, 0, 2.5, 1.5);
    Ray r2 = tracer.fireRay(2, 1, 0.5, 0.5);
    assert(r1.rayIsClose(r2));
}

void testImageCoverage(HDRImage image, ImageTracer tracer)
{
    tracer.fireAllRays(Ray => Color(1.0, 2.0, 3.0));
    for (uint row = 0; row < image.height; ++row)
        for (uint col = 0; col < image.width; ++col)
            assert(image.getPixel(col, row) == Color(1.0, 2.0, 3.0));
}

unittest
{
    HDRImage image = new HDRImage(4, 2);
    Camera camera = new PerspectiveCamera(1.0, 2.0);
    ImageTracer tracer = new ImageTracer(image, camera);

    testOrientation(tracer);
    testUVSubMapping(tracer);
    testImageCoverage(image, tracer);
}