module transformations;

import geometry : Normal, Point, Vec, vecX, vecY, vecZ;
import hdrimage : areClose;
import ray;
import std.math : cos, PI, sin, sqrt;

/// The Identity 4x4 Matrix
immutable float[4][4] id4 = [[1,0,0,0], [0,1,0,0], [0,0,1,0], [0,0,0,1]];

// ************************* Transformation *************************
/// Struct of a transformation that uses a 4x4 matrix as operator
struct Transformation
{	
	float[4][4] m = [[1,0,0,0], [0,1,0,0], [0,0,1,0], [0,0,0,1]];
	float[4][4] invM = [[1,0,0,0], [0,1,0,0], [0,0,1,0], [0,0,0,1]];

    /// Build a transformation with a 4x4 matrix and its inverse 4x4 matrix
	pure nothrow @nogc @safe this(in float[4][4] matrix, in float[4][4] invMatrix)
    {
		m = matrix;
		invM = invMatrix;
	}

    /// Return the product between two 4X4 matrices
	pure nothrow @nogc @safe float[4][4] matProd(in float[4][4] m1, in float[4][4] m2) const
    {
		float[4][4] prod = 0;
		for (ubyte i = 0; i < 4; ++i)
			for (ubyte j = 0; j < 4; ++j)
				for (ubyte k = 0; k < 4; ++k) prod[i][j] += m1[i][k]*m2[k][j];
		return prod;
	}

    /// Verify if two matrices are close by calling the fuction areClose on every component 
    pure nothrow @nogc @safe bool matrixIsClose(in float[4][4] m1, in float[4][4] m2, in float epsilon=1e-5) const
    {
        for (ubyte i = 0; i < 4; ++i)
            for (ubyte j = 0; j < 4; ++j)
                if (!areClose(m1[i][j], m2[i][j], epsilon)) return false;
        return true;
    }

    /// Verify if two Tranformations are close by calling the fuction matrixIsClose on the matrix and on its inverse
    pure nothrow @nogc @safe bool transfIsClose(in Transformation t, in float epsilon=1e-5) const
    {
        return matrixIsClose(m, t.m, epsilon) && matrixIsClose(invM, t.invM, epsilon);
    }

    /// Verify if a Tranformation is consistent: the product between the matrix and its inverse must be the identity
	pure nothrow @nogc @safe bool isConsistent(in float epsilon=1e-5) const
    {
		return matrixIsClose(matProd(m, invM), id4, epsilon);
	}

    /// Return the inverse of a Transformation
	pure nothrow @nogc @safe Transformation inverse() const
    {
		return Transformation(invM, m);
	}

    /// Return the product (*) between two Tranformations
	pure nothrow @nogc @safe Transformation opBinary(string op)(in Transformation rhs) const if (op == "*")
    {
		return Transformation(matProd(m, rhs.m), matProd(rhs.invM, invM));
	}

    /// Return the product (*) between a matrix and a Point 
	pure nothrow @nogc @safe Point opBinary(string op)(in Point rhs) const if (op == "*")
    {
		immutable Point p = Point(rhs.x * m[0][0] + rhs.y * m[0][1] + rhs.z * m[0][2] + m[0][3],
            rhs.x * m[1][0] + rhs.y * m[1][1] + rhs.z * m[1][2] + m[1][3],
            rhs.x * m[2][0] + rhs.y * m[2][1] + rhs.z * m[2][2] + m[2][3]);

		immutable float lambda = rhs.x * m[3][0] + rhs.y * m[3][1] + rhs.z * m[3][2] + m[3][3];
		if (lambda == 1) return p;
		return p * (1 / lambda);
	}

    /// Return the product (*) between a matrix and a Vec 
	pure nothrow @nogc @safe Vec opBinary(string op)(in Vec rhs) const if (op == "*")
    {
		return Vec(rhs.x * m[0][0] + rhs.y * m[0][1] + rhs.z * m[0][2],
            rhs.x * m[1][0] + rhs.y * m[1][1] + rhs.z * m[1][2],
            rhs.x * m[2][0] + rhs.y * m[2][1] + rhs.z * m[2][2]);
	}

    /// Return the product (*) between a matrix and a Normal 
    pure nothrow @nogc @safe Normal opBinary(string op)(in Normal rhs) const if (op == "*")
    {
		return Normal(rhs.x * invM[0][0] + rhs.y * invM[1][0] + rhs.z * invM[2][0],
            rhs.x * invM[0][1] + rhs.y * invM[1][1] + rhs.z * invM[2][1],
            rhs.x * invM[0][2] + rhs.y * invM[1][2] + rhs.z * invM[2][2]);
	}

    /// Return a transformed Ray: the product (*) of the origin (Point) and of the direction (Vec) with the matrix is calculated 
    pure nothrow @nogc @safe Ray opBinary(string op)(in Ray rhs) const if (op == "*")
    {
        return Ray(this * rhs.origin, this * rhs.dir, rhs.tMin, rhs.tMax, rhs.depth);
    }
}

///
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
    // isConsistent
    assert(t1.isConsistent);

    Transformation t2 = Transformation(t1.m, t1.invM);
    // transfIsClose
    assert(t1.transfIsClose(t2));

    Transformation t3 = Transformation(t1.m, t1.invM);
    t3.m[2][2] += 1.0;
    assert(!t1.transfIsClose(t3));

    Transformation t4 = Transformation(t1.m, t1.invM);
    t4.invM[2][2] += 1.0;
    assert(!t1.transfIsClose(t4));
}

///
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
    auto t = Transformation(m1, m2);
    assert(t.isConsistent);

    // Vec product
    auto expectedV = Vec(14.0, 38.0, 51.0);
    assert(expectedV.xyzIsClose(t * Vec(1.0, 2.0, 3.0)));

    // Point product
    auto expectedP = Point(18.0, 46.0, 58.0);
    assert(expectedP.xyzIsClose(t * Point(1.0, 2.0, 3.0)));

    // Normal product
    auto expectedN = Normal(-8.75, 7.75, -3.0);
    assert(expectedN.xyzIsClose(t * Normal(3.0, 2.0, 4.0)));
}

///
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
    // transfIsClose
    assert(expected.transfIsClose(t1 * t2));
}

///
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

    // inverse
    Transformation t2 = t1.inverse;
    assert(t2.isConsistent);

    // Transformation product (*)
    Transformation prod = t1 * t2;
    assert(prod.isConsistent);
    assert(prod.transfIsClose(Transformation()));
}

/// Return a translation of a given Vec (x,y,z)
pure nothrow @nogc @safe Transformation translation(in Vec v)
{
	immutable float[4][4] m = [[1.0, 0.0, 0.0, v.x],
		[0.0, 1.0, 0.0, v.y],
		[0.0, 0.0, 1.0, v.z],
		[0.0, 0.0, 0.0, 1.0]];
	immutable float[4][4] invM = [[1.0, 0.0, 0.0, -v.x],
		[0.0, 1.0, 0.0, -v.y],
		[0.0, 0.0, 1.0, -v.z],
		[0.0, 0.0, 0.0, 1.0]];
	return Transformation(m, invM);
}

///
unittest
{
    // translation
    Transformation tr1 = translation(Vec(1.0, 2.0, 3.0));
    assert(tr1.isConsistent);

    Transformation tr2 = translation(Vec(4.0, 6.0, 8.0));
    assert(tr2.isConsistent);

    Transformation prod = tr1 * tr2;
    assert(prod.isConsistent);

    Transformation expected = translation(Vec(5.0, 8.0, 11.0));
    assert(prod.transfIsClose(expected));
}

/// Return a Rotation around the X axis - Parameter: angle (float)
pure nothrow @nogc @safe Transformation rotationX(in float angleInDegrees)
{
    immutable float sine = sin(angleInDegrees * PI / 180), cosine = cos(angleInDegrees * PI / 180);
    immutable float[4][4] m = [[1.0, 0.0, 0.0, 0.0],
        [0.0, cosine, -sine, 0.0],
        [0.0, sine, cosine, 0.0],
        [0.0, 0.0, 0.0, 1.0]];
    immutable float[4][4] invM = [[1.0, 0.0, 0.0, 0.0],
        [0.0, cosine, sine, 0.0],
        [0.0, -sine, cosine, 0.0],
        [0.0, 0.0, 0.0, 1.0]];
    return Transformation(m, invM);
}

/// Return a Rotation around the X axis - Parameter: cosine and sine of an angle (float)
pure nothrow @nogc @safe Transformation rotationX(in float cosine, in float sine)
in (areClose(cosine * cosine + sine * sine, 1.0))
{
    immutable float[4][4] m = [[1.0, 0.0, 0.0, 0.0],
        [0.0, cosine, -sine, 0.0],
        [0.0, sine, cosine, 0.0],
        [0.0, 0.0, 0.0, 1.0]];
    immutable float[4][4] invM = [[1.0, 0.0, 0.0, 0.0],
        [0.0, cosine, sine, 0.0],
        [0.0, -sine, cosine, 0.0],
        [0.0, 0.0, 0.0, 1.0]];
    return Transformation(m, invM);
}

/// Return a Rotation around the Y axis - Parameter: angle (float)
pure nothrow @nogc @safe Transformation rotationY(in float angleInDegrees)
{
    immutable float sine = sin(angleInDegrees * PI / 180), cosine = cos(angleInDegrees * PI / 180);
    immutable float[4][4] m = [[cosine, 0.0, sine, 0.0],
        [0.0, 1.0, 0.0, 0.0],
        [-sine, 0.0, cosine, 0.0],
        [0.0, 0.0, 0.0, 1.0]];
    immutable float[4][4] invM = [[cosine, 0.0, -sine, 0.0],
        [0.0, 1.0, 0.0, 0.0],
        [sine, 0.0, cosine, 0.0],
        [0.0, 0.0, 0.0, 1.0]];
    return Transformation(m, invM);
}

/// Return a Rotation around the Y axis - Parameter: cosine and sine of an angle (float)
pure nothrow @nogc @safe Transformation rotationY(in float cosine, in float sine)
in (areClose(cosine * cosine + sine * sine, 1.0))
{
    immutable float[4][4] m = [[cosine, 0.0, sine, 0.0],
        [0.0, 1.0, 0.0, 0.0],
        [-sine, 0.0, cosine, 0.0],
        [0.0, 0.0, 0.0, 1.0]];
    immutable float[4][4] invM = [[cosine, 0.0, -sine, 0.0],
        [0.0, 1.0, 0.0, 0.0],
        [sine, 0.0, cosine, 0.0],
        [0.0, 0.0, 0.0, 1.0]];
    return Transformation(m, invM);
}

/// Return a Rotation around the Z axis - Parameter: angle (float)
pure nothrow @nogc @safe Transformation rotationZ(in float angleInDegrees)
{
    immutable float sine = sin(angleInDegrees * PI / 180), cosine = cos(angleInDegrees * PI / 180);
    immutable float[4][4] m = [[cosine, -sine, 0.0, 0.0],
        [sine, cosine, 0.0, 0.0],
        [0.0, 0.0, 1.0, 0.0],
        [0.0, 0.0, 0.0, 1.0]];
    immutable float[4][4] invM = [[cosine, sine, 0.0, 0.0],
        [-sine, cosine, 0.0, 0.0],
        [0.0, 0.0, 1.0, 0.0],
        [0.0, 0.0, 0.0, 1.0]];
    return Transformation(m, invM);
}

/// Return a Rotation around the Z axis - Parameter: cosine and sine of an angle (float)
pure nothrow @nogc @safe Transformation rotationZ(in float cosine, in float sine)
in (areClose(cosine * cosine + sine * sine, 1.0))
{
    immutable float[4][4] m = [[cosine, -sine, 0.0, 0.0],
        [sine, cosine, 0.0, 0.0],
        [0.0, 0.0, 1.0, 0.0],
        [0.0, 0.0, 0.0, 1.0]];
    immutable float[4][4] invM = [[cosine, sine, 0.0, 0.0],
        [-sine, cosine, 0.0, 0.0],
        [0.0, 0.0, 1.0, 0.0],
        [0.0, 0.0, 0.0, 1.0]];
    return Transformation(m, invM);
}

///
unittest
{
    // rotationX,rotationY, rotationZ
    assert(rotationX(0.1).isConsistent);
    assert(rotationY(0.1).isConsistent);
    assert(rotationZ(0.1).isConsistent);

    // xyzIsClose
    assert((rotationX(90) * vecY).xyzIsClose(vecZ));
    assert((rotationY(90) * vecZ).xyzIsClose(vecX));
    assert((rotationZ(90) * vecX).xyzIsClose(vecY));

    // transfIsClose
    assert(rotationX(sqrt(3.0) / 2.0, 0.5).transfIsClose(rotationX(30.0)));
    assert(rotationY(sqrt(2.0) / 2.0, sqrt(2.0) / 2.0).transfIsClose(rotationY(45.0)));
    assert(rotationZ(1.0, 0.0).transfIsClose(rotationZ(360.0)));
}

/// Return a scale transformation of a given Vec (x,y,z)
pure nothrow @nogc @safe Transformation scaling(in Vec v)
{
	immutable float[4][4] m = [[v.x, 0.0, 0.0, 0.0],
		[0.0, v.y, 0.0, 0.0],
		[0.0, 0.0, v.z, 0.0],
		[0.0, 0.0, 0.0, 1.0]];
	immutable float[4][4] invM = [[1/v.x, 0.0, 0.0, 0.0],
		[0.0, 1/v.y, 0.0, 0.0],
		[0.0, 0.0, 1/v.z, 0.0],
		[0.0, 0.0, 0.0, 1.0]];
	return Transformation(m, invM);
}

///
unittest
{
    // scaling
    Transformation tr1 = scaling(Vec(2.0, 5.0, 10.0));
    assert(tr1.isConsistent);

    Transformation tr2 = scaling(Vec(3.0, 2.0, 4.0));
    assert(tr2.isConsistent);

    // product of two scalings
    Transformation expected = scaling(Vec(6.0, 10.0, 40.0));
    assert(expected.transfIsClose(tr1 * tr2));
}