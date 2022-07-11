module parameters;

import colored;
import std.algorithm : canFind, endsWith;
import std.array : split;
import std.conv : ConvException, to;
import std.exception : enforce;
import std.file : FileException, isFile;
import std.format : format;
import std.math : isFinite, sqrt;
import std.stdio : writeln;
import std.traits : EnumMembers;

/**
* Check the extension of a file. If it's not the wanted one,
* the correct extension will be added at the end of the fileName
* Params: 
* 	fileName = (string)
* 	extension = (string)
* 	alreadyValid = (bool) 
* Returns: fileName (string)
*/
pure @safe string forceExtension(
	in string fileName, in string extension, out bool alreadyValid
	)
{
	if (!fileName.endsWith(extension))
		return format("%s.%s", fileName, extension);

	alreadyValid = true;
	return fileName;
}

// ************************* WrongSign *************************
/**
* Class used to recognise and throw Exceptions
* in case of wrong sign
*/
class WrongSign : Exception
{
	/**
	* Build an Exception of type WrongSign
	* Params:
	* msg = (string)
	* file = (string) = __FILE__ 
	* line = (size_t) = __LINE__
	*/
    pure @nogc @safe this(
		string msg, string file = __FILE__, size_t line = __LINE__
		)
    {
        super(msg, file, line);
    }
}

/**
* Assign to a given string a sign of comparison
* Params: 
* 	cmp = (string)
* Returns: one of those strings: ">", ">=", "<", "<="
*/
pure nothrow @safe @nogc isComparison(string cmp)
{
	return cmp == ">" || cmp == ">=" || cmp == "<" || cmp == "<=";
}

/**
* Verify if the string given represent a number 
* which is finite and with the correct sign
* Params: 
* 	cmp = (string)
* 	cand = (string)
* 	parmName = (string) = "assignment" 
*/
pure @safe T toSign(T, string cmp)(string cand, string parmName = "assignment")
if ((is(T == int) || is(T == float)) && isComparison(cmp))
{
	try
	{
		T number = to!T(cand);
		static if (is(T == float)) enforce!WrongSign(
			number.isFinite,
			format("invalid %s, %s is not a finite number", parmName, cand)
			);
		enforce!WrongSign(
			mixin("number" ~ cmp ~ "0"),
			format("invalid %s, %s %s 0 does not hold", parmName, cand, cmp)
			);
		return number;
	}
	catch (ConvException exc)
		throw new WrongSign(format("invalid %s: %s", parmName, exc.msg));
}

/**
* Verify if the string given represent a positive number
*/
alias toPositive(T) = toSign!(T, ">");

/**
* Verify if the string given represent a non negative number
*/
alias toNonNegative(T) = toSign!(T, ">=");

/**
* Verify if the string given represent a negative number
*/
alias toNegative(T) = toSign!(T, "<");

/**
* Verify if the string given represent a non negative number
*/
alias toNonPositive(T) = toSign!(T, "<=");

// ************************* InvalidPfm2pngParms *************************
/**
* Class used to recognise and throw Exceptions 
* in case of error in conversion pfm -> png
*___
* Used in modality pfm2png only. 
*/
class InvalidPfm2pngParms : Exception
{
	/** Build an Exception of type InvalidPfm2pngParms
	* Params: 
	* 	msg = (string)
	* 	file = (string) = __FILE__ 
	* 	line = (size_t) = __LINE__
	*/
    pure @nogc @safe this(
		string msg, string file = __FILE__, size_t line = __LINE__
		)
    {
        super(msg, file, line);
    }

	@safe void printError()
	{
		writeln("Error: ".bold.red, msg);
	}
}

// ************************* InvalidPfm2pngParms *************************
/**
* Struct used to record all the parameters 
* introduced in the command line by the user
*___
* Used in modality pfm2png only
* ___ 
* Usage: dub run -- pfm2png 
*/
struct Pfm2pngParameters
{
	string pfmInput, pngOutput;
	bool isOutputPNG;
	immutable float factor, gamma;

	/**
	* Build Pfm2pngParameters from a string of arguments provided by the user
	* Params:
	* 	pfmfileName = (string)
	* 	pngfileName = (string)
	* 	factor = (float)
	* 	gamma = (float)
	*/
	@safe this(in string[] args)
	{	
		assert(args.length == 4);

		try args[0].isFile;
		catch (FileException exc) throw new InvalidPfm2pngParms(exc.msg);
		pfmInput = args[0];

		pngOutput = forceExtension(args[1], "png", isOutputPNG);

		try
		{
			factor = toPositive!float(args[2], "factor");
			gamma = toPositive!float(args[3], "gamma");
		}
		catch (WrongSign exc) throw new InvalidPfm2pngParms(exc.msg);
	}
}

// ************************* InvalidRenderParms *************************
/**
* Class used to recognise and throw Exceptions
* in case of error in parameters for the rendering
* Used in modality render only. 
*/
class InvalidRenderParms : Exception
{
	/** Build an Exception of type InvalidRenderParms
	* Params: 
	* 	msg = (string)
	* 	file = (string) = __FILE__ 
	* 	line = (size_t) = __LINE__
	*/
    pure @nogc @safe this(
		string msg, string file = __FILE__, size_t line = __LINE__
		)
    {
        super(msg, file, line);
    }

	@safe void printError()
	{
		writeln("Error: ".bold.red, msg);
	}
}

/**
* Enumeration of the strings used for the Renderers: flat, onoff, path
*/
enum Renderers : string
{
	flat = "flat",
	onoff = "onoff",
	path = "path"
}
auto validRenderers = [EnumMembers!Renderers];

// ************************* RenderParameters *************************
/**
* Struct used to record all the parameters 
* introduced in the command line by the user
* ___
* Used in modality render only
*___
* Usage: dub run -- render
*/
struct RenderParameters
{
	string sceneFileName;
	immutable int width, height;
	string renderer;
	string pfmOutput, pngOutput;
	bool isOutputPFM, isOutputPNG;
	immutable int initialState, initialSequence;
	immutable int numberOfRays, depth;
	immutable int samplesPerSide;
	float[string] variableTable;
	
	/**
	* Build the struct from two strings of arguments provided by the user:
	* Params: 
	* 	width = (int) of the image
	* 	height = (int) of the image
	* 	renderer = (string) (flat, on/off, path)
	* 	angleOfView = (float)
	* 	pfmfileName = (string) input
	* 	pngfileName = (string) output
	* 	seed = (int)
	* 	initialSequence = (int)
	* 	camera = (string)  (perspective/orthogonal)
	* 	numberOfSamplesPerSide = (int) to fill the pixels
	*/
	@safe this(in string[] args, in string[] declaredFloat)
	{		
		assert(args.length == 11);

		try args[0].isFile;
		catch (FileException exc) throw new InvalidRenderParms(exc.msg);
		sceneFileName = args[0];

		try
		{
			width = toPositive!int(args[1], "width");
			height = toPositive!int(args[2], "height");
		}
		catch (WrongSign exc) throw new InvalidRenderParms(exc.msg);

		enforce!InvalidRenderParms(
			canFind(validRenderers, args[3]),
			format("valid options for algorithm are %s", validRenderers)
			);
		renderer = args[3];

		pfmOutput = forceExtension(args[4], "pfm", isOutputPFM);
		pngOutput = forceExtension(args[5], "png", isOutputPNG);

		/// pgc initialization: seed and sequence
		try
		{
			initialState = toPositive!int(args[6], "initialState");
			initialSequence = toPositive!int(args[7], "initialSequence");
			numberOfRays = toPositive!int(args[8], "numberOfRays");
			depth = toPositive!int(args[9], "depth");

			auto sampPerPixel = toNonNegative!int(args[10], "samplesPerPixel");
			samplesPerSide = cast(int)(sqrt(cast(double)sampPerPixel));
			enforce!InvalidRenderParms(
				samplesPerSide * samplesPerSide == sampPerPixel,
				format(
					"invalid samplesPerPixel, %s is not a perfect square",
					args[10]
					)
				);
		}
		catch (WrongSign exc) throw new InvalidRenderParms(exc.msg);

		foreach (string newVar; declaredFloat)
		{
			string[] nameAndValue = newVar.split(":");
			enforce!InvalidRenderParms(
				nameAndValue.length == 2,
				format("%s does not follow the pattern NAME:VALUE", newVar)
				);
			try variableTable[nameAndValue[0]] = to!float(nameAndValue[1]);
			catch (ConvException exc) throw new InvalidRenderParms(format(
					"invalid variable %s, %s",
					nameAndValue[0], exc.msg)
					);
		}
	}

	/**
	* Returns the aspect ratio of the image
	*/
	pure nothrow @nogc @safe float aspRat()
	{
		return cast(float)(width) / height;
	}
}