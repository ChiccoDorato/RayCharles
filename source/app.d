import std.stdio;
import std.conv;
import std.math;
import std.array;
import std.system;
import std.format;
import std.utf;
import std.algorithm;

bool areClose(float x, float y, float epsilon=1e-5){
	return abs(x-y) < epsilon;
}

float dClamp(float x){ //(x: float) -> float: in python? what's that
    return x / float(1 + x);
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

	string colorToString(){
		return "<r: "~to!string(r)~", g: "~to!string(g)~", b: "~to!string(b)~">";
	}

	bool colorAreClose(color c){
		return areClose(r, c.r) && areClose(g, c.g) && areClose(b, c.b);
	}

	float luminosity(){
		return (max(r, g, b) + min(r, g, b)) / 2.0;
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

	/*this(file){

	}*/

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

	void writePFM(Endian endianness = Endian.littleEndian){
		Appender!string pfm = appender!string;
		float endiannessStr;
		if(endianness == Endian.littleEndian){
			endiannessStr = -1.0;
		} 
		else{
			endiannessStr = 1.0;
		}
		pfm.put(toUTF32("PF\n"~to!string(width)~" "~to!string(height)~"\n"~to!string(endiannessStr)~"\n")); 
		color col;
		for(int i=height-1; i>-1; i--){
			for(int j=0; j<width; j++){
				col = getPixel(j, i);
				pfm.put(toUTF32(to!string(col.r)));
				pfm.put(toUTF32(to!string(col.g)));
				pfm.put(toUTF32(to!string(col.b)));}
			}
		writeln(pfm); 
	}

	float averageLuminosity(float delta=1e-10){
		float lumsum = 0.0;
        foreach(p; pixels[]){
            lumsum += log10(delta + p.luminosity());
		}
        return pow(10, lumsum / (pixels.length));
		}


	void normalizeImage(float factor, float luminosity){
		if(luminosity!>0 && luminosity!<0 && luminosity!=0){
			luminosity = averageLuminosity();
			//luminosity ?? averageLuminosity(); // Tipi opzionali not found yet
		}
		for(int i=0; i<pixels.length; i++){
			pixels[i] = pixels[i]*(factor/luminosity);
		}
	}

	 void clampImage(){
        for(int i=0; i< pixels.length; i++){
            pixels[i].r = dClamp(pixels[i].r);
            pixels[i].g = dClamp(pixels[i].g);
            pixels[i].b = dClamp(pixels[i].b);
		}
	}

}
	/*unittest{
		assert(toUTF8!string(11) == [0b00001011]);
		assert(to!string(12.375).toUTF32.equal([0b01000001010001100000000000000000]));
		}*/
    /*
	unittest{
        HDRImage img = new HDRImage(7,4);

		assert (img.validCoordinates(0, 0)); 
		assert (img.validCoordinates(6, 3));
		assert (! img.validCoordinates(-1, 0));
		assert (! img.validCoordinates(0, -1));
		assert (! img.validCoordinates(7, 0));
		assert (! img.validCoordinates(0, 4));

		assert (img.pixelOffset(3, 2) == 17);
    }*/

	unittest
	{ // Testing luminosity()
    color col1 = {1.0, 2.0, 3.0};
    color col2 = {9.0, 5.0, 7.0};

    assert(areClose(2.0, col1.luminosity()));
    assert(areClose(7.0, col2.luminosity()));
	}

	unittest
	{ // Testing averageLuminosity()
	HDRImage img1 = new HDRImage(2,1);
	color c1 = {5.0,10.0,15.0};
	color c2 = {500.0, 1000.0, 1500.0};
	img1.setPixel(0,0, c1 );
	img1.setPixel(1,0, c2);

	writeln(img1.averageLuminosity(0.0));
	assert(areClose(100.0, img1.averageLuminosity(0.0)));
	}
	
	unittest
	{ // Testing normalizeImage
    HDRImage img2 = new HDRImage(2,1);

	color c1 = {5.0,10.0,15.0};
	color c2 = {500.0, 1000.0, 1500.0};
	img2.setPixel(0,0, c1 );
	img2.setPixel(1,0, c2);

	color c3 = {0.5e2, 1.0e2, 1.5e2};
	color c4 = {0.5e4, 1.0e4, 1.5e4};
    img2.normalizeImage(1000.0,100.0);
    assert(img2.getPixel(0, 0).colorAreClose(c3));
    assert(img2.getPixel(1, 0).colorAreClose(c4));
	}

	unittest
	{// Testing clumpImage
	HDRImage img3 = new HDRImage(2,1);

	color c1 = {0.5e1, 1.0e1, 1.5e1};
	color c2 = {0.5e3, 1.0e3, 1.5e3};
    img3.setPixel(0, 0, c1);
    img3.setPixel(1, 0, c2);

    img3.clampImage();

    	// Check RGB boundaries
		foreach(pixel;img3.pixels){
			assert(pixel.r >= 0 && pixel.r <= 1);
			assert(pixel.g >= 0 && pixel.g <= 1);
			assert(pixel.b >= 0 && pixel.b <= 1);
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

	color c3 = {3e-6, 0, 0};
	writeln(c1.colorAreClose(c1+c3));

	image.setPixel(to!int(w/2),0,c1);
	image.setPixel(to!int(w/2),1,c2);
	image.setPixel(0,to!int(h-1),c3);
	image.writePFM();
	//writeln(c1.luminosity());
	float lum;
	float fac=1.0;
	image.normalizeImage(fac, lum);
}