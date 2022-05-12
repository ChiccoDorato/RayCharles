module geometry;

import hdrimage : areClose;
import std.array : split;
import std.conv : to;
import std.math : sqrt;

mixin template toString(T)
{
    string toString()() const
    in (T.tupleof.length == 3, "toString accepts xyz types only.")
    {
        string[] typePath = to!string(typeid(T)).split(".");
        return typePath[$-1]~"(x="~to!string(x)~", y="~to!string(y)~", z="~to!string(z)~")";
    }
}

mixin template xyzIsClose(T)
{
    bool xyzIsClose(T)(in T v) const
    in (T.tupleof.length == 3, "xyzIsClose accepts xyz types only.")
    {
        return areClose(x, v.x) && areClose(y, v.y) && areClose(z, v.z);
    }
}

/*mixin template sumDiff(T, R)
{
    R opBinary(string op)(in T rhs) const if (op == "+" || op == "-")
    in (T.tupleof.length == 3 && R.tupleof.length == 3, "sumDiff accepts xyz types only.")
    {
        return mixin("R(x"~op~"rhs.x, y"~op~"rhs.y, z"~op~"rhs.z)");
    }
}*/

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

mixin template squaredNorm(T)
{
    float squaredNorm()() const
    in (T.tupleof.length == 3, "squaredNorm accepts xyz types only.")
    {
        return x * x + y * y + z * z;
    }
}

mixin template norm(T)
{
    float norm()() const
    in (T.tupleof.length == 3, "norm accepts xyz types only.")
    {
        return sqrt(squaredNorm());
    }
}

mixin template normalize(R)
{
    R normalize()() const
    in (R.tupleof.length == 3, "normalize accepts xyz types only.")
    {
        return 1.0 / norm() * this;
    }
}

mixin template convert(T, R)
{
    R convert() const
    in (T.tupleof.length == 3 && R.tupleof.length == 3, "convert accepts xyz types only.")
    {
        return R(x, y, z);
    }
}

struct Vec
{
    float x, y, z;

    mixin toString!Vec;
    mixin xyzIsClose!Vec;

    //mixin sumDiff!(Vec, Vec);
    Vec opBinary(string op)(in Vec rhs) const if (op == "+" || op == "-")
    {
        return mixin("Vec(x"~op~"rhs.x, y"~op~"rhs.y, z"~op~"rhs.z)");
    }

    mixin neg!Vec;
    //mixin mul!Vec;
    Vec opBinary(string op)(in float alfa) const if (op == "*")
    {
        return Vec(x * alfa, y * alfa, z * alfa);
    }
    mixin rightMul!Vec;

    //mixin dot!Vec;
    float opBinary(string op)(in Vec rhs) const if (op == "*")
    {
        return x * rhs.x + y * rhs.y + z * rhs.z;
    }
    //mixin dot!Normal;
    float opBinary(string op)(in Normal rhs) const if (op == "*")
    {
        return x * rhs.x + y * rhs.y + z * rhs.z;
    }
    //mixin cross!(Vec, Vec);
    Vec opBinary(string op)(in Vec rhs) const if (op == "^")
    {
        return Vec(y * rhs.z - z * rhs.y, z * rhs.x - x * rhs.z, x * rhs.y - y * rhs.x);
    }
    //mixin cross!(Normal, Vec);
    Vec opBinary(string op)(in Normal rhs) const if (op == "^")
    {
        return Vec(y * rhs.z - z * rhs.y, z * rhs.x - x * rhs.z, x * rhs.y - y * rhs.x);
    }

    mixin squaredNorm!Vec;
    mixin norm!Vec;
    mixin normalize!Vec;

    mixin convert!(Vec, Normal);
}

immutable(Vec) vecX = Vec(1.0, 0.0, 0.0),
    vecY = Vec(0.0, 1.0, 0.0),
    vecZ = Vec(0.0, 0.0, 1.0);

unittest
{
    Vec a = {1.0, 2.0, 3.0}, b = {4.0, 6.0, 8.0};

    assert(a.xyzIsClose(a));
    assert(!a.xyzIsClose(b));

    assert((-a).xyzIsClose(Vec(-1.0, -2.0, -3.0)));
    assert((a + b).xyzIsClose(Vec(5.0, 8.0, 11.0)));
    assert((b - a).xyzIsClose(Vec(3.0, 4.0, 5.0)));

    assert((a * 2).xyzIsClose(Vec(2.0, 4.0, 6.0)));
    assert((-4 * a).xyzIsClose(Vec(-4.0, -8.0, -12.0)));

    assert((a * b).areClose(40.0));
    assert((a ^ b).xyzIsClose(Vec(-2.0, 4.0, -2.0)));
    assert((b ^ a).xyzIsClose(Vec(2.0, -4.0, 2.0)));

    assert(areClose(a.squaredNorm, 14.0));
    assert(areClose(a.norm * a.norm, 14.0));
}

struct Point
{
    float x, y, z;

    mixin toString!Point;
    mixin xyzIsClose!Point;
    
    //mixin sumDiff!(Point, Vec);
    Point opBinary(string op)(in Vec rhs) const if (op == "+" || op == "-")
    {
        return mixin("Point(x"~op~"rhs.x, y"~op~"rhs.y, z"~op~"rhs.z)");
    }
    Vec opBinary(string op)(in Point rhs) const if (op == "-")
    {
        return Vec(x - rhs.x, y - rhs.y, z - rhs.z);
    }

    mixin neg!Point;
    //mixin mul!Point;
    Point opBinary(string op)(in float alfa) const if (op == "*")
    {
        return Point(x * alfa, y * alfa, z * alfa);
    }
    mixin rightMul!Point;

    mixin convert!(Point, Vec);
}

unittest
{
    Point p1 = {1.0, 2.0, 3.0}, p2 = {4.0, 6.0, 8.0};
    assert(p1.xyzIsClose(p1));
    assert(!p1.xyzIsClose(p2));

    assert((-p1 * 2).xyzIsClose(Point(-2.0, -4.0, -6.0)));
    assert((0.5 * p2).xyzIsClose(Point(2.0, 3.0, 4.0)));

    Vec v = {4.0, 6.0, 8.0};
    assert((p1 + v).xyzIsClose(Point(5.0, 8.0, 11.0)));
    assert((p1 - v).xyzIsClose(Point(-3.0, -4.0, -5.0)));
    assert((p2 - p1).xyzIsClose(Vec(3.0, 4.0, 5.0)));
}

struct Normal
{
    float x, y, z;

    mixin toString!Normal;
    mixin xyzIsClose!Normal;

    mixin neg!Normal;
    //mixin mul!Normal;
    Normal opBinary(string op)(in float alfa) const if (op == "*")
    {
        return Normal(x * alfa, y * alfa, z * alfa);
    }
    mixin rightMul!Normal;

    //mixin dot!Vec;
    float opBinary(string op)(in Vec rhs) const if (op == "*")
    {
        return x * rhs.x + y * rhs.y + z * rhs.z;
    }
    //mixin cross!(Normal, Vec);
    Vec opBinary(string op)(in Normal rhs) const if (op == "^")
    {
        return Vec(y * rhs.z - z * rhs.y, z * rhs.x - x * rhs.z, x * rhs.y - y * rhs.x);
    }

    mixin squaredNorm!Normal;
    mixin norm!Normal;
    mixin normalize!Normal;
}

struct Vec2d
{
    float u, v;

    bool uvIsClose(in Vec2d v2d) const
    {
        return areClose(u, v2d.u) && areClose(v, v2d.v);
    }
}