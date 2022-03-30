import std.stdio;
import std.conv;
import std.math;
import std.file;
//import std.exception;
import core.exception;
import std.array;
import std.string;
import std.range;
import std.system;
import std.bitmanip;
import std.algorithm;

bool areClose(float x, float y, float epsilon=1e-5){
	return abs(x-y) < epsilon;
}

float clamp(float x){
	return x/(1.0+x);
}

ubyte[] readLine(ubyte[] stream, uint startingPosition)
in(startingPosition < stream.length, "Range error when reading a line."){
	ubyte[] line;

	for(uint i=startingPosition; i<stream.length; i++){
		line ~= stream[i];
		if(stream[i] == 10) break;
	}

	return line;
}

int[2] parseImgSize(ubyte[] imgSize){
	ubyte[][] dimensions = imgSize.split(10);
	if(dimensions.length != 2){
		throw new core.exception.RangeError("Invalid number of dimensions.");
	}

	string widthArray;
	for(uint j=0; j<dimensions[][0].length; j++){
		widthArray ~= to!string(dimensions[0][j]);
	}

	string heightArray;
	for(uint j=0; j<dimensions[][1].length; j++){
		heightArray ~= to!string(dimensions[1][j]);
	}

	int w = -1, h = -1;
	try{
		w = to!int(widthArray);
		h = to!int(heightArray);
		if(w < 0 || h < 0){
			throw new object.Exception("Invalid width and/or height: they must be non negative.");
		}
	}
	catch(std.conv.ConvException exc){
		writeln("Invalid width and/or height: they must be int.");
	}
	catch(core.exception.RangeError exc){
		writeln(exc.msg);
	}
	catch(object.Exception exc){
		writeln(exc.msg);
	}

	return [w, h];
}

float parseEndiannessLine(ubyte[] endiannessLine){
	string endiannessArray;
	for(uint j=0; j<endiannessLine.length; j++){
		endiannessArray ~= to!string(endiannessLine[j]);
	}

	float endianness;
	try{
		endianness = to!float(endiannessArray);
		if(areClose(endianness,0,1e-20)){
			throw new object.Exception("Endianness cannot be too close to zero.");
		}
	}
	catch(std.conv.ConvException exc){
		writeln("Invalid endianness: it must be a float.");
	}
	catch(object.Exception exc){
		writeln(exc.msg);
	}

	return endianness;
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

	bool colorIsClose(color c){
		return areClose(r, c.r) && areClose(g, c.g) && areClose(b, c.b);
	}

	float luminosity(){
		return (max(r, g, b) + min(r, g, b)) / 2.0;
	}

	unittest{
		color c1 = {1.0, 2.0, 3.0}, c2 = {5.0, 7.0, 9.0};

		assert (c1.colorIsClose(color(0.999999,2.0,3.0)));

		assert ((c1+c2).colorIsClose(color(6.0, 9.0, 12.0)));
		assert ((c1-c2).colorIsClose(color(-4.0, -5.0, -6.0)));
		assert ((c1*c2).colorIsClose(color(5.0, 14.0, 27.0)));

		assert ((c1*2.0).colorIsClose(color(2.0, 4.0, 6.0)));
		assert ((3.0*c1).colorIsClose(color(3.0, 6.0, 9.0)));
		
		color c3 = {9.0, 5.0, 7.0};
		assert(areClose(2.0, c1.luminosity()));
		assert(areClose(7.0, c3.luminosity()));
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

	this(ubyte[] stream){
		/*++i; // incremento perché i è sullo \n

		if(endiannessLittle){
			for(uint j=0; j<width*height; j++){
				reverse(stream[i..i+12]);
				pixels[j].b = *cast(float*)(&stream[i]);
				pixels[j].g = *cast(float*)(&stream[i+4]);
				pixels[j].r = *cast(float*)(&stream[i+8]);
				i += 12;
			}
		}
		else{
			for(uint j=0; j<width*height; j++){
				pixels[j].r = *cast(float*)(&stream[i]);
				pixels[j].g = *cast(float*)(&stream[i+4]);
				pixels[j].b = *cast(float*)(&stream[i+8]);
				i += 12;
			}
		}*/
	}

	this(string fileName){
		ubyte[] stream = cast(ubyte[])fileName.read;
		int streamPosition = 0;

		ubyte[] magic = stream.readLine(streamPosition);
		if(magic != [80,70,10]){
			throw new Exception(format("Invalid magic: %s.", magic));
		}
		streamPosition += magic.length;

		ubyte[] imgSize = stream.readLine(streamPosition);
		int[2] size = parseImgSize(imgSize);
		this(size[0], size[1]);
		streamPosition += imgSize.length;

		ubyte[] endiannessLine = stream.readLine(streamPosition);
		float endianness = parseEndiannessLine(endiannessLine);

		if(12*width*height != stream.length-streamPosition){
			throw new Exception(format("Expected %s pixels", width*height));
		}
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

	void writePFM(Endian endianness = Endian.littleEndian){
		float endiannessStr;
		if(endianness == Endian.bigEndian){
			endiannessStr = 1.0;
		} 
		else{
			endiannessStr = -1.0;
		}

		Appender!(ubyte[]) pfm = appender!(ubyte[]);
		pfm.put(cast(ubyte[])("PF\n"~to!string(width)~" "~to!string(height)~"\n"~to!string(endiannessStr)~"\n"));

		color col;
		for(int i=height-1; i>-1; i--){
			for(int j=0; j<width; j++){
				col = getPixel(j, i);
				if(endianness == Endian.bigEndian){
					pfm.append!(uint, Endian.bigEndian)(*cast(int*)(&col.r));
					pfm.append!(uint, Endian.bigEndian)(*cast(int*)(&col.g));
					pfm.append!(uint, Endian.bigEndian)(*cast(int*)(&col.b));
				}
				else{
					pfm.append!(uint, Endian.littleEndian)(*cast(int*)(&col.r));
					pfm.append!(uint, Endian.littleEndian)(*cast(int*)(&col.g));
					pfm.append!(uint, Endian.littleEndian)(*cast(int*)(&col.b));
				}
			}
		}
		writeln(pfm); 
	}

	float averageLuminosity(float delta=1e-10){
		float lumSum = 0.0;
        foreach(p; pixels[]){
            lumSum += log10(delta+p.luminosity());
		}
        return pow(10, lumSum/pixels.length);
	}

	void normalizeImage(float factor, float luminosity = NaN(0x3FFFFF)){
		if(luminosity.isNaN()){
			luminosity = averageLuminosity();
		}
		for(int i=0; i<pixels.length; i++){
			pixels[i] = pixels[i]*(factor/luminosity);
		}
	}
	
	void clampImage(){
		for(int i=0; i<pixels.length; i++){
			pixels[i].r = clamp(pixels[i].r);
			pixels[i].g = clamp(pixels[i].g);
			pixels[i].b = clamp(pixels[i].b);
		}
	}

	unittest{
        HDRImage img = new HDRImage(7,4);

		assert (img.validCoordinates(0, 0)); 
		assert (img.validCoordinates(6, 3));
		assert (!img.validCoordinates(-1, 0));
		assert (!img.validCoordinates(0, -1));
		assert (!img.validCoordinates(7, 0));
		assert (!img.validCoordinates(0, 4));

		assert (img.pixelOffset(3, 2) == 17);
    }

	unittest{
		HDRImage img = new HDRImage(2,1);
		color c1 = {5.0, 10.0, 15.0}, c2 = {500.0, 1000.0, 1500.0};
		img.setPixel(0, 0, c1);
		img.setPixel(1, 0, c2);
		
		writeln(img.averageLuminosity(0.0));
		assert(areClose(100.0, img.averageLuminosity(0.0)));
		
		color c3 = {0.5e2, 1.0e2, 1.5e2}, c4 = {0.5e4, 1.0e4, 1.5e4};
		img.normalizeImage(1000.0, 100.0);
		assert(img.getPixel(0, 0).colorIsClose(c3));
		assert(img.getPixel(1, 0).colorIsClose(c4));
	}

	unittest{
		HDRImage img = new HDRImage(2,1);
		
		color c1 = {0.5e1, 1.0e1, 1.5e1}, c2 = {0.5e3, 1.0e3, 1.5e3};
		img.setPixel(0, 0, c1);
		img.setPixel(1, 0, c2);
		img.clampImage();
		
		// Check RGB boundaries
		foreach(pixel; img.pixels){
			assert(pixel.r >= 0 && pixel.r <= 1);
			assert(pixel.g >= 0 && pixel.g <= 1);
			assert(pixel.b >= 0 && pixel.b <= 1);
		}
	}
}

void main(string[] args){ 
	if(args.length != 3){
		writeln("Passare le dimensioni dell'immagine");
		return;
	}

	int w = to!int(args[1]);
	int h = to!int(args[2]);
	HDRImage image = new HDRImage(w,h);

	color c1 = {0,10,2};
	color c2 = {-2,0,1};
	color c3 = {12.3, 0, 0};

	image.setPixel(1, 0, c1);
	image.setPixel(1, 1, c2);
	image.setPixel(0, 1, c3);
	image.writePFM();

	float lum, fac=1.0;
	image.normalizeImage(fac, lum);
}