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
        return this(-x, -y, -z);
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

unittest{
    vec a = {1.0, 2.0, 3.0}, b = {4.0, 6.0, 8.0};

    assert(a.xyzIsClose(a));
    assert(!a.xyzIsClose(b));

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

unittest{
    point p1 = {1.0, 2.0, 3.0}, p2 = {4.0, 6.0, 8.0};
    assert(p1.xyzIsClose(p1));
    assert(!p1.xyzIsClose(p2));

    assert((-p1*2).xyzIsClose(point(-2.0, -4.0, -6.0)));
    assert((0.5*p2).xyzIsClose(point(2.0, 3.0, 4.0)));

    vec v = {4.0, 6.0, 8.0};
    assert((p1+v).xyzIsClose(point(5.0, 8.0, 11.0)));
    assert((p1-v).xyzIsClose(point(-3.0, -4.0, -5.0)));
    assert((p2-p1).xyzIsClose(vec(3.0, 4.0, 5.0)));
}

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

	bool areCloseMatrix(float[4][4] m1, float[4][4] m2){
		for(int i=0;i<4;i++){
			for(int j=0;j<4;j++){
				if(!areClose(m1[i][j], m2[i][j])){
					return false;
				}
			}
		}
		return true;
	}

	bool isConsistent(){
		return areCloseMatrix(matProd(m,invM), id4);
	}

	transformation inverse(){
		transformation inv = transformation(this.invM, this.m);
		return inv;
	}

	transformation opBinary(string op)(transformation rhs) if(op == "*"){
		return transformation(m.matProd(rhs.m), rhs.invM.matProd(invM));
	}

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