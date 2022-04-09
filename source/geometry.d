import std.conv;
import std.array;
import std.math;

mixin template toString(T){
    string toString()(){
        string[] typePath = to!string(typeid(T)).split(".");
        return typePath[$-1]~"(x="~to!string(x)~", y="~to!string(y)~", z="~to!string(z)~")";
    }
}

bool areClose(float x, float y, float epsilon=1e-5){
	return abs(x-y) < epsilon;
}

mixin template xyzIsClose(T){
    bool xyzIsClose(T)(T v){
        return areClose(x, v.x) && areClose(y, v.y) && areClose(z, v.z);
    }
}

/*mixin template sumDiff(T, R){
    R opBinary(string op)(T rhs) if(op == "+" || op == "-"){
        return mixin("R(x"~op~"rhs.x, y"~op~"rhs.y, z"~op~"rhs.z)");
    }
}*/

mixin template neg(R){
    R opUnary(string op)() if(op == "-"){
        return R(-x, -y, -z);
    }
}

/*mixin template mul(R){
    R opBinary(string op)(float alfa) if(op == "*"){
        return R(x*alfa, y*alfa, z*alfa);
    }
}*/

mixin template rightMul(R){
    R opBinaryRight(string op)(float alfa) if(op == "*"){
        return R(alfa*x, alfa*y, alfa*z);
    }
}

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

mixin template squaredNorm(T){
    float squaredNorm()(){
        return x*x + y*y + z*z;
    }
}

mixin template norm(T){
    float norm()(){
        return sqrt(squaredNorm());
    }
}

mixin template normalize(R){
    R normalize()(){
        return 1/norm()*this;
    }
}

mixin template convert(T, R){
    R convert(){
        return R(x, y, z);
    }
}

struct vec{
    float x, y, z;

    mixin toString!vec;
    mixin xyzIsClose!vec;

    //mixin sumDiff!(vec, vec);
    vec opBinary(string op)(vec rhs) if(op == "+" || op == "-"){
        return mixin("vec(x"~op~"rhs.x, y"~op~"rhs.y, z"~op~"rhs.z)");
    }
    mixin neg!vec;

    //mixin mul!vec;
    vec opBinary(string op)(float alfa) if(op == "*"){
        return vec(x*alfa, y*alfa, z*alfa);
    }
    mixin rightMul!vec;

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
    mixin neg!point;

    //mixin mul!point;
    point opBinary(string op)(float alfa) if(op == "*"){
        return point(x*alfa, y*alfa, z*alfa);
    }
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