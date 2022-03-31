import std.stdio;
import std.conv;
import std.math;
import std.file;
import std.exception;
import core.exception;
import std.array;
import std.string;
import std.range;
import std.system;
import std.bitmanip;
import std.algorithm;

struct parameters{
	string inputPFMFile, outputPNGFile;
	float factor = 0.2, gamma = 1.0;

	@disable this();

	this(string[] args){
		if(args.length != 5){
			throw new Exception("Usage: executable inputPFMFile factor gamma outputPNGFile");
		}

		inputPFMFile = args[1];
		try{
			factor = to!float(args[2]);
		}
		catch(std.conv.ConvException exc){
			throw new std.conv.ConvException(format("Invalid factor [%s]: it must be a float.", args[2]));
		}
		try{
			gamma = to!float(args[3]);
		}
		catch(std.conv.ConvException exc){
			throw new std.conv.ConvException(format("Invalid gamma %s: it must be a float.", args[3]));
		}
		outputPNGFile = args[4];
	}
}

bool areClose(float x, float y, float epsilon=1e-5){
	return abs(x-y) < epsilon;
}

float clamp(float x){
	return x/(1.0+x);
}

ubyte[] readLine(ubyte[] stream, uint startingPosition){
	ubyte[] line;
	for(uint i=startingPosition; i<stream.length; i++){
		line ~= stream[i];
		if(stream[i] == 10) break;
	}
	return line;
}

unittest{
	ubyte[] line = [72,101,108,108,111,10,119,111,114,108,100];
	assert(readLine(line, 0) == [72,101,108,108,111,10]);
	assert(readLine(line, 6) == [119,111,114,108,100]);
	assert(line.readLine(11) == []);
}

int[2] parseImgSize(ubyte[] imgSize)
in{
	if(imgSize.length == 0){
		throw new Exception(format("%s is an empty array.", imgSize));
	}
}
do{
	ubyte[][] dimensions = imgSize.split(32);
	if(dimensions.length != 2){
		throw new Exception("Invalid number of dimensions.");
	}
	if(dimensions[][0].length == 0 || dimensions[][1].length == 0){
		throw new Exception("Invalid number of dimensions.");
	}

	// Se ASCII esteso? Conversione a char[] fallisce con tipo std.utf.UTFException. Va controllato? Temo di sì.
	char[] widthArray = cast(char[])(dimensions[][0]);
	char[] heightArray = cast(char[])(dimensions[1][0..$-1]);
	if(dimensions[1][$-1] != 10){
		heightArray ~= cast(char)(dimensions[1][$-1]);
	}

	try{
		int w = to!int(widthArray);
		int h = to!int(heightArray);
		if(w < 0 || h < 0){
			throw new object.Exception("Invalid width and/or height: they must be non negative.");
		}
		return [w,h];
	}
	catch(std.conv.ConvException exc){
		throw new std.conv.ConvException("Invalid width and/or height: they must be int.");
	}
}

unittest{
	ubyte[] dimensionsLine = [51,32,50,10], dimensionsOnlyLine = [45,48,32,55,48];
	assert(parseImgSize(dimensionsLine) == [3,2]);
	assert(parseImgSize(dimensionsOnlyLine) == [0,70]);

	ubyte[] floatDimensions = [50,46,32,51], negativeDimensions = [45,50,32,52];
	ubyte[] manyDimensions = [53,32,53,32,49];
	assertThrown!ConvException(parseImgSize(floatDimensions));
	assertThrown!Exception(parseImgSize(negativeDimensions));
	assertThrown!Exception(parseImgSize(manyDimensions));
}

float parseEndiannessLine(ubyte[] endiannessLine)
in{
	if(endiannessLine.length == 0){
		throw new Exception(format("%s is an empty array.", endiannessLine));
	}
}
do{
	// Sempre problema se ASCII esteso.
	char[] endiannessArray = cast(char[])(endiannessLine[0..$-1]);
	if(endiannessLine[$-1] != 10){
		endiannessArray ~= cast(char)(endiannessLine[$-1]);
	}

	try{
		float endiannessValue = to!float(endiannessArray);
		if(areClose(endiannessValue,0,1e-20)){
			throw new object.Exception("Endianness cannot be too close to zero.");
		}
		return endiannessValue;
	}
	catch(std.conv.ConvException exc){
		throw new std.conv.ConvException("Invalid endianness: it must be a float.");
	}
}

unittest{
	ubyte[] positiveNumber = [48,55,46,50,10], negativeNumber = [45,56,49];
	assert(areClose(parseEndiannessLine(positiveNumber), 7.2));
	assert(areClose(parseEndiannessLine(negativeNumber), -81));

	ubyte[] zero = [48,46,48,48], epsilon = [46,48,48,48,48,48,48,48,48,48,48,48,50,10];
	ubyte[] notNumber = [50,60,70,10];
	assertThrown!Exception(parseEndiannessLine(zero));
	assertNotThrown(parseEndiannessLine(epsilon));
	assertThrown!ConvException(parseEndiannessLine(notNumber));

	ubyte[] emptyArray = [];
	assertThrown!Exception(parseEndiannessLine(emptyArray));
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
}

unittest{
	color c1 = {1.0, 2.0, 3.0}, c2 = {5.0, 7.0, 9.0};

	assert(c1.colorIsClose(color(0.999999,2.0,3.0)));

	assert((c1+c2).colorIsClose(color(6.0, 9.0, 12.0)));
	assert((c1-c2).colorIsClose(color(-4.0, -5.0, -6.0)));
	assert((c1*c2).colorIsClose(color(5.0, 14.0, 27.0)));

	assert((c1*2.0).colorIsClose(color(2.0, 4.0, 6.0)));
	assert((3.0*c1).colorIsClose(color(3.0, 6.0, 9.0)));
		
	color c3 = {9.0, 5.0, 7.0};
	assert(areClose(2.0, c1.luminosity()));
	assert(areClose(7.0, c3.luminosity()));
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
		int streamPosition = 0;

		ubyte[] magic = stream.readLine(streamPosition);
		if(magic != [80,70,10]){
			throw new Exception(format("Invalid magic: %s.", magic));
		}
		streamPosition += magic.length;

		ubyte[] imgSize = stream.readLine(streamPosition);
		int[2] size = parseImgSize(imgSize);
		streamPosition += imgSize.length;

		ubyte[] endiannessLine = stream.readLine(streamPosition);
		float endiannessValue = parseEndiannessLine(endiannessLine);
		streamPosition += endiannessLine.length;

		if(12*size[0]*size[1] != stream.length-streamPosition){
			throw new Exception(format("Expected %s pixels", size[0]*size[1]));
		}
		this(size[0], size[1]);

		if(endiannessValue < 0){
			for(auto j=pixels.length-1; j>-1; j--){
				reverse(stream[j..j+12]);
				pixels[j].b = *cast(float*)(&stream[j-12]);
				pixels[j].g = *cast(float*)(&stream[j-8]);
				pixels[j].r = *cast(float*)(&stream[j-4]);
			}
		}
		else{
			for(auto j=pixels.length-1; j>-1; j--){
				pixels[j].r = *cast(float*)(&stream[j-12]);
				pixels[j].g = *cast(float*)(&stream[j-8]);
				pixels[j].b = *cast(float*)(&stream[j-4]);
			}
		}
	}

	this(string fileName){
		ubyte[] stream = cast(ubyte[])(fileName.read);
		this(stream);
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

	ubyte[] writePFM(Endian endianness = Endian.littleEndian){
		string endiannessStr;
		if(endianness == Endian.bigEndian){
			endiannessStr = "1.0";
		} 
		else{
			endiannessStr = "-1.0";
		}

		Appender!(ubyte[]) pfm = appender!(ubyte[]);
		pfm.put(cast(ubyte[])("PF\n"~to!string(width)~" "~to!string(height)~"\n"~endiannessStr~"\n"));

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
		return pfm.data;
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
}

unittest{
        HDRImage img = new HDRImage(7,4);

		assert(img.validCoordinates(0, 0)); 
		assert(img.validCoordinates(6, 3));
		assert(!img.validCoordinates(-1, 0));
		assert(!img.validCoordinates(0, -1));
		assert(!img.validCoordinates(7, 0));
		assert(!img.validCoordinates(0, 4));

		assert(img.pixelOffset(3, 2) == 17);
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
	HDRImage img = new HDRImage(2, 1);
		
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

/*unittest{
	ubyte[] referenceBytes = [
	0x50, 0x46, 0x0a, 0x33, 0x20, 0x32, 0x0a, 0x2d, 0x31, 0x2e, 0x30, 0x0a,
	0x00, 0x00, 0xc8, 0x42, 0x00, 0x00, 0x48, 0x43, 0x00, 0x00, 0x96, 0x43,
	0x00, 0x00, 0xc8, 0x43, 0x00, 0x00, 0xfa, 0x43, 0x00, 0x00, 0x16, 0x44,
	0x00, 0x00, 0x2f, 0x44, 0x00, 0x00, 0x48, 0x44, 0x00, 0x00, 0x61, 0x44,
	0x00, 0x00, 0x20, 0x41, 0x00, 0x00, 0xa0, 0x41, 0x00, 0x00, 0xf0, 0x41,
	0x00, 0x00, 0x20, 0x42, 0x00, 0x00, 0x48, 0x42, 0x00, 0x00, 0x70, 0x42,
	0x00, 0x00, 0x8c, 0x42, 0x00, 0x00, 0xa0, 0x42, 0x00, 0x00, 0xb4, 0x42];
	HDRImage img = new HDRImage(referenceBytes);
	img.setPixel(1,1,color(10,20,30));
	writeln(img.writePFM);
	writeln(referenceBytes);
}*/

unittest{
	string[2] files = ["reference_le.pfm", "reference_be.pfm"];

	foreach(string fileName; files){
		HDRImage img = new HDRImage(files[1]);

		assert(img.width == 3);
		assert(img.height == 2);

		//assert(img.getPixel(0,0).colorIsClose(color(1.0e1, 2.0e1, 3.0e1)));
	}
}

void main(string[] args){ 
	parameters* params;
	try{
		params = new parameters(args);
	}
	catch(Exception exc){
		writeln("Error! ", exc.msg);
		return;
	}

	HDRImage image = new HDRImage(params.inputPFMFile);
	writeln("File "~params.inputPFMFile~" has been read from disk.");

	image.normalizeImage(params.factor);
	image.clampImage;

	// Scrivere LDR: image.writeLDR(params.outputPNGFile,"PNG",params.gamma);
	writeln("File "~params.outputPNGFile~" has been read from disk.");
}