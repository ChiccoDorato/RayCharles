module hdrimage;

import colored;
import imageformats.png;
import std.algorithm : endsWith, max, min;
import std.array : appender, split;
import std.bitmanip;
import std.conv;
import std.exception : enforce;
import std.file : read;
import std.format : format, FormatSpec, formattedWrite, formatValue;
import std.math : abs, isNaN, log10, pow, round;
import std.range : isOutputRange, put;
import std.stdio : File, writeln;
import std.system : endian;

/// Verify if the difference between two floating point x and y is smaller than epsilon = 1e-5 (default)
pure nothrow @nogc @safe bool areClose(
	in float x, in float y, in float epsilon = 1e-5
	)
{
	return abs(x - y) < epsilon;
}

// ************************* Color *************************
/// Stucture representing a Color - Parameters: 3 floating point members red (r), green (g) and blue (b)
struct Color
{
	float r = 0.0, g = 0.0, b = 0.0;

	/// Return the sum (+), the difference (-) or the product (*) between two Colors
	pure nothrow @nogc @safe Color opBinary(string op)(in Color rhs) const
	if (op == "+" || op == "-" || op == "*")
	{
		return mixin("Color(r" ~ op ~ "rhs.r, g" ~ op ~ "rhs.g, b" ~ op ~ "rhs.b)");
	}

	/// Return the product between a floating point alpha on the left-hand side and a Color
	pure nothrow @nogc @safe Color opBinary(string op)(in float alfa) const
	if (op == "*")
	{
		return mixin("Color(r*alfa, g*alfa, b*alfa)");
	}

	/// Return the product between a floating point alpha on the right-hand side and a Color
	pure nothrow @nogc @safe Color opBinaryRight(string op)(in float alfa) const
	if (op == "*")
	{
		return mixin("Color(alfa*r, alfa*g, alfa*b)");
	}

// overload for +=, -= and *=.
	pure nothrow @nogc @safe ref Color opOpAssign(string op)(in Color rhs)
	if (op == "+" || op == "-" || op == "*")
    {
		this = mixin("this" ~ op ~ "rhs");
        return this;
	}

// overload for *= with a scalar.
	pure nothrow @nogc @safe ref Color opOpAssign(string op)(in float alfa)
	if (op == "*")
    {
		this = this * alfa;
        return this;
	}

	/// Return the three components of a Color in a string.
	@safe void toString(W)(ref W w, in ref FormatSpec!char fmt) const
    if (isOutputRange!(W, char))
    {
		put(w, "<");
        formatValue(w, r, fmt);
        put(w, ", ");
        formatValue(w, g, fmt);
		put(w, ", ");
        formatValue(w, b, fmt);
        put(w, ">");
    }

	/// Verify if two Colors are close by calling the fuction areClose for every component 
	pure nothrow @nogc @safe bool colorIsClose(in Color c) const
	{
		return areClose(r, c.r) && areClose(g, c.g) && areClose(b, c.b);
	}

	/// Return the luminosity of a specific Color
	pure nothrow @nogc @safe float luminosity() const
	{
		return (max(r, g, b) + min(r, g, b)) / 2.0;
	}
}

/// Fundamental colors: black (0.0, 0.0, 0.0) and white (1.0, 1.0, 1.0)
immutable black = Color(), white = Color(1.0, 1.0, 1.0);

///
unittest
{
	auto c1 = Color(1.0, 2.0, 3.0), c2 = Color(5.0, 7.0, 9.0);

	// colorIsClose
	assert(c1.colorIsClose(Color(0.999999, 2.0, 3.0)));

	// Operations sum (+), difference (-) and product (*) between two colors
	assert((c1 + c2).colorIsClose(Color(6.0, 9.0, 12.0)));
	assert((c1 - c2).colorIsClose(Color(-4.0, -5.0, -6.0)));
	assert((c1 * c2).colorIsClose(Color(5.0, 14.0, 27.0)));

	// Product of a Color with a scalar
	assert((c1 * 2.0).colorIsClose(Color(2.0, 4.0, 6.0)));
	assert((3.0 * c1).colorIsClose(Color(3.0, 6.0, 9.0)));
		
	auto c3 = Color(9.0, 5.0, 7.0);
	// luminosity
	assert(areClose(2.0, c1.luminosity));
	assert(areClose(7.0, c3.luminosity));
}

/// Class used to throw exceptions in case of compilation errors
class InvalidPFMFileFormat : Exception
{
    pure nothrow @nogc @safe this(
		string msg, string file = __FILE__, size_t line = __LINE__
		)
    {
        super(msg, file, line);
    }

	@safe void printError(in string pfmFileName)
	{
		writeln(
			format("%s: ", pfmFileName).bold,
			"Error: ".bold.red,
			format("not a pfm file, %s", msg));
	}
}

/// Read a line from an array of ubyte, given a starting position
pure nothrow @safe ubyte[] readLine(in ubyte[] stream, in uint startingPos)
{
	auto line = appender!(ubyte[]);
	for (uint i = startingPos; i < stream.length; ++i)
	{
		line.put(stream[i]);
		if (stream[i] == 10) break;
	}
	return line.data;
}

///
unittest
{
	ubyte[] line = [72, 101, 108, 108, 111, 10, 119, 111, 114, 108, 100];

	// ReadLine
	assert(readLine(line, 0) == [72, 101, 108, 108, 111, 10]);
	assert(readLine(line, 6) == [119, 111, 114, 108, 100]);
	assert(line.readLine(11) == []);
}

/// Check the width and the height of the image, throw an exception if something is wrong.
pure @safe int[2] parseImgSize(in ubyte[] imgSize)
{
	enforce!InvalidPFMFileFormat(
		imgSize.length > 0,
		"image dimensions are not indicated"
		);

	const(ubyte[][]) dimensions = imgSize.split(32);
	enforce!InvalidPFMFileFormat(
		dimensions.length == 2,
		"invalid number of dimensions"
		);
	enforce!InvalidPFMFileFormat(
		dimensions[][0].length > 0 && dimensions[][1].length > 0,
		"invalid number of dimensions"
		);

	// Se ASCII esteso - Conversione a char[] fallisce con tipo std.utf.UTFException.
	auto widthArray = cast(const(char)[])dimensions[][0];
	auto heightArray = cast(const(char)[])dimensions[1][0 .. $-1];

	try
	{
		immutable w = to!int(widthArray);
		immutable h = to!int(heightArray);
		enforce!InvalidPFMFileFormat(
			w > 0 && h > 0,
			"invalid width and/or height (non positive)"
			);
		return [w, h];
	}
	catch (ConvException exc)
		throw new InvalidPFMFileFormat(
			"invalid width and/or height (not an integer)"
			);
}

///
unittest
{
	import std.exception : assertThrown;

	ubyte[] dimensionsLine = [51, 32, 50, 10];
	// parseImgSize
	assert(parseImgSize(dimensionsLine) == [3, 2]);

	ubyte[] emptyArray;
	assertThrown!InvalidPFMFileFormat(parseImgSize(emptyArray));

	ubyte[] floatDimension = [50, 46, 32, 51, 10];
	ubyte[] zeroDimension = [52, 32, 48, 10];
	ubyte[] negativeDimension = [45, 50, 32, 52, 10];
	ubyte[] manyDimensions = [53, 32, 53, 32, 49, 10];
	assertThrown!InvalidPFMFileFormat(parseImgSize(floatDimension));
	assertThrown!InvalidPFMFileFormat(parseImgSize(zeroDimension));
	assertThrown!InvalidPFMFileFormat(parseImgSize(negativeDimension));
	assertThrown!InvalidPFMFileFormat(parseImgSize(manyDimensions));
}

/// Check if the correct Endianness is used, throw an exception if wrong.
pure @safe float parseEndiannessLine(in ubyte[] endiannessLine)
{
	enforce!InvalidPFMFileFormat(
		endiannessLine.length > 0,
		"endianness is not indicated"
		);
	// Sempre problema se ASCII esteso.
	auto endiannessArray = cast(const(char)[])(endiannessLine[0 .. $-1]);

	try
	{
		immutable endiannessValue = to!float(endiannessArray);
		if (areClose(endiannessValue, 0.0, 1e-20))
			throw new InvalidPFMFileFormat(
				"endianness cannot be too close to zero"
				);
		return endiannessValue;
	}
	catch (ConvException exc)
		throw new InvalidPFMFileFormat(
			"invalid endianness (not a floating point)"
			);
}
///
unittest
{
	import std.exception : assertThrown, assertNotThrown;

	ubyte[] positiveNumber = [48, 55, 46, 50, 10];
	ubyte[] negativeNumber = [45, 56, 49, 10];
	assert(areClose(parseEndiannessLine(positiveNumber), 7.2));
	assert(areClose(parseEndiannessLine(negativeNumber), -81));

	ubyte[] emptyArray;
	assertThrown!InvalidPFMFileFormat(parseEndiannessLine(emptyArray));

	ubyte[] zero = [48, 46, 48, 48, 10];
	ubyte[] epsilon = [46, 48, 48, 48, 48, 48, 48, 48, 48, 50, 10];
	ubyte[] notNumber = [50, 60, 70, 10];
	assertThrown!InvalidPFMFileFormat(parseEndiannessLine(zero));
	assertNotThrown(parseEndiannessLine(epsilon));
	assertThrown!InvalidPFMFileFormat(parseEndiannessLine(notNumber));
}

/// Read a floating point number from an array of ubyte.
pure float readFloat(
	in ubyte[] stream, in int startingPos, in float endiannessValue
	)
in (stream.length - startingPos > 3, "Less than 4 bytes left in the stream")
in (!areClose(endiannessValue, 0.0, 1e-20), "Endianness must differ from zero")
{
	uint nativeValue = *cast(uint*)(stream.ptr + startingPos);
	if (endian == Endian.littleEndian && endiannessValue > 0.0)
		nativeValue = nativeValue.swapEndian;
	if (endian == Endian.bigEndian && endiannessValue < 0.0)
		nativeValue = nativeValue.swapEndian;
	return *cast(float*)(&nativeValue);
}

///
unittest
{
	ubyte[] test = [30, 20, 70, 55, 108, 99, 10, 7];
	ubyte[] check = [55, 70, 20, 30, 7, 10, 99, 108];
	assert(test.readFloat(0, -1.0) == check.readFloat(0, 1.0));
	assert(test.readFloat(4, -1.0) == check.readFloat(4 ,1.0));
}

/// Return the clamped floating point number
pure nothrow @nogc @safe float clamp(float x)
in (x >= 0.0)
{
	return x / (1.0 + x);
}

// ************************* HDRImage *************************
/// Class of an High Dynamic Range Image
class HDRImage
{
	immutable int width, height;
	Color[] pixels;
	
	/// Build an HDRImage from two integers: width (w) and height (h)
	pure nothrow @safe this(in int w, in int h)
	in (w > 0 && h > 0)
	{
		width = w;
		height = h;
		pixels.length = width * height;
	}

	/// Build an HDRImage from an array of ubyte
	pure this(in ubyte[] stream)
	{
		int streamPos = 0;

		immutable ubyte[] magic = stream.readLine(streamPos);
		enforce!InvalidPFMFileFormat(magic == [80, 70, 10], "invalid magic");
		streamPos += magic.length;

		immutable ubyte[] imgSize = stream.readLine(streamPos);
		immutable int[2] size = parseImgSize(imgSize);
		streamPos += imgSize.length;

		immutable ubyte[] endiannessLine = stream.readLine(streamPos);
		immutable float endiannessValue = parseEndiannessLine(endiannessLine);
		streamPos += endiannessLine.length;

		enforce!InvalidPFMFileFormat(
			12 * size[0] * size[1] == stream.length - streamPos,
			format("expected %s pixels", size[0]*size[1])
			);
		this(size[0], size[1]);

		float red, green, blue;
		int pixelPos;
		for (int i = 0; i < height; ++i)
		{
			for (int j = 0; j < width; ++j)
			{
				pixelPos = streamPos + 12 * this.pixelOffset(j, height - 1 - i); //(j, i)
				red = readFloat(stream, pixelPos, endiannessValue);
				green = readFloat(stream, pixelPos + 4, endiannessValue);
				blue = readFloat(stream, pixelPos + 8, endiannessValue);
				this.setPixel(j, i, Color(red, green, blue));
			}
		}
	}

	/// Build an HDRImage from a file
	this(in string fileName)
	{
		auto stream = cast(immutable ubyte[])(fileName.read);
		this(stream);
	}

	@safe void toString(
		scope void delegate(scope const(char)[]) @safe sink
		) const
    {
		sink.formattedWrite!"Image %s×%s"(width, height);
    }

	/// Check if the two integer coordinates (x and y) are inside the surface of the HDRImage 
	pure nothrow @nogc @safe bool validCoordinates(in int x, in int y) const
	{
		return x >= 0 && x < width && y >= 0 && y < height;
	}

	/// Return the position of a Pixel given the two integer coordinates (x and y)
	pure nothrow @nogc @safe int pixelOffset(in int x, in int y) const
	{
		return y * width + x;
	}
	
	/// Return the Color of a Pixel if it is inside the HDRImage
	pure nothrow @nogc @safe Color getPixel(in int x, in int y) const
	in (validCoordinates(x, y))
	{
		return pixels[pixelOffset(x, y)];
	}

	/// Set the Color given in a specific Pixel defined by two integer coordinates (x and y) 
	pure nothrow @nogc @safe void setPixel(in int x, in int y, Color c)
	in (validCoordinates(x, y))
	{
		pixels[pixelOffset(x, y)] = c;
	}
	
	/// Write a PFM file with Endianness "little Endian" from an array of ubyte
	pure nothrow @safe ubyte[] writePFM(
		in Endian endianness = Endian.littleEndian
		) const
	{
		immutable ubyte[3] magic = [80, 70, 10], endOfHeader = [49, 46, 48];
		immutable ubyte space = 32, endLine = 10;
		auto byteWidth = cast(ubyte[])(to!(char[])(width));
		auto byteHeight = cast(ubyte[])(to!(char[])(height));

		auto pfm = appender!(ubyte[]);
		if (endianness == Endian.littleEndian)
			pfm.put(
				magic ~
				byteWidth ~ space ~ byteHeight ~ endLine ~
				ubyte(45) ~ endOfHeader ~ endLine
				);
		else pfm.put(
			magic ~
			byteWidth ~ space ~ byteHeight ~ endLine ~
			endOfHeader ~ endLine
			);

		Color c;
		for (int i = height - 1; i > -1; --i) //++i
		{
			for (int j = 0; j < width; ++j)
			{
				c = getPixel(j, i);
				if (endianness == Endian.bigEndian)
				{
					pfm.append!(uint, Endian.bigEndian)(*cast(uint*)(&c.r));
					pfm.append!(uint, Endian.bigEndian)(*cast(uint*)(&c.g));
					pfm.append!(uint, Endian.bigEndian)(*cast(uint*)(&c.b));
				}
				else
				{
					pfm.append!(uint, Endian.littleEndian)(*cast(uint*)(&c.r));
					pfm.append!(uint, Endian.littleEndian)(*cast(uint*)(&c.g));
					pfm.append!(uint, Endian.littleEndian)(*cast(uint*)(&c.b));
				}
			}
		}
		return pfm.data;
	}

	@safe bool notProvided(
		in string fileName, in string extension
		) const
	{
		if (fileName.length == 0)
		{
			writeln("Warning: ".bold.green, format(
				"%s file not written since no name was provided",
				extension
				));
			return true;
		}
		return false;
	}

	@safe string checkExtension(in string fileName, in string extension) const
	in (fileName.length != 0)
	{
		string fileRightName = fileName;
		if (!fileName.endsWith(extension))
		{
			fileRightName = format("%s.%s", fileName, extension);
			writeln(
				"Warning: ".bold.green,
				fileName.bold, " automatically renamed to ", fileRightName.bold
				);
		}
		return fileRightName;
	}

	/// Write a PFM file with a given name, with Endianness "little Endian" from an array of ubyte
	// Not safe on windows
	/* @safe */ void writePFMFile(
		in string fileName, in Endian endianness = Endian.littleEndian
		) const
	{
		if (notProvided(fileName, "pfm")) return;
	
		string fileRightName = checkExtension(fileName, "pfm");
		auto file = File(fileRightName, "wb");
		file.rawWrite(writePFM(endianness));
	}

	/// Write a PNG file with a given name and with a fixed gamma parameter
	void writePNG(in string fileName, in float gamma = 1.0) const
	{
		if (notProvided(fileName, "png")) return;

		string fileRightName = checkExtension(fileName, "png");
		auto rgb = appender!(ubyte[]);
		foreach (Color c; pixels)
		{
			rgb.put(to!ubyte(round(255.0 * pow(c.r, 1.0 / gamma))));
			rgb.put(to!ubyte(round(255.0 * pow(c.g, 1.0 / gamma))));
			rgb.put(to!ubyte(round(255.0 * pow(c.b, 1.0 / gamma))));
		}
		imageformats.png.write_png(fileRightName, width, height, rgb.data, 0);
	}

	/// Return the average luminosity of an HDRImage
	pure nothrow @nogc @safe float averageLuminosity(
		in float delta = 1e-10
		) const
	{
		float lumSum = 0.0;
        foreach (Color p; pixels[]) lumSum += log10(delta + p.luminosity);
        return pow(10, lumSum / pixels.length);
	}

	/// Normalize each pixel of an HDRImage multiplying by the ratio: factor / luminosity
	pure nothrow @nogc @safe void normalizeImage(
		in float factor, float luminosity = float.init
		)
	{
		if (luminosity.isNaN) luminosity = averageLuminosity;
		for (int i = 0; i < pixels.length; ++i)
			pixels[i] *= factor / luminosity;
	}

	/// Correct the colors of an HDRImage calling clamp on every r,b,g component in every pixel
	pure nothrow @nogc @safe void clampImage()
	{
		for (int i = 0; i < pixels.length; ++i)
		{
			pixels[i].r = clamp(pixels[i].r);
			pixels[i].g = clamp(pixels[i].g);
			pixels[i].b = clamp(pixels[i].b);
		}
	}
}

///
unittest
{
	auto img = new HDRImage(7, 4);

	// validCoordinates
	assert(img.validCoordinates(0, 0)); 
	assert(img.validCoordinates(6, 3));
	assert(!img.validCoordinates(-1, 0));
	assert(!img.validCoordinates(0, -1));
	assert(!img.validCoordinates(7, 0));
	assert(!img.validCoordinates(0, 4));

	// pixelOffset
	assert(img.pixelOffset(3, 2) == 17);
}

///
unittest
{
	auto img = new HDRImage(2, 1);
	auto c1 = Color(5.0, 10.0, 15.0), c2 = Color(500.0, 1000.0, 1500.0);
	img.setPixel(0, 0, c1);
	img.setPixel(1, 0, c2);
		
	writeln(img.averageLuminosity(0.0));

	// averageLuminosity
	assert(areClose(100.0, img.averageLuminosity(0.0)));
		
	auto c3 = Color(0.5e2, 1.0e2, 1.5e2), c4 = Color(0.5e4, 1.0e4, 1.5e4);
	img.normalizeImage(1000.0, 100.0);

	// colorIsClose
	assert(img.getPixel(0, 0).colorIsClose(c3));
	assert(img.getPixel(1, 0).colorIsClose(c4));
}

///
unittest
{
	auto img = new HDRImage(2, 1);
		
	auto c1 = Color(0.5e1, 1.0e1, 1.5e1), c2 = Color(0.5e3, 1.0e3, 1.5e3);
	img.setPixel(0, 0, c1);
	img.setPixel(1, 0, c2);
	img.clampImage();
		
	foreach (Color pixel; img.pixels)
	{
		// Check RGB boundaries
		assert(pixel.r >= 0.0 && pixel.r <= 1.0);
		assert(pixel.g >= 0.0 && pixel.g <= 1.0);
		assert(pixel.b >= 0.0 && pixel.b <= 1.0);
	}
}

///
unittest
{
	auto img = new HDRImage(3, 2);
	img.setPixel(0, 0, Color(1.0e1, 2.0e1, 3.0e1));
	img.setPixel(1, 0, Color(4.0e1, 5.0e1, 6.0e1));
	img.setPixel(2, 0, Color(7.0e1, 8.0e1, 9.0e1));
	img.setPixel(0, 1, Color(1.0e2, 2.0e2, 3.0e2));
	img.setPixel(1, 1, Color(4.0e2, 5.0e2, 6.0e2));
	img.setPixel(2, 1, Color(7.0e2, 8.0e2, 9.0e2));

	ubyte[84] leReferenceBytes = [
	0x50, 0x46, 0x0a, 0x33, 0x20, 0x32, 0x0a, 0x2d, 0x31, 0x2e, 0x30, 0x0a,
	0x00, 0x00, 0xc8, 0x42, 0x00, 0x00, 0x48, 0x43, 0x00, 0x00, 0x96, 0x43,
	0x00, 0x00, 0xc8, 0x43, 0x00, 0x00, 0xfa, 0x43, 0x00, 0x00, 0x16, 0x44,
	0x00, 0x00, 0x2f, 0x44, 0x00, 0x00, 0x48, 0x44, 0x00, 0x00, 0x61, 0x44,
	0x00, 0x00, 0x20, 0x41, 0x00, 0x00, 0xa0, 0x41, 0x00, 0x00, 0xf0, 0x41,
	0x00, 0x00, 0x20, 0x42, 0x00, 0x00, 0x48, 0x42, 0x00, 0x00, 0x70, 0x42,
	0x00, 0x00, 0x8c, 0x42, 0x00, 0x00, 0xa0, 0x42, 0x00, 0x00, 0xb4, 0x42
	];

	ubyte[83] beReferenceBytes = [
	0x50, 0x46, 0x0a, 0x33, 0x20, 0x32, 0x0a, 0x31, 0x2e, 0x30, 0x0a, 0x42,
	0xc8, 0x00, 0x00, 0x43, 0x48, 0x00, 0x00, 0x43, 0x96, 0x00, 0x00, 0x43,
	0xc8, 0x00, 0x00, 0x43, 0xfa, 0x00, 0x00, 0x44, 0x16, 0x00, 0x00, 0x44,
	0x2f, 0x00, 0x00, 0x44, 0x48, 0x00, 0x00, 0x44, 0x61, 0x00, 0x00, 0x41,
	0x20, 0x00, 0x00, 0x41, 0xa0, 0x00, 0x00, 0x41, 0xf0, 0x00, 0x00, 0x42,
	0x20, 0x00, 0x00, 0x42, 0x48, 0x00, 0x00, 0x42, 0x70, 0x00, 0x00, 0x42,
	0x8c, 0x00, 0x00, 0x42, 0xa0, 0x00, 0x00, 0x42, 0xb4, 0x00, 0x00
	];
	
	// writePFM
	assert(img.writePFM == leReferenceBytes);
	assert(img.writePFM(Endian.bigEndian) == beReferenceBytes);
}

///
unittest
{
	auto files = ["pfmImages/reference_le.pfm", "pfmImages/reference_be.pfm"];

	foreach (string fileName; files)
	{
		auto img = new HDRImage(fileName);

		assert(img.width == 3);
		assert(img.height == 2);

		// getPixel
		assert(img.getPixel(0, 0).colorIsClose(Color(1.0e1, 2.0e1, 3.0e1)));
		assert(img.getPixel(1, 0).colorIsClose(Color(4.0e1, 5.0e1, 6.0e1)));
        assert(img.getPixel(2, 0).colorIsClose(Color(7.0e1, 8.0e1, 9.0e1)));
        assert(img.getPixel(0, 1).colorIsClose(Color(1.0e2, 2.0e2, 3.0e2)));
        assert(img.getPixel(0, 0).colorIsClose(Color(1.0e1, 2.0e1, 3.0e1)));
        assert(img.getPixel(1, 1).colorIsClose(Color(4.0e2, 5.0e2, 6.0e2)));
        assert(img.getPixel(2, 1).colorIsClose(Color(7.0e2, 8.0e2, 9.0e2)));
	}
}