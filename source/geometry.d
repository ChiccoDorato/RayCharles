module geometry;

import hdrimage : areClose;
import pcg;
import std.array : split;
import std.conv : to;
import std.math : sqrt;

/// Convert an (x, y, z)-object into a string
mixin template toString(T)
{
    string toString()() const
    in (T.tupleof.length == 3, "toString accepts xyz types only.")
    {
        string[] typePath = to!string(typeid(T)).split(".");
        return typePath[$-1]~"(x="~to!string(x)~", y="~to!string(y)~", z="~to!string(z)~")";
    }
}

/// Verify if two (x, y, z)-objects are close by calling the function areClose
mixin template xyzIsClose(T)
{
    immutable(bool) xyzIsClose(T)(in T v) const
    in (T.tupleof.length == 3, "xyzIsClose accepts xyz types only.")
    {
        return areClose(x, v.x) && areClose(y, v.y) && areClose(z, v.z);
    }
}

/* 
mixin template sumDiff(T, R)
{
    R opBinary(string op)(in T rhs) const if (op == "+" || op == "-")
    in (T.tupleof.length == 3 && R.tupleof.length == 3, "sumDiff accepts xyz types only.")
    {
        return mixin("R(x"~op~"rhs.x, y"~op~"rhs.y, z"~op~"rhs.z)");
    }
}*/

/// Return an (x, y, z)-object with opposite coordinates (-x, -y, -z)
mixin template neg(R)
{
    R opUnary(string op)() const if (op == "-")
    in (R.tupleof.length == 3, "neg accepts xyz types only.")
    {
        return R(-x, -y, -z);
    }
}

/*mixin template mul(R)
{
    R opBinary(string op)(in float alfa) const if (op == "*")
    in (R.tupleof.length == 3, "mul accepts xyz types only.")
    {
        return R(x * alfa, y * alfa, z * alfa);
    }
}*/

/// Multiply a factor alpha by an (x, y, z)-object
mixin template rightMul(R)
{
    R opBinaryRight(string op)(in float alfa) const if (op == "*")
    in (R.tupleof.length == 3, "rightMul accepts xyz types only.")
    {
        return R(alfa * x, alfa * y, alfa * z);
    }
}

/*mixin template dot(T)
{
    float opBinary(string op)(in T rhs) const if (op == "*")
    in (T.tupleof.length == 3, "dot accepts xyz types only.")
    {
        return x * rhs.x + y * rhs.y + z * rhs.z;
    }
}*/

/*mixin template cross(T, R)
{
    R opBinary(string op)(in T rhs) const if (op == "^")
    in (T.tupleof.length == 3 && R.tupleof.length == 3, "cross accepts xyz types only.")
    {
        return mixin("R(y * rhs.z - z * rhs.y, z * rhs.x - x * rhs.z, x * rhs.y - y * rhs.x)");
    }
}*/

/// Calculate the squared norm of an (x, y, z)-object
mixin template squaredNorm(T)
{
    float squaredNorm()() const
    in (T.tupleof.length == 3, "squaredNorm accepts xyz types only.")
    {
        return x * x + y * y + z * z;
    }
}

/// Calculate the norm of an (x, y, z)-object
mixin template norm(T)
{
    float norm()() const
    in (T.tupleof.length == 3, "norm accepts xyz types only.")
    {
        return sqrt(squaredNorm());
    }
}

/// Normalize an (x, y, z)-object dividing it by its norm
mixin template normalize(R)
{
    R normalize()() const
    in (R.tupleof.length == 3, "normalize accepts xyz types only.")
    {
        return 1.0 / norm() * this;
    }
}

/// Convert an (x, y, z)-object in a different one
mixin template convert(T, R)
{
    R convert() const
    in (T.tupleof.length == 3 && R.tupleof.length == 3, "convert accepts xyz types only.")
    {
        return R(x, y, z);
    }
}

///******************** Vec ********************
/// struct for a 3D Vector
struct Vec
{
    float x, y, z;

    mixin toString!Vec;
    mixin xyzIsClose!Vec;

    /*mixin sumDiff!(Vec, Vec);*/
    /// Operations: Sum (+) and Difference (-) between two Vec
    Vec opBinary(string op)(in Vec rhs) const if (op == "+" || op == "-")
    {
        return mixin("Vec(x"~op~"rhs.x, y"~op~"rhs.y, z"~op~"rhs.z)");
    }

    /// Calculate the opposite Vec with coordinates (-x, -y, -z)
    mixin neg!Vec;

    /*mixin mul!Vec;*/

    /// Product (*) between a Vec and a floating point
    Vec opBinary(string op)(in float alfa) const if (op == "*")
    {
        return Vec(x * alfa, y * alfa, z * alfa);
    }
    
    /// Product (*) between a floating point and a Vec 
    mixin rightMul!Vec;

    /*mixin dot!Vec;*/
    /// Calculate scalar product (*) between two Vec
    float opBinary(string op)(in Vec rhs) const if (op == "*")
    {
        return x * rhs.x + y * rhs.y + z * rhs.z;
    }

    /*mixin dot!Normal;*/
    /// Scalar product (*) between two Normal
    float opBinary(string op)(in Normal rhs) const if (op == "*")
    {
        return x * rhs.x + y * rhs.y + z * rhs.z;
    }

    /*mixin cross!(Vec, Vec);*/
    /// Cross product (^) between two Vec
    Vec opBinary(string op)(in Vec rhs) const if (op == "^")
    {
        return Vec(y * rhs.z - z * rhs.y, z * rhs.x - x * rhs.z, x * rhs.y - y * rhs.x);
    }

    /*mixin cross!(Normal, Vec);*/
    /// Cross product (*) between a Normal and a Vec 
    Vec opBinary(string op)(in Normal rhs) const if (op == "^")
    {
        return Vec(y * rhs.z - z * rhs.y, z * rhs.x - x * rhs.z, x * rhs.y - y * rhs.x);
    }

    /// Calculate the squared norm of a Vec
    mixin squaredNorm!Vec;

    /// Calculate the norm of a Vec
    mixin norm!Vec;

    /// Normalize a Vec dividing it by its norm
    mixin normalize!Vec;

    /// Convert a Vec into a Normal
    mixin convert!(Vec, Normal);
}

/// Cartesian Versors in x, y and z direction
immutable(Vec) vecX = Vec(1.0, 0.0, 0.0),
    vecY = Vec(0.0, 1.0, 0.0),
    vecZ = Vec(0.0, 0.0, 1.0);

unittest
{
    Vec a = {1.0, 2.0, 3.0}, b = {4.0, 6.0, 8.0};
    // xyzIsClose
    assert(a.xyzIsClose(a));
    assert(!a.xyzIsClose(b));

    // Negative Vec
    assert((-a).xyzIsClose(Vec(-1.0, -2.0, -3.0)));
    // Sum (+) and Difference (-) between two Vec
    assert((a + b).xyzIsClose(Vec(5.0, 8.0, 11.0)));
    assert((b - a).xyzIsClose(Vec(3.0, 4.0, 5.0)));
    // Product Vec with a floating point on the right-hand side and on the left-hand side
    assert((a * 2).xyzIsClose(Vec(2.0, 4.0, 6.0)));
    assert((-4 * a).xyzIsClose(Vec(-4.0, -8.0, -12.0)));
    // Dot (*) and Cross (^) product
    assert((a * b).areClose(40.0));
    assert((a ^ b).xyzIsClose(Vec(-2.0, 4.0, -2.0)));
    assert((b ^ a).xyzIsClose(Vec(2.0, -4.0, 2.0)));
    // squaredNorm and norm
    assert(areClose(a.squaredNorm, 14.0));
    assert(areClose(a.norm * a.norm, 14.0));
}

///******************** Point ********************
/// struct for a 3D Point
struct Point
{
    float x, y, z;

    /// Convert a Point into a string
    mixin toString!Point;
    /// Verify if two Point are close calling the function areClose on every component (x, y, z)
    mixin xyzIsClose!Point;
    
    //mixin sumDiff!(Point, Vec);
    // Operations: Sum (+) and Difference (-) between two Point returning a Point
    Point opBinary(string op)(in Vec rhs) const if (op == "+" || op == "-")
    {
        return mixin("Point(x"~op~"rhs.x, y"~op~"rhs.y, z"~op~"rhs.z)");
    }
    // Difference (-) between two Point returning a Vec
    Vec opBinary(string op)(in Point rhs) const if (op == "-")
    {
        return Vec(x - rhs.x, y - rhs.y, z - rhs.z);
    }

    /// Calculate the opposite Point with coordinates (-x, -y, -z)
    mixin neg!Point;

    //mixin mul!Point;
    /// Product (*) between a Point and a floating point
    Point opBinary(string op)(in float alfa) const if (op == "*")
    {
        return Point(x * alfa, y * alfa, z * alfa);
    }
    /// Product (*) between a floating point and a Vec on the right-hand side
    mixin rightMul!Point;
    /// Convert a Point into a Vec
    mixin convert!(Point, Vec);
}

///
unittest
{
    Point p1 = {1.0, 2.0, 3.0}, p2 = {4.0, 6.0, 8.0};
    // xyzIsClose
    assert(p1.xyzIsClose(p1));
    assert(!p1.xyzIsClose(p2));
    // Operations: Product (*) between a Point and a floating point (left/right-hand side)
    assert((-p1 * 2).xyzIsClose(Point(-2.0, -4.0, -6.0)));
    assert((0.5 * p2).xyzIsClose(Point(2.0, 3.0, 4.0)));

    Vec v = {4.0, 6.0, 8.0};
    // Operations: Sum (+) and Difference (-) between a Point and a Vec, Difference between two Point
    assert((p1 + v).xyzIsClose(Point(5.0, 8.0, 11.0)));
    assert((p1 - v).xyzIsClose(Point(-3.0, -4.0, -5.0)));
    assert((p2 - p1).xyzIsClose(Vec(3.0, 4.0, 5.0)));
}

///******************** Normal ********************
/// struct for a 3D Normal
struct Normal
{
    float x, y, z;

    /// Convert a Normal into a string
    mixin toString!Normal;
    /// Verify if two Normal are close calling the function areClose on every component (x, y, z)
    mixin xyzIsClose!Normal;

    /// Calculate the opposite Normal with coordinates (-x, -y, -z)
    mixin neg!Normal;

    //mixin mul!Normal;
    /// Product (*) between a Normal and a floating point
    Normal opBinary(string op)(in float alfa) const if (op == "*")
    {
        return Normal(x * alfa, y * alfa, z * alfa);
    }

    /// Product (*) between a floating point and a Normal on the right-hand side
    mixin rightMul!Normal;

    //mixin dot!Vec;
    /// Scalar product (*) between a Normal and a Vec
    float opBinary(string op)(in Vec rhs) const if (op == "*")
    {
        return x * rhs.x + y * rhs.y + z * rhs.z;
    }

    //mixin cross!(Normal, Vec);
    /// Cross product (^) between two Normal returning a Vec
    Vec opBinary(string op)(in Normal rhs) const if (op == "^")
    {
        return Vec(y * rhs.z - z * rhs.y, z * rhs.x - x * rhs.z, x * rhs.y - y * rhs.x);
    }

    /// Calculate the squared norm of a Normal
    mixin squaredNorm!Normal;
    /// Calculate the norm of a Normal
    mixin norm!Normal;
    /// Normalize a Normal dividing it by its norm
    mixin normalize!Normal;

    /// Convert a Normal into a Vec
    mixin convert!(Normal, Vec);
}

///******************** Vec2d ********************
/// struct for a 2D Vec
struct Vec2d
{
    float u, v;

    /// Verify if two Vec2d are close calling the function areClose on every component (u, v)
    immutable(bool) uvIsClose(in Vec2d v2d) const
    {
        return areClose(u, v2d.u) && areClose(v, v2d.v);
    }
}

/// Return an array of Vec generatig a 3D Orthonormal Base
Vec[3] createONBFromZ(in Normal n)
in (areClose(n.squaredNorm, 1.0, 8.0 * 1e-5))
{
    float sign;
    n.z > 0.0 ? (sign = 1.0) : (sign = -1.0); 
    immutable float a = -1.0 / (sign + n.z);
    immutable float b = n.x * n.y * a;

    immutable Vec e1 = Vec(1.0 + sign * n.x * n.x * a, sign * b, -sign * n.x);
    immutable Vec e2 = Vec(b, sign + n.y * n.y * a, -n.y);

    return [e1, e2, Vec(n.x, n.y, n.z)];
}

unittest
{
    PCG pcg = new PCG();

    Vec[3] base;
    for (int i = 0; i < 10_000; ++i)
    {
        Normal n = Normal(pcg.randomFloat, pcg.randomFloat, pcg.randomFloat).normalize;
        base = createONBFromZ(n);

        // Verify that the z axis is aligned with the normal
        assert(base[2].xyzIsClose(n));

        // Verify the correct normalization
        assert(areClose(base[0].squaredNorm, 1));
        assert(areClose(base[1].squaredNorm, 1));
        assert(areClose(base[2].squaredNorm, 1));

        // Verify that the base is orthogonal
        assert(areClose(base[0]*base[1], 0));
        assert(areClose(base[1]*base[2], 0));
        assert(areClose(base[2]*base[0], 0));

        // Verify that the cyclic cross product of two Vec of the base give the third 
        assert((base[0]^base[1]).xyzIsClose(base[2]));
        assert((base[1]^base[2]).xyzIsClose(base[0]));
        assert((base[2]^base[0]).xyzIsClose(base[1]));
    }
}