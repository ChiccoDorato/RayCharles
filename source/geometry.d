import std.math;

bool areClose(float x, float y, float epsilon=1e-5){
	return abs(x-y) < epsilon;
}

mixin template SumDiff(T, Ret) {
  Ret opBinary(string op)(T rhs) const
       if (op == "+" || op == "-") {
      return mixin("Ret(x " ~ op ~ " rhs.x, y " ~ op ~ "rhs.y, z " ~ op ~ " rhs.z);");
      }
}

struct vec{
    float x, y, z;

    vec opBinary(string op)(vec rhs) if(op == "+" || op == "-"){
		mixin ("return vec(x"~op~"rhs.x, y"~op~"rhs.y, z"~op~"rhs.z);");
	}

    vec opUnary(string op)() if(op == "-"){
        mixin ("return vec(-x, -y, -z);");
    }

    vec opBinary(string op)(float alfa) if(op == "*"){
		mixin ("return vec(x*alfa, y*alfa, z*alfa);");
	}

    vec opBinaryRight(string op)(float alfa) if(op == "*"){
		mixin ("return vec(alfa*x, alfa*y, alfa*z);");
	}

    float opBinary(string op)(vec rhs) if(op == "*"){
        mixin ("return x*rhs.x + y*rhs.y + z*rhs.z;");
    }

    vec opBinary(string op)(vec rhs) if(op == "*"){
        mixin ("return vec(y*rhs.z-z*rhs.y, z*rhs.x-x*rhs.z, x*rhs.y-y*rhs.x);");
    }

	float squaredNorm(){
		return x*x + y*y + z*z;
	}

	float norm(){
		return sqrt(squaredNorm());
	}

	vec normalizeVec(){
		return this*(1/norm());
	}

    bool vecIsClose(vec v){
        return areClose(x, v.x) && areClose(y, v.y) && areClose(z, v.z);
    }
}

struct point{
    float x, y, z;
    mixin SumDiff!(vec, point);
    mixin SumDiff!(point, vec);
}

struct normal{
    float x, y, z;
}