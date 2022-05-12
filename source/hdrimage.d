module hdrimage;

import imageformats.png;
import std.algorithm : endsWith, max, min;
import std.array : Appender, appender, split;
import std.bitmanip;
import std.conv;
import std.exception : assertThrown, assertNotThrown, enforce;
import std.file : read;
import std.format : format;
import std.math : abs, isNaN, log10, NaN, pow, round;
import std.stdio : File, writeln;
import std.system : endian;

bool areClose(in float x, in float y, in float epsilon = 1e-5)
{
	return abs(x - y) < epsilon;
}

struct Color
{
	float r = 0.0, g = 0.0, b = 0.0;

	Color opBinary(string op)(in Color rhs) const if (op == "+" || op == "-" || op == "*")
	{
		mixin("return Color(r"~op~"rhs.r, g"~op~"rhs.g, b"~op~"rhs.b);");
	}

	Color opBinary(string op)(in float alfa) const if (op == "*")
	{
		mixin("return Color(r*alfa, g*alfa, b*alfa);");
	}

	Color opBinaryRight(string op)(in float alfa) const if (op == "*")
	{
		mixin("return Color(alfa*r, alfa*g, alfa*b);");
	}

	string colorToString() const
	{
		return "<r: "~to!string(r)~", g: "~to!string(g)~", b: "~to!string(b)~">";
	}

	bool colorIsClose(in Color c) const
	{
		return areClose(r, c.r) && areClose(g, c.g) && areClose(b, c.b);
	}

	float luminosity() const
	{
		return (max(r, g, b) + min(r, g, b)) / 2.0;
	}
}

unittest
{
	Color c1 = {1.0, 2.0, 3.0}, c2 = {5.0, 7.0, 9.0};

	assert(c1.colorIsClose(Color(0.999999, 2.0, 3.0)));

	assert((c1 + c2).colorIsClose(Color(6.0, 9.0, 12.0)));
	assert((c1 - c2).colorIsClose(Color(-4.0, -5.0, -6.0)));
	assert((c1 * c2).colorIsClose(Color(5.0, 14.0, 27.0)));

	assert((c1 * 2.0).colorIsClose(Color(2.0, 4.0, 6.0)));
	assert((3.0 * c1).colorIsClose(Color(3.0, 6.0, 9.0)));
		
	Color c3 = {9.0, 5.0, 7.0};
	assert(areClose(2.0, c1.luminosity));
	assert(areClose(7.0, c3.luminosity));
}

class InvalidPFMFileFormat : Exception
{
    this(string msg, string file = __FILE__, size_t line = __LINE__)
    {
        super(msg, file, line);
    }
}

ubyte[] readLine(in ubyte[] stream, uint startingPosition)
{
	ubyte[] line;
	for (uint i = startingPosition; i < stream.length; ++i)
	{
		line ~= stream[i];
		if (stream[i] == 10) break;
	}
	return line;
}

unittest
{
	ubyte[] line = [72, 101, 108, 108, 111, 10, 119, 111, 114, 108, 100];
	assert(readLine(line, 0) == [72, 101, 108, 108, 111, 10]);
	assert(readLine(line, 6) == [119, 111, 114, 108, 100]);
	assert(line.readLine(11) == []);
}

int[2] parseImgSize(in ubyte[] imgSize)
{
	enforce!InvalidPFMFileFormat(imgSize.length > 0, "image dimensions are not indicated");

	const ubyte[][] dimensions = imgSize.split(32);
	if (dimensions.length != 2)
		throw new InvalidPFMFileFormat("invalid number of dimensions");
	if (dimensions[][0].length == 0 || dimensions[][1].length == 0)
		throw new InvalidPFMFileFormat("invalid number of dimensions");

	// Se ASCII esteso? Conversione a char[] fallisce con tipo std.utf.UTFException.
	// Va controllato? Temo di sì.
	char[] widthArray = cast(char[])(dimensions[][0]);
	char[] heightArray = cast(char[])(dimensions[1][0 .. $-1]);

	try
	{
		int w = to!int(widthArray);
		int h = to!int(heightArray);
		if (w < 0 || h < 0)
			throw new InvalidPFMFileFormat("invalid width and/or height (negative)");
		return [w, h];
	}
	catch (ConvException exc)
		throw new InvalidPFMFileFormat("invalid width and/or height (not an integer)");
}

unittest
{
	ubyte[] dimensionsLine = [51, 32, 50, 10];
	assert(parseImgSize(dimensionsLine) == [3, 2]);

	ubyte[] emptyArray;
	assertThrown!InvalidPFMFileFormat(parseImgSize(emptyArray));

	ubyte[] floatDimensions = [50, 46, 32, 51, 10], negativeDimensions = [45, 50, 32, 52, 10];
	ubyte[] manyDimensions = [53, 32, 53, 32, 49, 10];
	assertThrown!InvalidPFMFileFormat(parseImgSize(floatDimensions));
	assertThrown!InvalidPFMFileFormat(parseImgSize(negativeDimensions));
	assertThrown!InvalidPFMFileFormat(parseImgSize(manyDimensions));
}

float parseEndiannessLine(in ubyte[] endiannessLine)
{
	enforce!InvalidPFMFileFormat(endiannessLine.length > 0, "endianness is not indicated");
	// Sempre problema se ASCII esteso.
	char[] endiannessArray = cast(char[])(endiannessLine[0 .. $-1]);

	try
	{
		float endiannessValue = to!float(endiannessArray);
		if (areClose(endiannessValue, 0, 1e-20))
			throw new InvalidPFMFileFormat("endianness cannot be too close to zero");
		return endiannessValue;
	}
	catch (ConvException exc)
		throw new InvalidPFMFileFormat("invalid endianness (not a floating point)");
}

unittest
{
	ubyte[] positiveNumber = [48, 55, 46, 50, 10], negativeNumber = [45, 56, 49, 10];
	assert(areClose(parseEndiannessLine(positiveNumber), 7.2));
	assert(areClose(parseEndiannessLine(negativeNumber), -81));

	ubyte[] emptyArray;
	assertThrown!InvalidPFMFileFormat(parseEndiannessLine(emptyArray));

	ubyte[] zero = [48, 46, 48, 48, 10], epsilon = [46, 48, 48, 48, 48, 48, 48, 48, 48, 50, 10];
	ubyte[] notNumber = [50, 60, 70, 10];
	assertThrown!InvalidPFMFileFormat(parseEndiannessLine(zero));
	assertNotThrown(parseEndiannessLine(epsilon));
	assertThrown!InvalidPFMFileFormat(parseEndiannessLine(notNumber));
}

float readFloat(in ubyte[] stream, int startingPosition, in float endiannessValue)
in (
	stream.length - startingPosition > 3,
	format("Less than 4 bytes in %s from index %s", stream, startingPosition)
	)
in (!areClose(endiannessValue, 0, 1e-20), "Endianness cannot be too close to zero")
{
	uint nativeValue = *cast(uint*)(stream.ptr + startingPosition);
	if (endian == Endian.littleEndian && endiannessValue > 0)
		nativeValue = nativeValue.swapEndian;
	if (endian == Endian.bigEndian && endiannessValue < 0)
		nativeValue = nativeValue.swapEndian;
	return *cast(float*)(&nativeValue);
}

unittest
{
	ubyte[] test = [30, 20, 70, 55, 108, 99, 10, 7];
	ubyte[] check = [55, 70, 20, 30, 7, 10, 99, 108];
	assert(test.readFloat(0,-1) == check.readFloat(0,1));
	assert(test.readFloat(4,-1) == check.readFloat(4,1));
}

float clamp(float x)
{
	return x / (1.0 + x);
}

class HDRImage
{
	immutable int width, height;
	Color[] pixels;
	
	this(in int w, in int h)
	{
		width = w;
		height = h;
		pixels.length = width * height;
	}

	this(in ubyte[] stream)
	{
		int streamPosition = 0;

		immutable ubyte[] magic = cast(immutable(ubyte[]))(stream.readLine(streamPosition));
		enforce!InvalidPFMFileFormat(magic == [80, 70, 10], "invalid magic");
		streamPosition += magic.length;

		immutable ubyte[] imgSize = cast(immutable(ubyte[]))(stream.readLine(streamPosition));
		immutable int[2] size = cast(immutable(int[2]))(parseImgSize(imgSize));
		streamPosition += imgSize.length;

		immutable ubyte[] endiannessLine = cast(immutable(ubyte[]))(stream.readLine(streamPosition));
		immutable float endiannessValue = cast(immutable(float))(parseEndiannessLine(endiannessLine));
		streamPosition += endiannessLine.length;

		enforce!InvalidPFMFileFormat(
			12 * size[0] * size[1] == stream.length - streamPosition,
			format("expected [%s] pixels", size[0]*size[1])
			);
		this(size[0], size[1]);

		float red, green, blue;
		int posPixel;
		for (int i = 0; i < height; ++i)
		{
			for (int j = 0; j < width; ++j)
			{
				posPixel = streamPosition + 12 * this.pixelOffset(j, height - 1 - i);
				red = readFloat(stream, posPixel, endiannessValue);
				green = readFloat(stream, posPixel + 4, endiannessValue);
				blue = readFloat(stream, posPixel + 8, endiannessValue);
				this.setPixel(j, i, Color(red, green, blue));
			}
		}
	}

	this(in string fileName)
	{
		immutable(ubyte[]) stream = cast(immutable(ubyte[]))(fileName.read);
		this(stream);
	}

	bool validCoordinates(in int x, in int y) const
	{
		return x >= 0 && x < width && y >= 0 && y < height;
	}

	int pixelOffset(in int x, in int y) const
	{
		return y * width + x;
	}

	Color getPixel(in int x, in int y) const
	in (validCoordinates(x, y))
	{
		return pixels[pixelOffset(x, y)];
	}

	void setPixel(in int x, in int y, Color c)
	in (validCoordinates(x, y))
	{
		pixels[pixelOffset(x, y)] = c;
	}

	ubyte[] writePFM(in Endian endianness = Endian.littleEndian) const
	{
		string endiannessStr;
		if (endianness == Endian.bigEndian) endiannessStr = "1.0";
		else endiannessStr = "-1.0";

		Appender!(ubyte[]) pfm = appender!(ubyte[]);
		pfm.put(cast(ubyte[])("PF\n"~to!string(width)~" "~to!string(height)~"\n"~endiannessStr~"\n"));

		Color col;
		for (int i = height - 1; i > -1; --i)
		{
			for (int j = 0; j < width; ++j)
			{
				col = getPixel(j, i);
				if (endianness == Endian.bigEndian)
				{
					pfm.append!(uint, Endian.bigEndian)(*cast(uint*)(&col.r));
					pfm.append!(uint, Endian.bigEndian)(*cast(uint*)(&col.g));
					pfm.append!(uint, Endian.bigEndian)(*cast(uint*)(&col.b));
				}
				else
				{
					pfm.append!(uint, Endian.littleEndian)(*cast(uint*)(&col.r));
					pfm.append!(uint, Endian.littleEndian)(*cast(uint*)(&col.g));
					pfm.append!(uint, Endian.littleEndian)(*cast(uint*)(&col.b));
				}
			}
		}
		return pfm.data;
	}

	void writePFMFile(string fileName, in Endian endianness = Endian.littleEndian) const
	{
		if (fileName == [])
		{
			writeln("WARNING: file not written because no name was provided");
			return;
		}

		if (!fileName.endsWith(".pfm"))
		{
			fileName ~= ".pfm";
			writeln("WARNING: pfm file automatically renamed to ", fileName);
		}
		File file = File(fileName, "wb");
		file.rawWrite(writePFM(endianness));
	}

	void writePNG(char[] fileName, in float gamma = 1.0) const
	{
		if (fileName == [])
		{
			writeln("WARNING: png file not written because no name was provided");
			return;
		}

		ubyte[] data;
		foreach (Color c; pixels)
		{
			data ~= to!ubyte(round(255 * pow(c.r, 1 / gamma)));
			data ~= to!ubyte(round(255 * pow(c.g, 1 / gamma)));
			data ~= to!ubyte(round(255 * pow(c.b, 1 / gamma)));
		}
		if (!fileName.endsWith(".png"))
		{
			fileName ~= ".png";
			writeln("WARNING: file automatically renamed to ", fileName);
		}
		imageformats.png.write_png(fileName, width, height, data, 0);
	}

	float averageLuminosity(in float delta=1e-10) const
	{
		float lumSum = 0.0;
        foreach (p; pixels[]) lumSum += log10(delta + p.luminosity);
        return pow(10, lumSum / pixels.length);
	}

	void normalizeImage(in float factor, float luminosity = NaN(0x3FFFFF))
	{
		if (luminosity.isNaN()) luminosity = averageLuminosity();
		for (int i = 0; i < pixels.length; ++i) pixels[i] = pixels[i] * (factor / luminosity);
	}
	
	void clampImage()
	{
		for (int i = 0; i < pixels.length; ++i)
		{
			pixels[i].r = clamp(pixels[i].r);
			pixels[i].g = clamp(pixels[i].g);
			pixels[i].b = clamp(pixels[i].b);
		}
	}
}

unittest
{
	HDRImage img = new HDRImage(7,4);

	assert(img.validCoordinates(0, 0)); 
	assert(img.validCoordinates(6, 3));
	assert(!img.validCoordinates(-1, 0));
	assert(!img.validCoordinates(0, -1));
	assert(!img.validCoordinates(7, 0));
	assert(!img.validCoordinates(0, 4));

	assert(img.pixelOffset(3, 2) == 17);
}

unittest
{
	HDRImage img = new HDRImage(2,1);
	Color c1 = {5.0, 10.0, 15.0}, c2 = {500.0, 1000.0, 1500.0};
	img.setPixel(0, 0, c1);
	img.setPixel(1, 0, c2);
		
	writeln(img.averageLuminosity(0.0));
	assert(areClose(100.0, img.averageLuminosity(0.0)));
		
	Color c3 = {0.5e2, 1.0e2, 1.5e2}, c4 = {0.5e4, 1.0e4, 1.5e4};
	img.normalizeImage(1000.0, 100.0);
	assert(img.getPixel(0, 0).colorIsClose(c3));
	assert(img.getPixel(1, 0).colorIsClose(c4));
}

unittest
{
	HDRImage img = new HDRImage(2, 1);
		
	Color c1 = {0.5e1, 1.0e1, 1.5e1}, c2 = {0.5e3, 1.0e3, 1.5e3};
	img.setPixel(0, 0, c1);
	img.setPixel(1, 0, c2);
	img.clampImage();
		
	// Check RGB boundaries
	foreach (pixel; img.pixels)
	{
		assert(pixel.r >= 0 && pixel.r <= 1);
		assert(pixel.g >= 0 && pixel.g <= 1);
		assert(pixel.b >= 0 && pixel.b <= 1);
	}
}

unittest
{
	HDRImage img = new HDRImage(3,2);
	img.setPixel(0, 0, Color(1.0e1, 2.0e1, 3.0e1));
	img.setPixel(1, 0, Color(4.0e1, 5.0e1, 6.0e1));
	img.setPixel(2, 0, Color(7.0e1, 8.0e1, 9.0e1));
	img.setPixel(0, 1, Color(1.0e2, 2.0e2, 3.0e2));
	img.setPixel(1, 1, Color(4.0e2, 5.0e2, 6.0e2));
	img.setPixel(2, 1, Color(7.0e2, 8.0e2, 9.0e2));

	ubyte[] LEreferenceBytes = [
	0x50, 0x46, 0x0a, 0x33, 0x20, 0x32, 0x0a, 0x2d, 0x31, 0x2e, 0x30, 0x0a,
	0x00, 0x00, 0xc8, 0x42, 0x00, 0x00, 0x48, 0x43, 0x00, 0x00, 0x96, 0x43,
	0x00, 0x00, 0xc8, 0x43, 0x00, 0x00, 0xfa, 0x43, 0x00, 0x00, 0x16, 0x44,
	0x00, 0x00, 0x2f, 0x44, 0x00, 0x00, 0x48, 0x44, 0x00, 0x00, 0x61, 0x44,
	0x00, 0x00, 0x20, 0x41, 0x00, 0x00, 0xa0, 0x41, 0x00, 0x00, 0xf0, 0x41,
	0x00, 0x00, 0x20, 0x42, 0x00, 0x00, 0x48, 0x42, 0x00, 0x00, 0x70, 0x42,
	0x00, 0x00, 0x8c, 0x42, 0x00, 0x00, 0xa0, 0x42, 0x00, 0x00, 0xb4, 0x42];

	ubyte[] BEreferenceBytes = [
	0x50, 0x46, 0x0a, 0x33, 0x20, 0x32, 0x0a, 0x31, 0x2e, 0x30, 0x0a, 0x42,
	0xc8, 0x00, 0x00, 0x43, 0x48, 0x00, 0x00, 0x43, 0x96, 0x00, 0x00, 0x43,
	0xc8, 0x00, 0x00, 0x43, 0xfa, 0x00, 0x00, 0x44, 0x16, 0x00, 0x00, 0x44,
	0x2f, 0x00, 0x00, 0x44, 0x48, 0x00, 0x00, 0x44, 0x61, 0x00, 0x00, 0x41,
	0x20, 0x00, 0x00, 0x41, 0xa0, 0x00, 0x00, 0x41, 0xf0, 0x00, 0x00, 0x42,
	0x20, 0x00, 0x00, 0x42, 0x48, 0x00, 0x00, 0x42, 0x70, 0x00, 0x00, 0x42,
	0x8c, 0x00, 0x00, 0x42, 0xa0, 0x00, 0x00, 0x42, 0xb4, 0x00, 0x00];
	
	assert(img.writePFM == LEreferenceBytes);
	assert(img.writePFM(Endian.bigEndian) == BEreferenceBytes);
}

unittest
{
	string[2] files = ["reference_le.pfm", "reference_be.pfm"];

	foreach (string fileName; files)
	{
		HDRImage img = new HDRImage(fileName);

		assert(img.width == 3);
		assert(img.height == 2);

		assert(img.getPixel(0,0).colorIsClose(Color(1.0e1, 2.0e1, 3.0e1)));
		assert(img.getPixel(1,0).colorIsClose(Color(4.0e1, 5.0e1, 6.0e1)));
        assert(img.getPixel(2,0).colorIsClose(Color(7.0e1, 8.0e1, 9.0e1)));
        assert(img.getPixel(0,1).colorIsClose(Color(1.0e2, 2.0e2, 3.0e2)));
        assert(img.getPixel(0,0).colorIsClose(Color(1.0e1, 2.0e1, 3.0e1)));
        assert(img.getPixel(1,1).colorIsClose(Color(4.0e2, 5.0e2, 6.0e2)));
        assert(img.getPixel(2,1).colorIsClose(Color(7.0e2, 8.0e2, 9.0e2)));
	}
}