import std.math;

bool areClose(float x, float y, float epsilon=1e-5){
	return abs(x-y) < epsilon;
}

mixin template neg(R){
    R opUnary(string op)() if(op == "-"){
        return mixin("R(-x, -y, -z);");
    }
}

mixin template mul(R){
    R opBinary(string op)(float alfa) if(op == "*"){
        return mixin("R(x*alfa, y*alfa, z*alfa);");
    }
}

mixin template rightMul(R){
    R opBinaryRight(string op)(float alfa) if(op == "*"){
        return mixin("R(alfa*x, alfa*y, alfa*z);");
    }
}

mixin template dot(T){
    float opBinary(string op)(T rhs) if(op == "*"){
        return mixin("return x*rhs.x + y*rhs.y + z*rhs.z;");
    }
}

mixin template cross(T, R){
    R opBinary(string op)(T rhs) if(op == "*"){
        return mixin("R(y*rhs.z-z*rhs.y, z*rhs.x-x*rhs.z, x*rhs.y-y*rhs.x);");
    }
}

float squaredNorm(T)(T v){
    return v.x*v.x + v.y*v.y + v.z*v.z;
}

float norm(T)(T v){
    return sqrt(squaredNorm(v));
}

mixin template normalize(R){
    R normalize(R)(R v){
        mixin mul!R;
        return mixin("v*(1/norm(v));");
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

// Prova a piazzarlo dentro la struttura!!!

mixin template toString(T){
    string toString(T obj){
        string line= "<"~to!string(obj.x)~", "~to!string(obj.y)~", "~to!string(obj.z)~">";
        return line;
    }
}
*/

struct point{
   float x, y, z;

    //mixin diff!(point, vec);
    //mixin sum!(vec, point);
    //mixin sumDiff!(vec, point);
    //mixin toString!(point);
    
    vec opBinary(string op)(point rhs) const
    if (op == "-") {
        return vec(x - rhs.x, y - rhs.y, z - rhs.z);
        //return mixin("point(x " ~ op ~ " rhs.x, y " ~ op ~ "rhs.y, z " ~ op ~ " rhs.z)");
    }

    point opBinary(string op)(vec rhs) const
    if (op == "+") {
          return point(x + rhs.x, y + rhs.y, z + rhs.z);
          //return mixin("point(x " ~ op ~ " rhs.x, y " ~ op ~ "rhs.y, z " ~ op ~ " rhs.z)");
    }
}

struct vec{
    float x, y, z;
}

/*

// PULLA DA BERNA

struct vec{
    float x, y, z;
        vec opBinary(string op)(vec rhs) if(op == "+" || op == "-"){
		mixin("return vec(x"~op~"rhs.x, y"~op~"rhs.y, z"~op~"rhs.z);");
	}


    mixin neg!vec;
    mixin sumDiff!(vec, vec);
    mixin mul!vec;
    mixin rightMul!vec;

    mixin dot!(vec);
    mixin cross!(vec, vec);

    mixin squaredNorm!vec;
    mixin norm!vec;
    mixin normalize!vec;

    bool vecIsClose(vec v){
        return areClose(x, v.x) && areClose(y, v.y) && areClose(z, v.z);
    }
}
*/

struct normal{
    float x, y, z;

    mixin neg!normal;
    mixin mul!(normal);
    mixin rightMul!normal;

    mixin dot!vec;
    mixin cross!(vec, vec);
    mixin cross!(normal, vec);

    mixin squaredNorm!normal;
    mixin norm!normal;
    mixin normalize!normal;
}