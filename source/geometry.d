import std.array : split;
import std.conv : to;
import std.math : abs,sqrt,PI,sin,cos;

mixin template toString(T)
{
    string toString()()
    in (T.tupleof.length == 3, "toString accepts xyz types only.")
    {
        string[] typePath = to!string(typeid(T)).split(".");
        return typePath[$-1]~"(x="~to!string(x)~", y="~to!string(y)~", z="~to!string(z)~")";
    }
}

bool areClose(float x, float y, float epsilon=1e-5)
{
	return abs(x-y) < epsilon;
}

mixin template xyzIsClose(T)
{
    bool xyzIsClose(T)(T v)
    in (T.tupleof.length == 3, "xyzIsClose accepts xyz types only.")
    {
        return areClose(x, v.x) && areClose(y, v.y) && areClose(z, v.z);
    }
}

/*mixin template sumDiff(T, R)
{
    R opBinary(string op)(T rhs) if (op == "+" || op == "-")
    in (T.tupleof.length == 3 && R.tupleof.length == 3, "sumDiff accepts xyz types only.")
    {
        return mixin("R(x"~op~"rhs.x, y"~op~"rhs.y, z"~op~"rhs.z)");
    }
}*/

mixin template neg(R)
{
    R opUnary(string op)() if (op == "-")
    in (R.tupleof.length == 3, "neg accepts xyz types only.")
    {
        return R(-x, -y, -z);
    }
}

/*mixin template mul(R)
{
    R opBinary(string op)(float alfa) if (op == "*")
    in (R.tupleof.length == 3, "mul accepts xyz types only.")
    {
        return R(x * alfa, y * alfa, z * alfa);
    }
}*/

mixin template rightMul(R)
{
    R opBinaryRight(string op)(float alfa) if (op == "*")
    in (R.tupleof.length == 3, "rightMul accepts xyz types only.")
    {
        return R(alfa * x, alfa * y, alfa * z);
    }
}

/*mixin template dot(T)
{
    float opBinary(string op)(T rhs) if (op == "*")
    in (T.tupleof.length == 3, "dot accepts xyz types only.")
    {
        return x * rhs.x + y * rhs.y + z * rhs.z;
    }
}*/

/*mixin template cross(T, R)
{
    R opBinary(string op)(T rhs) if (op == "^")
    in (T.tupleof.length == 3 && R.tupleof.length == 3, "cross accepts xyz types only.")
    {
        return mixin("R(y * rhs.z - z * rhs.y, z * rhs.x - x * rhs.z, x * rhs.y - y * rhs.x)");
    }
}*/

mixin template squaredNorm(T)
{
    float squaredNorm()()
    in (T.tupleof.length == 3, "squaredNorm accepts xyz types only.")
    {
        return x * x + y * y + z * z;
    }
}

mixin template norm(T)
{
    float norm()()
    in (T.tupleof.length == 3, "norm accepts xyz types only.")
    {
        return sqrt(squaredNorm());
    }
}

mixin template normalize(R)
{
    R normalize()()
    in (R.tupleof.length == 3, "normalize accepts xyz types only.")
    {
        return 1 / norm() * this;
    }
}

mixin template convert(T, R)
{
    R convert()
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
    Vec opBinary(string op)(Vec rhs) if (op == "+" || op == "-")
    {
        return mixin("Vec(x"~op~"rhs.x, y"~op~"rhs.y, z"~op~"rhs.z)");
    }

    mixin neg!Vec;
    //mixin mul!Vec;
    Vec opBinary(string op)(float alfa) if (op == "*")
    {
        return Vec(x * alfa, y * alfa, z * alfa);
    }
    mixin rightMul!Vec;

    //mixin dot!Vec;
    float opBinary(string op)(Vec rhs) if (op == "*")
    {
        return x * rhs.x + y * rhs.y + z * rhs.z;
    }
    //mixin dot!Normal;
    float opBinary(string op)(Normal rhs) if (op == "*")
    {
        return x * rhs.x + y * rhs.y + z * rhs.z;
    }
    //mixin cross!(Vec, Vec);
    Vec opBinary(string op)(Vec rhs) if (op == "^")
    {
        return Vec(y * rhs.z - z * rhs.y, z * rhs.x - x * rhs.z, x * rhs.y - y * rhs.x);
    }
    //mixin cross!(Normal, Vec);
    Vec opBinary(string op)(Normal rhs) if (op == "^")
    {
        return Vec(y * rhs.z - z * rhs.y, z * rhs.x - x * rhs.z, x * rhs.y - y * rhs.x);
    }

    mixin squaredNorm!Vec;
    mixin norm!Vec;
    mixin normalize!Vec;

    mixin convert!(Vec, Normal);
}

Vec vecX = Vec(1.0, 0.0, 0.0), vecY = Vec(0.0, 1.0, 0.0), vecZ = Vec(0.0, 0.0, 1.0);

struct Point
{
    float x, y, z;

    mixin toString!Point;
    mixin xyzIsClose!Point;
    
    //mixin sumDiff!(Point, Vec);
    Point opBinary(string op)(Vec rhs) if (op == "+" || op == "-")
    {
        return mixin("Point(x"~op~"rhs.x, y"~op~"rhs.y, z"~op~"rhs.z)");
    }
    Vec opBinary(string op)(Point rhs) if (op == "-")
    {
        return Vec(x - rhs.x, y - rhs.y, z - rhs.z);
    }

    mixin neg!Point;
    //mixin mul!Point;
    Point opBinary(string op)(float alfa) if (op == "*")
    {
        return Point(x * alfa, y * alfa, z * alfa);
    }
    mixin rightMul!Point;

    mixin convert!(Point, Vec);
}

struct Normal
{
    float x, y, z;

    mixin toString!Normal;
    mixin xyzIsClose!Normal;

    mixin neg!Normal;
    //mixin mul!Normal;
    Normal opBinary(string op)(float alfa) if (op == "*")
    {
        return Normal(x * alfa, y * alfa, z * alfa);
    }
    mixin rightMul!Normal;

    //mixin dot!Vec;
    float opBinary(string op)(Vec rhs) if (op == "*")
    {
        return x * rhs.x + y * rhs.y + z * rhs.z;
    }
    //mixin cross!(Normal, Vec);
    Vec opBinary(string op)(Normal rhs) if (op == "^")
    {
        return Vec(y * rhs.z - z * rhs.y, z * rhs.x - x * rhs.z, x * rhs.y - y * rhs.x);
    }

    mixin squaredNorm!Normal;
    mixin norm!Normal;
    mixin normalize!Normal;
}

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

float[4][4] id4 = [[1,0,0,0], [0,1,0,0], [0,0,1,0], [0,0,0,1]];

struct Transformation
{	
	float[4][4] m = [[1,0,0,0], [0,1,0,0], [0,0,1,0], [0,0,0,1]];
	float[4][4] invM = [[1,0,0,0], [0,1,0,0], [0,0,1,0], [0,0,0,1]];

	this(float[4][4] matrix, float[4][4] invMatrix)
    {
		m = matrix;
		invM = invMatrix;
	}

	float[4][4] matProd(float[4][4] m1, float[4][4] m2)
    {
		float[4][4] prod = 0;
		for (ubyte i = 0; i < 4; ++i)
			for (ubyte j = 0; j < 4; ++j)
				for (ubyte k = 0; k < 4; ++k) prod[i][j] += m1[i][k]*m2[k][j];
		return prod;
	}

    bool matrixIsClose(float[4][4] m1, float[4][4] m2, float epsilon=1e-5)
    {
        for (ubyte i = 0; i < 4; ++i)
            for (ubyte j = 0; j < 4; ++j)
                if (!areClose(m1[i][j], m2[i][j], epsilon)) return false;
        return true;
    }

    bool transfIsClose(Transformation t, float epsilon=1e-5)
    {
        return matrixIsClose(m, t.m, epsilon) && matrixIsClose(invM, t.invM, epsilon);
    }

	bool isConsistent(float epsilon=1e-5)
    {
		return matrixIsClose(matProd(m, invM), id4, epsilon);
	}

	Transformation inverse()
    {
		return Transformation(invM, m);
	}

	Transformation opBinary(string op)(Transformation rhs) if (op == "*")
    {
		return Transformation(matProd(m, rhs.m), matProd(rhs.invM, invM));
	}

	Point opBinary(string op)(Point rhs) if (op == "*")
    {
		Point p = Point(rhs.x * m[0][0] + rhs.y * m[0][1] + rhs.z * m[0][2] + m[0][3],
            rhs.x * m[1][0] + rhs.y * m[1][1] + rhs.z * m[1][2] + m[1][3],
            rhs.x * m[2][0] + rhs.y * m[2][1] + rhs.z * m[2][2] + m[2][3]);

		float lambda = rhs.x * m[3][0] + rhs.y * m[3][1] + rhs.z * m[3][2] + m[3][3];
		if (lambda == 1) return p;
		return p * (1 / lambda);
	}

	Vec opBinary(string op)(Vec rhs) if (op == "*")
    {
		return Vec(rhs.x * m[0][0] + rhs.y * m[0][1] + rhs.z * m[0][2],
            rhs.x * m[1][0] + rhs.y * m[1][1] + rhs.z * m[1][2],
            rhs.x * m[2][0] + rhs.y * m[2][1] + rhs.z * m[2][2]);
	}

    Normal opBinary(string op)(Normal rhs) if (op == "*")
    {
		return Normal(rhs.x * invM[0][0] + rhs.y * invM[1][0] + rhs.z * invM[2][0],
            rhs.x * invM[0][1] + rhs.y * invM[1][1] + rhs.z * invM[2][1],
            rhs.x * invM[0][2] + rhs.y * invM[1][2] + rhs.z * invM[2][2]);
	}
    
// Function that creates translation of a given vector.
Transformation translation(Vec v)
{
	float[4][4] m = [[1.0, 0.0, 0.0, v.x],
		[0.0, 1.0, 0.0, v.y],
		[0.0, 0.0, 1.0, v.z],
		[0.0, 0.0, 0.0, 1.0]];
	float[4][4] invM = [[1.0, 0.0, 0.0, -v.x],
		[0.0, 1.0, 0.0, -v.y],
		[0.0, 0.0, 1.0, -v.z],
		[0.0, 0.0, 0.0, 1.0]];
	return Transformation(m, invM);
}

Transformation rotationX(float angleInDegrees)
{
    float sine = sin(angleInDegrees * PI / 180), cosine = cos(angleInDegrees * PI / 180);
    float[4][4] m = [[1.0, 0.0, 0.0, 0.0],
        [0.0, cosine, -sine, 0.0],
        [0.0, sine, cosine, 0.0],
        [0.0, 0.0, 0.0, 1.0]];
    float[4][4] invM = [[1.0, 0.0, 0.0, 0.0],
        [0.0, cosine, sine, 0.0],
        [0.0, -sine, cosine, 0.0],
        [0.0, 0.0, 0.0, 1.0]];
    return Transformation(m, invM);
}

Transformation rotationY(float angleInDegrees)
{
    float sine = sin(angleInDegrees * PI / 180), cosine = cos(angleInDegrees * PI / 180);
    float[4][4] m = [[cosine, 0.0, sine, 0.0],
        [0.0, 1.0, 0.0, 0.0],
        [-sine, 0.0, cosine, 0.0],
        [0.0, 0.0, 0.0, 1.0]];
    float[4][4] invM = [[cosine, 0.0, -sine, 0.0],
        [0.0, 1.0, 0.0, 0.0],
        [sine, 0.0, cosine, 0.0],
        [0.0, 0.0, 0.0, 1.0]];
    return Transformation(m, invM);
}

Transformation rotationZ(float angleInDegrees)
{
    float sine = sin(angleInDegrees * PI / 180), cosine = cos(angleInDegrees * PI / 180);
    float[4][4] m = [[cosine, -sine, 0.0, 0.0],
        [sine, cosine, 0.0, 0.0],
        [0.0, 0.0, 1.0, 0.0],
        [0.0, 0.0, 0.0, 1.0]];
    float[4][4] invM = [[cosine, sine, 0.0, 0.0],
        [-sine, cosine, 0.0, 0.0],
        [0.0, 0.0, 1.0, 0.0],
        [0.0, 0.0, 0.0, 1.0]];
    return Transformation(m, invM);
}

Transformation scaling(Vec v)
{
	float[4][4] m = [[v.x, 0.0, 0.0, 0.0],
		[0.0, v.y, 0.0, 0.0],
		[0.0, 0.0, v.z, 0.0],
		[0.0, 0.0, 0.0, 1.0]];
	float[4][4] invM = [[1/v.x, 0.0, 0.0, 0.0],
		[0.0, 1/v.y, 0.0, 0.0],
		[0.0, 0.0, 1/v.z, 0.0],
		[0.0, 0.0, 0.0, 1.0]];
	return Transformation(m, invM);
}

unittest
{
    float[4][4] m1 = [[1.0, 2.0, 3.0, 4.0],
        [5.0, 6.0, 7.0, 8.0],
        [9.0, 9.0, 8.0, 7.0],
        [6.0, 5.0, 4.0, 1.0]];
    float[4][4] m2 = [[-3.75, 2.75, -1, 0],
        [4.375, -3.875, 2.0, -0.5],
        [0.5, 0.5, -1.0, 1.0],
        [-1.375, 0.875, 0.0, -0.5]];
    Transformation t1 = Transformation(m1, m2);
    assert(t1.isConsistent);

    Transformation t2 = Transformation(t1.m, t1.invM);
    assert(t1.transfIsClose(t2));

    Transformation t3 = Transformation(t1.m, t1.invM);
    t3.m[2][2] += 1.0;
    assert(!t1.transfIsClose(t3));

    Transformation t4 = Transformation(t1.m, t1.invM);
    t4.invM[2][2] += 1.0;
    assert(!t1.transfIsClose(t4));
}

unittest
{
    float[4][4] m1 = [[1.0, 2.0, 3.0, 4.0],
        [5.0, 6.0, 7.0, 8.0],
        [9.0, 9.0, 8.0, 7.0],
        [6.0, 5.0, 4.0, 1.0]];
    float[4][4] m2 = [[-3.75, 2.75, -1, 0],
        [4.375, -3.875, 2.0, -0.5],
        [0.5, 0.5, -1.0, 1.0],
        [-1.375, 0.875, 0.0, -0.5]];
    Transformation t1 = Transformation(m1, m2);
    assert(t1.isConsistent);

    float[4][4] m3 = [[3.0, 5.0, 2.0, 4.0],
        [4.0, 1.0, 0.0, 5.0],
        [6.0, 3.0, 2.0, 0.0],
        [1.0, 4.0, 2.0, 1.0]];
    float[4][4] m4 = [[0.4, -0.2, 0.2, -0.6],
        [2.9, -1.7, 0.2, -3.1],
        [-5.55, 3.15, -0.4, 6.45],
        [-0.9, 0.7, -0.2, 1.1]];
    Transformation t2 = Transformation(m3, m4);
    assert(t2.isConsistent);

    float[4][4] m5 = [[33.0, 32.0, 16.0, 18.0],
        [89.0, 84.0, 40.0, 58.0],
        [118.0, 106.0, 48.0, 88.0],
        [63.0, 51.0, 22.0, 50.0]];
    float[4][4] m6 = [[-1.45, 1.45, -1.0, 0.6],
        [-13.95, 11.95, -6.5, 2.6],
        [25.525, -22.025, 12.25, -5.2],
        [4.825, -4.325, 2.5, -1.1]];
    Transformation expected = Transformation(m5, m6);
    assert(expected.isConsistent(1e-4));
    assert(expected.transfIsClose(t1 * t2));
}

unittest
{
    float[4][4] m1 = [[1.0, 2.0, 3.0, 4.0],
        [5.0, 6.0, 7.0, 8.0],
        [9.0, 9.0, 8.0, 7.0],
        [0.0, 0.0, 0.0, 1.0]];
    float[4][4] m2 = [[-3.75, 2.75, -1, 0],
        [5.75, -4.75, 2.0, 1.0],
        [-2.25, 2.25, -1.0, -2.0],
        [0.0, 0.0, 0.0, 1.0]];
    Transformation t = Transformation(m1, m2);
    assert(t.isConsistent);

    Vec expectedV = {14.0, 38.0, 51.0};
    assert(expectedV.xyzIsClose(t * Vec(1.0, 2.0, 3.0)));

    Point expectedP = {18.0, 46.0, 58.0};
    assert(expectedP.xyzIsClose(t * Point(1.0, 2.0, 3.0)));

    Point expectedN = {-8.75, 7.75, -3.0};
    assert(expectedN.xyzIsClose(t * Normal(3.0, 2.0, 4.0)));
}

unittest
{
    float[4][4] m1 = [[1.0, 2.0, 3.0, 4.0],
        [5.0, 6.0, 7.0, 8.0],
        [9.0, 9.0, 8.0, 7.0],
        [6.0, 5.0, 4.0, 1.0]];
    float[4][4] m2 = [[-3.75, 2.75, -1, 0],
        [4.375, -3.875, 2.0, -0.5],
        [0.5, 0.5, -1.0, 1.0],
        [-1.375, 0.875, 0.0, -0.5]];
    Transformation t1 = Transformation(m1, m2);

    Transformation t2 = t1.inverse;
    assert(t2.isConsistent);

    Transformation prod = t1 * t2;
    assert(prod.isConsistent);
    assert(prod.transfIsClose(Transformation()));
}

unittest
{
    Transformation tr1 = translation(Vec(1.0, 2.0, 3.0));
    assert(tr1.isConsistent);

    Transformation tr2 = translation(Vec(4.0, 6.0, 8.0));
    assert(tr2.isConsistent);

    Transformation prod = tr1 * tr2;
    assert(prod.isConsistent);

    Transformation expected = translation(Vec(5.0, 8.0, 11.0));
    assert(prod.transfIsClose(expected));
}

unittest
{
    assert(rotationX(0.1).isConsistent);
    assert(rotationY(0.1).isConsistent);
    assert(rotationZ(0.1).isConsistent);

    assert((rotationX(90) * vecY).xyzIsClose(vecZ));
    assert((rotationY(90) * vecZ).xyzIsClose(vecX));
    assert((rotationZ(90) * vecX).xyzIsClose(vecY));
}

unittest
{
    Transformation tr1 = scaling(Vec(2.0, 5.0, 10.0));
    assert(tr1.isConsistent);

    Transformation tr2 = scaling(Vec(3.0, 2.0, 4.0));
    assert(tr2.isConsistent);

    Transformation expected = scaling(Vec(6.0, 10.0, 40.0));
    assert(expected.transfIsClose(tr1 * tr2));
}