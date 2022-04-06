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

struct vec{
    float x, y, z;

    vec opBinary(string op)(vec rhs) if(op == "+" || op == "-"){
		mixin("return vec(x"~op~"rhs.x, y"~op~"rhs.y, z"~op~"rhs.z);");
	}

    mixin neg!vec;
    mixin defSumDiff!(vec, vec);
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

struct point{
    float x, y, z;
}

struct normal{
    float x, y, z;

    mixin neg!normal;
    mixin mul!(normal, float);
    mixin rightMul!normal;

    mixin dot!vec;
    mixin cross!(vec, vec);
    mixin cross!(normal, vec);

    mixin squaredNorm!normal;
    mixin norm!normal;
    mixin normalize!normal;
}