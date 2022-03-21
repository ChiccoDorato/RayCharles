import std.stdio;
import std.conv;
import std.math;

bool areClose(float x, float y, float epsilon=1e-5){
	return abs(x-y) < epsilon;
}

struct color{
	float r=0.0, g=0.0, b=0.0;

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

	void stampa(){
		writeln("(", r, ", ", g, ", ", b, ")");
	}

	bool colorAreClose(color c){
		return areClose(r, c.r) && areClose(g, c.g) && areClose(b, c.b);
	}

	unittest{
		color c1 = {1.0, 2.0, 3.0}, c2 = {5.0, 7.0, 9.0};

		assert (c1.colorAreClose(color(0.999999,2.0,3.0)));

		assert ((c1+c2).colorAreClose(color(6.0, 9.0, 12.0)));
		assert ((c1-c2).colorAreClose(color(-4.0, -5.0, -6.0)));
		assert ((c1*c2).colorAreClose(color(5.0, 14.0, 27.0)));

		assert ((c1*2.0).colorAreClose(color(2.0, 4.0, 6.0)));
		assert ((3.0*c1).colorAreClose(color(3.0, 6.0, 9.0)));
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

	bool validCoordinates(int x, int y){
		return x>=0 && x<width && y>=0 && y<height;
	}

	int pixelOffset(int x, int y){
		return y*width + x;
	}

	color getPixel(int x, int y){
		assert (validCoordinates(x, y));
		return pixels[pixelOffset(x, y)];
	}

	void setPixel(int x, int y, color c){
		assert (validCoordinates(x, y));
		pixels[pixelOffset(x, y)] = c;
	}

    unittest{
        HDRImage img = new HDRImage(7,4);

		assert (img.validCoordinates(0, 0)); 
		assert (img.validCoordinates(6, 3));
		assert (! img.validCoordinates(-1, 0));
		assert (! img.validCoordinates(0, -1));
		assert (! img.validCoordinates(7, 0));
		assert (! img.validCoordinates(0, 4));

		assert (img.pixelOffset(3, 2) == 17);
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
	c1.stampa();
	c2.stampa();
	write("C1*2: ");
	(c1*2).stampa();
	
	color c3 = {3e-6, 0, 0};
	writeln(c1.colorAreClose(c1+c3));
}