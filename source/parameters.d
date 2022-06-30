module parameters;

import std.algorithm : canFind;
import std.array : split;
import std.conv : ConvException, to;
import std.exception : enforce;
import std.file : isFile;
import std.format : format;
import std.math : isFinite, sqrt;
import std.traits : EnumMembers;

// ************************* InvalidPfm2pngParms *************************
/// Class used to recognise and throw exceptions in case of error in conversion pfm -> png
/// Used in modality pfm2png only. 
class InvalidPfm2pngParms : Exception
{
	// Build an Exception of type InvalidPfm2pngParms
    pure @nogc @safe this(string msg, string file = __FILE__, size_t line = __LINE__)
    {
        super(msg, file, line);
    }
}

// ************************* InvalidPfm2pngParms *************************
/// Struct used to record all the parameters introduced in the command line by the user.
/// Used in modality pfm2png only. 
/// 
/// Usage: dub run -- pfm2png 
struct Pfm2pngParameters
{
	string pfmInput, pngOutput;
	immutable float factor, gamma;

	/// Build the struct from a string of arguments that are provided by the user:
	/// the pfm file name, the png file name, the factor and the gamma
	@safe this(in string[] args)
	{	
		assert(args.length == 4);

		enforce(args[0].isFile);
		pfmInput = args[0];

		pngOutput = args[1];

		try
		{
			//factor
			factor = to!float(args[2]);
			enforce!InvalidPfm2pngParms(isFinite(factor) && factor > 0,
				"Factor must be a positive number");
		}
		catch (ConvException exc)
			throw new InvalidPfm2pngParms(format("Invalid factor [%s]", args[2]));

		try
		{
			// gamma
			gamma = to!float(args[3]);
			enforce!InvalidPfm2pngParms(isFinite(gamma) && gamma > 0,
				"Gamma must be a positive number");
		}
		catch (ConvException exc)
			throw new InvalidPfm2pngParms(format("Invalid gamma [%s]", args[3]));
	}
}

// ************************* InvalidRenderParms *************************
/// Class used to recognise and throw exceptions in case of error in parameters for the rendering
/// Used in modality render only. 
class InvalidRenderParms : Exception
{
	/// Build an Exception of type InvalidRenderParms
    pure @nogc @safe this(string msg, string file = __FILE__, size_t line = __LINE__)
    {
        super(msg, file, line);
    }
}

enum ValidRenderers : string
{
	flat = "flat",
	onoff = "on-off",
	path = "path"
}

// ************************* RenderParameters *************************
/// Struct used to record all the parameters introduced in the command line by the user.
/// Used in modality render only. 
/// 
/// Usage: dub run -- render
struct RenderParameters
{
	string sceneFileName;
	immutable int width, height;
	string renderer;
	string pfmOutput, pngOutput;
	immutable int initialState, initialSequence;
	immutable int numberOfRays, depth;
	immutable int samplesPerSide;
	float[string] variableTable;
	
	/// Build the struct from a string of arguments that can be provided by the user:
	/// the width and height of the image, the kind of renderer, the angle of view,
	/// the name of the input pfm file and of the output png file, the seed and initiasl sequence for a pcg,
	/// the kind of camera (perspective/orthogonal), the number of samples per side to fill the pixels
	@safe this(in string[] args, in string[] declaredFloat)
	{		
		assert(args.length == 11);

		enforce(args[0].isFile);
		sceneFileName = args[0];

		try
		{
			/// width
			width = to!int(args[1]);
			enforce!InvalidRenderParms(width > 0, format("Invalid width [%s]", args[1]));
		}
		catch (ConvException exc)
			throw new InvalidRenderParms(format("Invalid width [%s]", args[1]));

		try
		{
			/// height
			height = to!int(args[2]);
			enforce!InvalidRenderParms(height > 0, format("Invalid height [%s]", args[2]));
		}
		catch (ConvException exc)
			throw new InvalidRenderParms(format("Invalid height [%s]", args[2]));

		enforce!InvalidRenderParms(canFind([EnumMembers!ValidRenderers], args[3]),
			format("Option algorithm must be one of the following values: %s",
			EnumMembers!ValidRenderers));
		renderer = args[3];

		pfmOutput = args[4];
		pngOutput = args[5];

		/// pgc initialization: seed and sequence
		try
		{	
			initialState = to!int(args[6]);
			enforce!InvalidRenderParms(initialState > 0, format("Invalid initialState [%s]", args[6]));
		}
		catch (ConvException exc)
			throw new InvalidRenderParms(format("Invalid initialState [%s]", args[6]));

		try
		{
			initialSequence = to!int(args[7]);
			enforce!InvalidRenderParms(initialSequence > 0, format("Invalid initialSequence [%s]", args[7]));
		}
		catch (ConvException exc)
			throw new InvalidRenderParms(format("Invalid initialSequence [%s]", args[7]));

		try
		{
			/// number of rays shot
			numberOfRays = to!int(args[8]);
			enforce!InvalidRenderParms(numberOfRays > 0, format("Invalid numberOfRays [%s]", args[8]));
		}
		catch (ConvException exc)
			throw new InvalidRenderParms(format("Invalid numberOfRays [%s]", args[8]));

		try
		{
			/// depth travelled by the ray
			depth = to!int(args[9]);
			enforce!InvalidRenderParms(depth > 0, format("Invalid depth [%s]", args[9]));
		}
		catch (ConvException exc)
			throw new InvalidRenderParms(format("Invalid depth [%s]", args[9]));

		try
		{	
			/// number of samples per pixel 	
			immutable int samplesPerPixel = to!int(args[10]);
			enforce!InvalidRenderParms(samplesPerPixel >= 0, format(
				"Invalid samplesPerPixel [%s]. It must be a perfect square: 0, 1, 4, 9...", args[10]));

			samplesPerSide = cast(immutable int)(sqrt(cast(double)samplesPerPixel));
			enforce!InvalidRenderParms((samplesPerSide * samplesPerSide) == samplesPerPixel, format(
				"Invalid samplesPerPixel [%s]. It must be a perfect square: 0, 1, 4, 9...", args[10]));
		}
		catch (ConvException exc)
			throw new InvalidRenderParms(format(
				"Invalid samplesPerPixel [%s]. It must be a perfect square: 0, 1, 4, 9...", args[10]));

		foreach (string newVar; declaredFloat)
		{
			string[] nameAndValue = newVar.split(":");
			enforce!InvalidRenderParms(nameAndValue.length == 2,
				format("%s does not follow the definition pattern NAME:VALUE", newVar));
			try
			{
				variableTable[nameAndValue[0]] = to!float(nameAndValue[1]);
			}
			catch (ConvException exc)
				throw new InvalidRenderParms(format("Invalid value [%s] for variable %s",
					nameAndValue[1], nameAndValue[0]));
		}
	}

	/// Return the aspect ratio of the image
	pure nothrow @nogc @safe float aspRat()
	{
		return cast(float)(width) / height;
	}
}