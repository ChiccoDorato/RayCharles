import geometry;
import hdrimage;
import std.math;
import std.stdio;


struct Ray
{
    Point origin;
    Vec dir;
    float tMin = 1e-5, tMax = float.infinity; 
    int depth = 0;

    Point at(float t)
    {
        return origin + t * dir;
    }

    bool rayIsClose(Ray rhs)
    {
        return origin.xyzIsClose(rhs.origin) && dir.xyzIsClose(rhs.dir);
    }
}

unittest
{
    Ray r1 = {Point(1.0, 2.0, 3.0), Vec(5.0, 4.0, -1.0)};
    Ray r2 = {Point(1.0, 2.0, 3.0), Vec(5.0, 4.0, -1.0)};
    Ray r3 = {Point(5.0, 1.0, 4.0), Vec(3.0, 9.0, 4.0)};

    assert(r1.rayIsClose(r2));
    assert(!r1.rayIsClose(r3));

    Ray ray4 = Ray(Point(1.0, 2.0, 4.0), Vec(4.0, 2.0, 1.0));
    assert(ray4.at(0.0).xyzIsClose(ray4.origin));
    assert(ray4.at(1.0).xyzIsClose(Point(5.0, 4.0, 5.0)));
    assert(ray4.at(2.0).xyzIsClose(Point(9.0, 6.0, 6.0)));
}

unittest
{
    Ray ray5 = Ray(Point(1.0,2.0,3.0),Vec(6.0,5.0,4.0));
    Transformation tra = translation(Vec(10.0, 11.0, 12.0)) * rotationX(90.0);
    Ray transformed = tra * ray5;

    assert(transformed.origin.xyzIsClose(Point(11.0, 8.0, 14.0)));
    assert(transformed.dir.xyzIsClose(Vec(6.0, -4.0, 5.0)));
}

// It works also using "interface Camera" removing the "abstract"
class Camera
{   
    float d;    // Screen-Observer distance
    float aspectRatio;
    Transformation transformation;  
     
    abstract Ray fireRay(float u, float v);
}

class OrthogonalCamera : Camera 
{
    this(float aspRat = 1.0, Transformation transf = Transformation(id4,id4))
    {
        aspectRatio = aspRat;
        transformation = transf;
    }

    override Ray fireRay(float u, float v)
    {
        if (d == 0) writeln("USAGE: distance d from the screen cannot be zero in OrthogonalCamera.");
        
        Ray r = Ray(Point(-1.0, (1.0 - 2 * u) * aspectRatio, 2 * v - 1), vecX);
        r.tMin = 1.0;
        return transformation * r;
    }
}

unittest
{
    OrthogonalCamera cam = new OrthogonalCamera(2.0);

    Ray ray6 = cam.fireRay(0.0, 0.0);
    Ray ray7 = cam.fireRay(1.0, 0.0);
    Ray ray8 = cam.fireRay(0.0, 1.0);
    Ray ray9 = cam.fireRay(1.0, 1.0);

    // Rays are parallel by verifying that cross-products vanish
    assert(areClose(0.0, (ray6.dir ^ (ray7.dir)).squaredNorm()));
    assert(areClose(0.0, (ray6.dir ^ (ray8.dir)).squaredNorm()));
    assert(areClose(0.0, (ray6.dir ^ (ray9.dir)).squaredNorm()));

   // Rays hitting the corners have the right coordinates
    assert(ray6.at(1.0).xyzIsClose(Point(0.0, 2.0, -1.0)));
    assert(ray7.at(1.0).xyzIsClose(Point(0.0, -2.0, -1.0)));
    assert(ray8.at(1.0).xyzIsClose(Point(0.0, 2.0, 1.0)));
    assert(ray9.at(1.0).xyzIsClose(Point(0.0, -2.0, 1.0)));
}

unittest
{
    Camera cam = new OrthogonalCamera(1.0, translation(-vecY * 2.0) * rotationZ(90));

    Ray ray10 = cam.fireRay(0.5, 0.5);
    assert(ray10.at(1.0).xyzIsClose(Point(0.0, -2.0, 0.0)));
}

 class PerspectiveCamera : Camera 
{
    this(float dist = 1.0, float aspRat = 1.0, Transformation transf = Transformation(id4,id4))
    {
        d = dist;
        aspectRatio = aspRat;
        transformation = transf;
    }

    override Ray fireRay(float u, float v)
    {
        if (d == 0) writeln("USAGE: distance d from the screen cannot be zero in PerspectiveCamera.");
        
        Ray r = Ray(Point(-d,0.0,0.0), Vec(d, (1.0 - 2 * u) * aspectRatio, 2 * v - 1));
        r.tMin = 1.0;
        return transformation * r;
    }
}

unittest
{
    Camera cam = new PerspectiveCamera(1.0, 2.0);

    Ray ray11 = cam.fireRay(0.0, 0.0);
    Ray ray12 = cam.fireRay(1.0, 0.0);
    Ray ray13 = cam.fireRay(0.0, 1.0);
    Ray ray14 = cam.fireRay(1.0, 1.0);

    // All the rays depart from the same point
    assert(ray11.origin.xyzIsClose(ray12.origin));
    assert(ray11.origin.xyzIsClose(ray13.origin));
    assert(ray11.origin.xyzIsClose(ray14.origin));

    // The ray hitting the corners have the right coordinates
    assert(ray11.at(1.0).xyzIsClose(Point(0.0, 2.0, -1.0)));
    assert(ray12.at(1.0).xyzIsClose(Point(0.0, -2.0, -1.0)));
    assert(ray13.at(1.0).xyzIsClose(Point(0.0, 2.0, 1.0)));
    assert(ray14.at(1.0).xyzIsClose(Point(0.0, -2.0, 1.0)));
}

class ImageTracer
{
    HDRImage image = new HDRImage(0,0);
    Camera camera;

    this(HDRImage img, Camera cam)
    {
        image = img;
        camera = cam;
    }

    Ray fireRay(int col, int row, float uPixel = 0.5, float vPixel = 0.5)
    {
        // For now, there is an error in this formula
        float u = (col + uPixel) / (image.width - 1);
        float v = (row + vPixel) / (image.height - 1);
        return camera.fireRay(u, v);
    }

/*     // This func should be passed to fireAllRays...
    Color func(Ray r){
        return Color(0,0,0); // All black(?)
    }

    void fireAllRays(){
        Ray ray;
        Color color;
        for(uint row = 0; row < image.height-1; row++){
            for(uint col=0; col < image.width-1; col++){
                ray = fireRay(col, row);
                color = func(ray);
                image.setPixel(col, row, color);
            }
        }
    } */
}

unittest
{
    HDRImage image = new HDRImage(4,2);
    Camera camera = new PerspectiveCamera(1,2);
    ImageTracer tracer = new ImageTracer(image, camera);

    Ray ray15 = tracer.fireRay(0, 0, 2.5, 1.5);
    Ray ray16 = tracer.fireRay(2, 1, 0.5, 0.5);
    assert(ray15.rayIsClose(ray16));

/*  tracer.fireAllRays(lambda ray: Color(1.0, 2.0, 3.0))
    for row in range(image.height):
        for col in range(image.width):
            assert image.get_pixel(col, row) == Color(1.0, 2.0, 3.0 */
}