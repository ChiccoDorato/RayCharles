import std.stdio;
import std.conv;

struct color{
	float r=0, g=0, b=0;

	color opBinary(string op)(color rhs){
		static if(op == "+" || op == "-" || op == "*"){
			mixin ("return color(r"~op~"rhs.r, g"~op~"rhs.g, b"~op~"rhs.b);");
		}
		else static assert(0, "Operation "~op~" not defined");
	}

	color opBinary(string op:"*")(float alfa){
		mixin ("return color(r"~op~"alfa, g"~op~"alfa, b"~op~"alfa);");
	}

	color opBinaryRight(string op:"*")(float alfa){
		mixin ("return color(r"~op~"alfa, g"~op~"alfa, b"~op~"alfa);");
	}
}

class HDRImage{
	int width, height;
	color[] pixels;
	
	this(int w, int h){
		width = w;
		height = h;
		pixels.length = width*height;
	}
}

void main(string[] args)
{
	if(args.length != 3){
		writeln("Passare le dimensioni dell'immagine");
		return;
	}

	int w = to!int(args[1]);
	int h = to!int(args[2]);
	HDRImage image = new HDRImage(w,h);

	color c1 = {70,10,80};
	color c2 = {20,100,33};
	writeln("C1: ",c1);
	writeln("C2: ",c2);
	writeln("C1*2:", c1*2);
	writeln("C1+C2: ", c1+c2);
	writeln("C1-C2: ", c1-c2);
	writeln("C2*2: ", c2*2);
	writeln("C1*C2: ", c1*c2);
	writeln("3*C1: ", 3*c1);
	writeln("-0.5*C2: ", -0.5*c2);
}
