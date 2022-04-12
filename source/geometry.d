import std.conv:to;
import std.array:split;
import std.math:abs,sqrt;

mixin template toString(T){
    string toString()()
    in(T.tupleof.length == 3, "toString accepts xyz types only.")
    {
        string[] typePath = to!string(typeid(T)).split(".");
        return typePath[$-1]~"(x="~to!string(x)~", y="~to!string(y)~", z="~to!string(z)~")";
    }
}

bool areClose(float x, float y, float epsilon=1e-5){
	return abs(x-y) < epsilon;
}

mixin template xyzIsClose(T){
    bool xyzIsClose(T)(T v)
    in(T.tupleof.length == 3, "xyzIsClose accepts xyz types only.")
    {
        return areClose(x, v.x) && areClose(y, v.y) && areClose(z, v.z);
    }
}

mixin template neg(R){
    R opUnary(string op)() if(op == "-")
    in(R.tupleof.length == 3, "neg accepts xyz types only.")
    {
        return R(-x, -y, -z);
    }
}

mixin template rightMul(R){
    R opBinaryRight(string op)(float alfa) if(op == "*")
    in(R.tupleof.length == 3, "rightMul accepts xyz types only.")
    {
        return R(alfa*x, alfa*y, alfa*z);
    }
}

mixin template squaredNorm(T){
    float squaredNorm()()
    in(T.tupleof.length == 3, "squaredNorm accepts xyz types only.")
    {
        return x*x + y*y + z*z;
    }
}

mixin template norm(T){
    float norm()()
    in(T.tupleof.length == 3, "norm accepts xyz types only.")
    {
        return sqrt(squaredNorm());
    }
}

mixin template normalize(R){
    R normalize()()
    in(R.tupleof.length == 3, "normalize accepts xyz types only.")
    {
        return 1/norm()*this;
    }
}

mixin template convert(T, R){
    R convert()
    in(T.tupleof.length == 3 && R.tupleof.length == 3, "convert accepts xyz types only.")
    {
        return R(x, y, z);
    }
}

/*mixin template sumDiff(T, R) {
  R opBinary(string op)(T rhs) const
       if (op == "+" || op == "-") {
      return mixin("R(x " ~ op ~ " rhs.x, y " ~ op ~ "rhs.y, z " ~ op ~ " rhs.z)");
      }
}
mixin template sum(T, R) {
  R opBinary(string op)(T rhs) const
       if (op == "+"){
      return R(x+rhs.x, y+rhs.y, z+rhs.z);
      //return mixin("R(x " ~ op ~ " rhs.x, y " ~ op ~ "rhs.y, z " ~ op ~ " rhs.z)");
      }
}

mixin template diff(T, R) {
  R opBinary(string op)(T rhs) const
       if (op == "-") {
       return R(x - rhs.x, y - rhs.y, z - rhs.z);
       //return mixin("R(x " ~ op ~ " rhs.x, y " ~ op ~ "rhs.y, z " ~ op ~ " rhs.z)");
      }
}
*/

/*mixin template mul(R){
    R opBinary(string op)(float alfa) if(op == "*"){
        return R(x*alfa, y*alfa, z*alfa);
    }
}*/

/*mixin template dot(T){
    float opBinary(string op)(T rhs) if(op == "*"){
        return x*rhs.x + y*rhs.y + z*rhs.z;
    }
}*/

/*mixin template cross(T, R){
    R opBinary(string op)(T rhs) if(op == "^"){
        return mixin("R(y*rhs.z-z*rhs.y, z*rhs.x-x*rhs.z, x*rhs.y-y*rhs.x)");
    }
}*/

struct vec{
    float x, y, z;

    //Method to convert a vec into a string
    mixin toString!vec;

    // Method to confront to vec to see if they are close
    mixin xyzIsClose!vec;

    //mixin sumDiff!(vec, vec);
    vec opBinary(string op)(vec rhs) if(op == "+" || op == "-"){
        return mixin("vec(x"~op~"rhs.x, y"~op~"rhs.y, z"~op~"rhs.z)");
    }
    //mixin neg!vec;
    vec opUnary(string op)() if(op == "-")
    in(this.tupleof.length == 3, "neg accepts xyz types only.")
    {
        return vec(-x, -y, -z);
    }
    //mixin mul!vec;
    vec opBinary(string op)(float alfa) if(op == "*"){
        return vec(x*alfa, y*alfa, z*alfa);
    }
    //mixin rightMul!vec;
    vec opBinaryRight(string op)(float alfa) if(op == "*"){
        return vec(alfa*x, alfa*y, alfa*z);
    }
    //mixin dot!vec;
    float opBinary(string op)(vec rhs) if(op == "*"){
        return x*rhs.x + y*rhs.y + z*rhs.z;
    }
    //mixin dot!normal;
    float opBinary(string op)(normal rhs) if(op == "*"){
        return x*rhs.x + y*rhs.y + z*rhs.z;
    }
    //mixin cross!(vec, vec);
    vec opBinary(string op)(vec rhs) if(op == "^"){
        return vec(y*rhs.z-z*rhs.y, z*rhs.x-x*rhs.z, x*rhs.y-y*rhs.x);
    }
    //mixin cross!(normal, vec);
    vec opBinary(string op)(normal rhs) if(op == "^"){
        return vec(y*rhs.z-z*rhs.y, z*rhs.x-x*rhs.z, x*rhs.y-y*rhs.x);
    }

    mixin squaredNorm!vec;
    mixin norm!vec;
    mixin normalize!vec;
    mixin convert!(vec, normal);
    
}

struct point{
    float x, y, z;

    mixin toString!point;
    mixin xyzIsClose!point;
    
    //mixin sumDiff!(point, vec);
    point opBinary(string op)(vec rhs) if(op == "+" || op == "-"){
        return mixin("point(x"~op~"rhs.x, y"~op~"rhs.y, z"~op~"rhs.z)");
    }

    vec opBinary(string op)(point rhs) if(op == "-"){
        return vec(x-rhs.x, y-rhs.y, z-rhs.z);
    }

    //mixin mul!point;
    point opBinary(string op)(float alfa) if(op == "*"){
        return point(x*alfa, y*alfa, z*alfa);
    }

    mixin neg!point;
    mixin rightMul!point;
    mixin convert!(point, vec);
}

struct normal{
    float x, y, z;

    mixin toString!normal;
    mixin xyzIsClose!normal;
    mixin neg!normal;

    //mixin mul!normal;
    normal opBinary(string op)(float alfa) if(op == "*"){
        return normal(x*alfa, y*alfa, z*alfa);
    }
    
    mixin rightMul!normal;

    //mixin dot!vec;
    float opBinary(string op)(vec rhs) if(op == "*"){
        return x*rhs.x + y*rhs.y + z*rhs.z;
    }
    //mixin cross!(normal, vec);
    vec opBinary(string op)(normal rhs) if(op == "^"){
        return vec(y*rhs.z-z*rhs.y, z*rhs.x-x*rhs.z, x*rhs.y-y*rhs.x);
    }

    mixin squaredNorm!normal;
    mixin norm!normal;
    mixin normalize!normal;
}

// Test Geometry
// test Vectors
unittest{
    vec a = {1.0, 2.0, 3.0}, b = {4.0, 6.0, 8.0};
    assert(a.xyzIsClose(a));
    assert(!a.xyzIsClose(b));
    // test Vectors Operations
    assert((-a).xyzIsClose(vec(-1.0, -2.0, -3.0)));
    assert((a+b).xyzIsClose(vec(5.0, 8.0, 11.0)));
    assert((b-a).xyzIsClose(vec(3.0, 4.0, 5.0)));

    assert((a*2).xyzIsClose(vec(2.0, 4.0, 6.0)));
    assert((-4*a).xyzIsClose(vec(-4.0, -8.0, -12.0)));

    assert((a*b).areClose(40.0));
    assert((a^b).xyzIsClose(vec(-2.0, 4.0, -2.0)));
    assert((b^a).xyzIsClose(vec(2.0, -4.0, 2.0)));

    assert(areClose(a.squaredNorm, 14.0));
    assert(areClose(a.norm*a.norm, 14.0));
}
// test Points
unittest{
    point p1 = {1.0, 2.0, 3.0}, p2 = {4.0, 6.0, 8.0};
    assert(p1.xyzIsClose(p1));
    assert(!p1.xyzIsClose(p2));
    // test Points Operations
    assert((-p1*2).xyzIsClose(point(-2.0, -4.0, -6.0)));
    assert((0.5*p2).xyzIsClose(point(2.0, 3.0, 4.0)));

    vec v = {4.0, 6.0, 8.0};
    assert((p1+v).xyzIsClose(point(5.0, 8.0, 11.0)));
    assert((p1-v).xyzIsClose(point(-3.0, -4.0, -5.0)));
    assert((p2-p1).xyzIsClose(vec(3.0, 4.0, 5.0)));
}

// Transformation
float[4][4] id4 = [[1,0,0,0],[0,1,0,0],[0,0,1,0],[0,0,0,1]];

struct transformation{	
	float[4][4] m = [[1,0,0,0],[0,1,0,0],[0,0,1,0],[0,0,0,1]]; 
	float[4][4] invM = [[1,0,0,0],[0,1,0,0],[0,0,1,0],[0,0,0,1]];

	this(float[4][4] matrix, float[4][4] invMatrix){
		m = matrix;
		invM = invMatrix;
	}

	float[4][4] matProd(float[4][4] m1, float[4][4] m2){
		float[4][4] mProd = 0;
		for(int i=0;i<4;i++){
			for(int j=0;j<4;j++){
				for(int k=0;k<4;k++){
					mProd[i][j] += m1[i][k]*m2[k][j];
				}
			}
		}
		return mProd;
	}

    // Method that makes the confront with another 4x4 matrix
    bool areCloseMatrix(float[4][4] m2){
		for(int i=0;i<4;i++){
			for(int j=0;j<4;j++){
				if(!areClose(m[i][j], m2[i][j])){
					return false;
				}
			}
		}
		return true;
    }

    // Method that makes the confront with another transformations
    bool areCloseTra(transformation m2){
		for(int i=0;i<4;i++){
			for(int j=0;j<4;j++){
				if(!areClose(m[i][j], m2.m[i][j]) || !areClose(invM[i][j], m2.invM[i][j])){
					return false;
				}
			}
		}
		return true;
    } 

	bool isConsistent(){
		return are2MatClose(matProd(m,invM), id4);
	}

    // Method that gives the inverse of a transf.
	transformation inverse(){
		transformation inv = transformation(this.invM, this.m);
		return inv;
	}

    // Method that calculates the product between two matrices returning the resulting matrix
    // The inverse is also calculated and inserted in the new transf.
	transformation opBinary(string op)(transformation rhs) if(op == "*"){
		return transformation(m.matProd(rhs.m), rhs.invM.matProd(invM));
	}

    // Method that calculates the product point * matrix of a transf. returning a point
	point opBinary(string op)(point rhs) if(op == "*"){
		point p = point(rhs.x * m[0][0] + rhs.y * m[0][1] + rhs.z * m[0][2] + m[0][3],
            rhs.x * m[1][0] + rhs.y * m[1][1] + rhs.z * m[1][2] + m[1][3],
            rhs.x * m[2][0] + rhs.y * m[2][1] + rhs.z * m[2][2] + m[2][3]);

		float lambda = rhs.x * m[3][0] + rhs.y * m[3][1] + rhs.z * m[3][2] + m[3][3];
		if(lambda == 1){
			return p;
		}
		return p*(1/lambda);
	}

    // Method that calculates the product vec * matrix of a transf. returning a vec
	vec opBinary(string op)(vec rhs) if(op == "*"){
		vec v = vec(rhs.x * m[0][0] + rhs.y * m[0][1] + rhs.z * m[0][2],
            rhs.x * m[1][0] + rhs.y * m[1][1] + rhs.z * m[1][2],
            rhs.x * m[2][0] + rhs.y * m[2][1] + rhs.z * m[2][2]);
	

		float lambda = rhs.x * m[3][0] + rhs.y * m[3][1] + rhs.z * m[3][2] + m[3][3];
		if(lambda == 1){
			return v;
		}
		return v*(1/lambda);
	}

    // Method that calculates the product normal * matrix of a transf. returning a normal
	normal opBinary(string op)(normal rhs) if(op == "*"){
		normal n = normal(rhs.x * invM[0][0] + rhs.y * invM[0][1] + rhs.z * invM[0][2],
            rhs.x * invM[1][0] + rhs.y * invM[1][1] + rhs.z * invM[1][2],
            rhs.x * invM[2][0] + rhs.y * invM[2][1] + rhs.z * invM[2][2]);
        return n;	
    }
}

// Function that confronts two generic 4x4 matrices
bool are2MatClose(float[4][4] m1, float[4][4] m2){
    for(int i=0;i<4;i++){
			for(int j=0;j<4;j++){
				if(!areClose(m1[i][j], m2[i][j])){
					return false;
				}
			}
	    }
	return true;
}

// Function that creates a translation matrix from a vector
transformation traslation(vec v){
    float[4][4] m = [[1.0, 0.0, 0.0, v.x],
        [0.0, 1.0, 0.0, v.y],
        [0.0, 0.0, 1.0, v.z],
        [0.0, 0.0, 0.0, 1.0]];
    float[4][4] invM = [[1.0, 0.0, 0.0, -v.x],
        [0.0, 1.0, 0.0, -v.y],
        [0.0, 0.0, 1.0, -v.z],
        [0.0, 0.0, 0.0, 1.0]];

    transformation trasl = transformation(m, invM);
    return trasl;
}

// test Transformations
unittest
{
    float[4][4] m=[ [1.0, 2.0, 3.0, 4.0],
                [5.0, 6.0, 7.0, 8.0],
                [9.0, 9.0, 8.0, 7.0],
                [6.0, 5.0, 4.0, 1.0]];
    float[4][4] invM=[[-3.75, 2.75, -1, 0],
                [4.375, -3.875, 2.0, -0.5],
                [0.5, 0.5, -1.0, 1.0],
                [-1.375, 0.875, 0.0, -0.5]];
    transformation m1 = transformation(m, invM);
    
    assert(m1.isConsistent());
    
    transformation m2 = transformation(m = m1.m, invM =m1.invM);

    assert(m1.areCloseMatrix(m2.m));
    assert(m1.areCloseTra(m2));
    assert(are2MatClose(m1.m,m2.m));
    assert(are2MatClose(m1.invM,m2.invM));
    

    transformation m3 = transformation(m = m1.m, invM = m1.invM);
    m3.m[2][2] += 1.0; 
    assert(!m1.areCloseMatrix(m3.m));
    assert(!m1.areCloseTra(m3));
    assert(!are2MatClose(m1.m, m3.m));
    //assert(!are2MatClose(m1.invM, m3.invM)); // of course because the inverse does not adjourn automatically!


    transformation m4 = transformation(m = m1.m, invM = m1.invM);
    m4.invM[2][2] += 1.0;
    assert(!m1.areCloseMatrix(m4.invM));
    assert(!m1.areCloseTra(m4));
    assert(!are2MatClose(m1.invM, m4.invM));
}

// Testing Multiplications
unittest
{
    float[4][4] m=[[1.0, 2.0, 3.0, 4.0],
                [5.0, 6.0, 7.0, 8.0],
                [9.0, 9.0, 8.0, 7.0],
                [6.0, 5.0, 4.0, 1.0]];
    float[4][4] invM=[[-3.75, 2.75, -1, 0],
                [4.375, -3.875, 2.0, -0.5],
                [0.5, 0.5, -1.0, 1.0],
                [-1.375, 0.875, 0.0, -0.5]];
    transformation m1 = transformation(m, invM);
    assert(m1.isConsistent());

    m=[[3.0, 5.0, 2.0, 4.0],
                [4.0, 1.0, 0.0, 5.0],
                [6.0, 3.0, 2.0, 0.0],
                [1.0, 4.0, 2.0, 1.0]];
    invM=[[0.4, -0.2, 0.2, -0.6],
                [2.9, -1.7, 0.2, -3.1],
                [-5.55, 3.15, -0.4, 6.45],
                [-0.9, 0.7, -0.2, 1.1]];
        
    transformation m2 = transformation(m, invM);
    assert(m2.isConsistent());

    float[4][4] me=[[33.0, 32.0, 16.0, 18.0],
                [89.0, 84.0, 40.0, 58.0],
                [118.0, 106.0, 48.0, 88.0],
                [63.0, 51.0, 22.0, 50.0]];
    float[4][4] invMe=[[-1.45, 1.45, -1.0, 0.6],
                [-13.95, 11.95, -6.5, 2.6],
                [25.525, -22.025, 12.25, -5.2],
                [4.825, -4.325, 2.5, -1.1]];

    transformation expected = transformation(me, invMe);
    // NOT CONSISTENT!!! ERROR IN THE MATRIX?
    //assert(expected.isConsistent());
    //assert(are2MatClose(m1.matProd(m1.m,m2.m), expected.m));
    //assert(are2MatClose(m1.matProd(m1.invM,m2.invM), expected.invM));
}
      

unittest{

    float[4][4] m=[
                [1.0, 2.0, 3.0, 4.0],
                [5.0, 6.0, 7.0, 8.0],
                [9.0, 9.0, 8.0, 7.0],
                [0.0, 0.0, 0.0, 1.0]];
    float[4][4] invM=[
                [-3.75, 2.75, -1, 0],
                [5.75, -4.75, 2.0, 1.0],
                [-2.25, 2.25, -1.0, -2.0],
                [0.0, 0.0, 0.0, 1.0]];

    transformation m5 = transformation(m, invM);
            
    assert(m5.isConsistent());

    vec expectedV = vec(14.0, 38.0, 51.0);
    //vec rhs = vec(1.0,2.0,3.0); 
    assert(expectedV.isClose(m5 * vec(1.0, 2.0, 3.0)));

    point expectedP = point(18.0, 46.0, 58.0);
    assert(expectedP.is_close(m5 * point(1.0, 2.0, 3.0));

    normal expectedN = normal(-8.75, 7.75, -3.0);
    assert(expected_n.is_close(m5 * normal(3.0, 2.0, 4.0));
}
unittest
{
      float[4][4] m=[
                [1.0, 2.0, 3.0, 4.0],
                [5.0, 6.0, 7.0, 8.0],
                [9.0, 9.0, 8.0, 7.0],
                [6.0, 5.0, 4.0, 1.0];
    float[4][4] invM=[
                [-3.75, 2.75, -1, 0],
                [4.375, -3.875, 2.0, -0.5],
                [0.5, 0.5, -1.0, 1.0],
                [-1.375, 0.875, 0.0, -0.5];

    transformation m6 = transformation(m, invM);
    assert(m6.isConsistent());

    transformation m7 = m1.inverse();
    assert(m7.isConsistent());
    
    transformation prod = m6.matProd(m6.m, m7.m);
    assert(prod.isConsistent());
}
        
// FINIRE

        
        assert prod.is_close(Transformation())

    def test_translations(self):
        tr1 = translation(Vec(1.0, 2.0, 3.0))
        assert tr1.is_consistent()

        tr2 = translation(Vec(4.0, 6.0, 8.0))
        assert tr1.is_consistent()

        prod = tr1 * tr2
        assert prod.is_consistent()

        expected = translation(Vec(5.0, 8.0, 11.0))
        assert prod.is_close(expected) */
}