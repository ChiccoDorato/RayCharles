module geometry;

import hdrimage : areClose;
import pcg;
import std.format : FormatSpec, formatValue;
import std.math : sqrt;
import std.meta : AliasSeq;
import std.range : isOutputRange, put;
import std.traits : Fields, hasMember;

/// Verify if the type given has three float components (x, y, z)
pure nothrow @nogc @safe bool isXYZ(T)()
{
    return is(
        Fields!T == AliasSeq!(float, float, float)) &&
        hasMember!(T, "x") && hasMember!(T, "y") && hasMember!(T, "z"
        ) ?
        true : false;
}

/// Convert an (x, y, z)-object into a string
mixin template toString()
{
    static assert(isXYZ!(typeof(this)), "toString defined in non-xyz type");
    @safe void toString(W)(ref W w, scope const ref FormatSpec!char fmt) const
    if (isOutputRange!(W, char))
    {
		put(w, "(");
        formatValue(w, x, fmt);
        put(w, ", ");
        formatValue(w, y, fmt);
		put(w, ", ");
        formatValue(w, z, fmt);
        put(w, ")");
    }
}

/// Verify if two (x, y, z)-objects are close by calling the function areClose
mixin template xyzIsClose()
{
    static assert(isXYZ!(typeof(this)), "xyzIsClose defined in non-xyz type");
    pure nothrow @nogc @safe bool xyzIsClose(in typeof(this) v) const
    {
        return areClose(x, v.x) && areClose(y, v.y) && areClose(z, v.z);
    }
}

/* 
mixin template sumDiff(T, R)
{
    static assert(
        isXYZ!(typeof(this)) && isXYZ!T && isXYZ!R,
        "sumDiff defined with non-xyz type"
        );
    pure nothrow @nogc @safe R opBinary(string op)(in T rhs) const
    if (op == "+" || op == "-")
    {
        return mixin("R(x" ~ op ~ "rhs.x, y" ~ op ~ "rhs.y, z" ~ op ~ "rhs.z)");
    }
}*/

/// Return an (x, y, z)-object with opposite coordinates (-x, -y, -z)
mixin template neg()
{
    static assert(isXYZ!(typeof(this)), "neg defined in non-xyz type");
    pure nothrow @nogc @safe typeof(this) opUnary(string op)() const
    if (op == "-")
    {
        return typeof(this)(-x, -y, -z);
    }
}

/*mixin template mul()
{
    static assert(isXYZ!(typeof(this)), "mul defined in non-xyz type");
    pure nothrow @nogc @safe typeof(this) opBinary(string op)(in float alfa) const
    if (op == "*")
    {
        return typeof(this)(x * alfa, y * alfa, z * alfa);
    }
}*/

/// Multiply a factor alpha by an (x, y, z)-object
mixin template rightMul()
{
    static assert(isXYZ!(typeof(this)), "rightMul defined in non-xyz type");
    pure nothrow @nogc @safe typeof(this) opBinaryRight(string op)(in float alfa) const
    if (op == "*")
    {
        return typeof(this)(alfa * x, alfa * y, alfa * z);
    }
}

/*mixin template dot(T)
{
    static assert(
        isXYZ(typeof(this)) && isXYZ!T,
        "dot defined with non-xyz type"
        );
    pure nothrow @nogc @safe float opBinary(string op)(in T rhs) const
    if (op == "*")
    {
        return x * rhs.x + y * rhs.y + z * rhs.z;
    }
}*/

/*mixin template cross(T, R)
{
    static assert(
        isXYZ!(typeof(this)) && isXYZ!T && isXYZ!R,
        "cross defined with non-xyz type"
        );
    pure nothrow @nogc @safe R opBinary(string op)(in T rhs) const
    if (op == "^")
    {
        return mixin(
            "R(y * rhs.z - z * rhs.y,
            z * rhs.x - x * rhs.z,
            x * rhs.y - y * rhs.x)"
            );
    }
}*/

/// Calculate the squared norm of an (x, y, z)-object
mixin template squaredNorm()
{
    static assert(isXYZ!(typeof(this)), "squaredNorm defined in non-xyz type");
    pure nothrow @nogc @safe float squaredNorm() const
    {
        return x * x + y * y + z * z;
    }
}

/// Calculate the norm of an (x, y, z)-object
mixin template norm()
{
    static assert(isXYZ!(typeof(this)), "norm defined in non-xyz type");
    pure nothrow @nogc @safe float norm() const
    {
        return sqrt(squaredNorm);
    }
}

/// Normalize an (x, y, z)-object dividing it by its norm
mixin template normalize()
{
    static assert(isXYZ!(typeof(this)), "normalize defined in non-xyz type");
    pure nothrow @nogc @safe typeof(this) normalize() const
    {
        return (areClose(x, 0.0) && areClose(y, 0.0) && areClose(z, 0.0)) ?
            this : 1.0 / norm * this;
    }
}

/// Convert an (x, y, z)-object in a different one
mixin template convert(R)
{
    static assert(
        isXYZ!(typeof(this)) && isXYZ!R,
        "convert defined in non-xyz type"
        );
    pure nothrow @nogc @safe R convert() const
    {
        return R(x, y, z);
    }
}

// ************************* Vec *************************
/// struct for a 3D Vector
struct Vec
{
    float x, y, z;

    mixin toString;
    mixin xyzIsClose;

    /*mixin sumDiff!(Vec, Vec);*/
    /// Operations: Sum (+) and Difference (-) between two Vec
    pure nothrow @nogc @safe Vec opBinary(string op)(in Vec rhs) const
    if (op == "+" || op == "-")
    {
        return mixin(
            "Vec(x" ~ op ~ "rhs.x, y" ~ op ~ "rhs.y, z" ~ op ~ "rhs.z)"
            );
    }

    /// Calculate the opposite Vec with coordinates (-x, -y, -z)
    mixin neg;

    /*mixin mul;*/

    /// Product (*) between a Vec and a floating point
    pure nothrow @nogc @safe Vec opBinary(string op)(in float alfa) const
    if (op == "*")
    {
        return Vec(x * alfa, y * alfa, z * alfa);
    }
    
    /// Product (*) between a floating point and a Vec 
    mixin rightMul;

    /*mixin dot!Vec;*/
    /// Calculate scalar product (*) between two Vec
    pure nothrow @nogc @safe float opBinary(string op)(in Vec rhs) const
    if (op == "*")
    {
        return x * rhs.x + y * rhs.y + z * rhs.z;
    }

    /*mixin dot!Normal;*/
    /// Scalar product (*) between two Normal
    pure nothrow @nogc @safe float opBinary(string op)(in Normal rhs) const
    if (op == "*")
    {
        return x * rhs.x + y * rhs.y + z * rhs.z;
    }

    /*mixin cross!(Vec, Vec);*/
    /// Cross product (^) between two Vec
    pure nothrow @nogc @safe Vec opBinary(string op)(in Vec rhs) const
    if (op == "^")
    {
        return Vec(
            y * rhs.z - z * rhs.y,
            z * rhs.x - x * rhs.z,
            x * rhs.y - y * rhs.x
            );
    }

    /*mixin cross!(Normal, Vec);*/
    /// Cross product (*) between a Normal and a Vec 
    pure nothrow @nogc @safe Vec opBinary(string op)(in Normal rhs) const
    if (op == "^")
    {
        return Vec(
            y * rhs.z - z * rhs.y,
            z * rhs.x - x * rhs.z,
            x * rhs.y - y * rhs.x
            );
    }

    /// Calculate the squared norm of a Vec
    mixin squaredNorm;

    /// Calculate the norm of a Vec
    mixin norm;

    /// Normalize a Vec dividing it by its norm
    mixin normalize;

    /// Convert a Vec into a Normal
    mixin convert!Normal;
    alias toNormal = Vec.convert;
}

/// Cartesian Versors in x, y and z direction
immutable vecX = Vec(1.0, 0.0, 0.0), vecY = Vec(0.0, 1.0, 0.0),  vecZ = Vec(0.0, 0.0, 1.0);

///
unittest
{
    auto a = Vec(1.0, 2.0, 3.0), b = Vec(4.0, 6.0, 8.0);
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

// ************************* Point *************************
/// Struct for a 3D Point (x, y, z)
struct Point
{
    float x, y, z;

    /// Convert a Point into a string
    mixin toString;
    /// Verify if two Point are close calling the function areClose on every component (x, y, z)
    mixin xyzIsClose;
    
    //mixin sumDiff!(Vec, Point);
    // Operations: Sum (+) and Difference (-) between a Point and a Vec returning a Point
    pure nothrow @nogc @safe Point opBinary(string op)(in Vec rhs) const
    if (op == "+" || op == "-")
    {
        return mixin(
            "Point(x" ~ op ~ "rhs.x, y" ~ op ~ "rhs.y, z" ~ op ~ "rhs.z)"
            );
    }
    // Difference (-) between two Point returning a Vec
    pure nothrow @nogc @safe Vec opBinary(string op)(in Point rhs) const
    if (op == "-")
    {
        return Vec(x - rhs.x, y - rhs.y, z - rhs.z);
    }

    /// Calculate the opposite Point with coordinates (-x, -y, -z)
    mixin neg;

    //mixin mul;
    /// Product (*) between a Point and a floating point
    pure nothrow @nogc @safe Point opBinary(string op)(in float alfa) const
    if (op == "*")
    {
        return Point(x * alfa, y * alfa, z * alfa);
    }
    /// Product (*) between a floating point and a Vec on the right-hand side
    mixin rightMul;

    /// Convert a Point into a Vec
    mixin convert!Vec;
    alias toVec = Point.convert;
}

///
unittest
{
    auto p1 = Point(1.0, 2.0, 3.0), p2 = Point(4.0, 6.0, 8.0);
    // xyzIsClose
    assert(p1.xyzIsClose(p1));
    assert(!p1.xyzIsClose(p2));
    // Operations: Product (*) between a Point and a floating point (left/right-hand side)
    assert((-p1 * 2).xyzIsClose(Point(-2.0, -4.0, -6.0)));
    assert((0.5 * p2).xyzIsClose(Point(2.0, 3.0, 4.0)));

    auto v = Vec(4.0, 6.0, 8.0);
    // Operations: Sum (+) and Difference (-) between a Point and a Vec, Difference between two Point
    assert((p1 + v).xyzIsClose(Point(5.0, 8.0, 11.0)));
    assert((p1 - v).xyzIsClose(Point(-3.0, -4.0, -5.0)));
    assert((p2 - p1).xyzIsClose(Vec(3.0, 4.0, 5.0)));
}

// ************************* Normal *************************
/// struct for a 3D Normal
struct Normal
{
    float x, y, z;

    /// Convert a Normal into a string
    mixin toString;
    /// Verify if two Normal are close calling the function areClose on every component (x, y, z)
    mixin xyzIsClose;

    /// Calculate the opposite Normal with coordinates (-x, -y, -z)
    mixin neg;

    //mixin mul;
    /// Product (*) between a Normal and a floating point
    pure nothrow @nogc @safe Normal opBinary(string op)(in float alfa) const
    if (op == "*")
    {
        return Normal(x * alfa, y * alfa, z * alfa);
    }

    /// Product (*) between a floating point and a Normal on the right-hand side
    mixin rightMul;

    //mixin dot!Vec;
    /// Scalar product (*) between a Normal and a Vec
    pure nothrow @nogc @safe float opBinary(string op)(in Vec rhs) const
    if (op == "*")
    {
        return x * rhs.x + y * rhs.y + z * rhs.z;
    }

    //mixin cross!(Normal, Vec);
    /// Cross product (^) between two Normal returning a Vec
    pure nothrow @nogc @safe Vec opBinary(string op)(in Normal rhs) const
    if (op == "^")
    {
        return Vec(y * rhs.z - z * rhs.y, z * rhs.x - x * rhs.z, x * rhs.y - y * rhs.x);
    }

    /// Calculate the squared norm of a Normal
    mixin squaredNorm;
    /// Calculate the norm of a Normal
    mixin norm;
    /// Normalize a Normal dividing it by its norm
    mixin normalize;

    /// Convert a Normal into a Vec
    mixin convert!Vec;
    alias toVec = Normal.convert;
}

///
unittest
{
    auto n1 = Normal(0.0, 0.0, 0.0), n2 = Normal(5.0, 12.0, 0.0);
    assert(n1.normalize == n1);
    assert(n2.normalize.xyzIsClose(Normal(5.0 / 13.0, 12.0 / 13.0, 0.0)));
}

// ************************* Vec2d *************************
/// struct for a 2D Vec
struct Vec2d
{
    float u, v;

    /// Verify if two Vec2d are close calling the function areClose on every component (u, v)
    pure nothrow @nogc @safe bool uvIsClose(in Vec2d v2d) const
    {
        return areClose(u, v2d.u) && areClose(v, v2d.v);
    }
}

/// Return an array of Vec generatig a 3D Orthonormal Base
pure nothrow @nogc @safe Vec[3] createONBFromZ(Normal n)
{
    immutable float sqNorm = n.squaredNorm;
    if (!areClose(sqNorm, 1.0, 1e-4)) n = n * (1.0 / sqrt(sqNorm));

    immutable float sign = n.z > 0.0 ? 1.0 : -1.0;
    immutable float a = -1.0 / (sign + n.z);
    immutable float b = n.x * n.y * a;

    immutable e1 = Vec(1.0 + sign * n.x * n.x * a, sign * b, -sign * n.x);
    immutable e2 = Vec(b, sign + n.y * n.y * a, -n.y);

    return [e1, e2, Vec(n.x, n.y, n.z)];
}

///
unittest
{
    auto pcg = new PCG();
    Vec[3] base;
    for (int i = 0; i < 10_000; ++i)
    {
        auto n = Normal(pcg.randomFloat, pcg.randomFloat, pcg.randomFloat).normalize;
        base = createONBFromZ(n);

        // Verify that the z axis is aligned with the normal
        assert(base[2].xyzIsClose(n.toVec));

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