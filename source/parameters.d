module parameters;

import std.conv : ConvException, to;
import std.exception : enforce;
import std.file : isFile;
import std.format : format;
import std.math : isFinite, sqrt, trunc;

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

// ************************* InvalidDemoParms *************************
/// Class used to recognise and throw exceptions in case of error in parmeters for the rendering
/// Used in modality demo only. 
class InvalidDemoParms : Exception
{
	/// Build an Exception of type InvalidDemoParms
    pure @nogc @safe this(string msg, string file = __FILE__, size_t line = __LINE__)
    {
        super(msg, file, line);
    }
}

// ************************* DemoParameters *************************
/// Struct used to record all the parameters introduced in the command line by the user.
/// Used in modality demo only. 
/// 
/// Usage: dub run -- demo
struct DemoParameters
{
	immutable int width, height;
	string renderer;
	immutable float angle;
	string pfmOutput, pngOutput;
	immutable int initialState, initialSequence;
	immutable int numberOfRays, depth;
	immutable bool orthogonal;
	immutable int samplesPerSide;
	
	/// Build the struct from a string of arguments that can be provided by the user:
	/// the width and height of the image, the kind of renderer, the angle of view,
	/// the name of the input pfm file and of the output png file, the seed and initiasl sequence for a pcg,
	/// the kind of camera (perspective/orthogonal), the number of samples per side to fill the pixels
	pure @safe this(in string[] args)
	{		
		assert(args.length == 12);

		try
		{
			/// width
			width = to!int(args[0]);
			enforce!InvalidDemoParms(width > 0, format("Invalid width [%s]", args[0]));
		}
		catch (ConvException exc)
			throw new InvalidDemoParms(format("Invalid width [%s]", args[0]));
		
		try
		{
			/// height
			height = to!int(args[1]);
			enforce!InvalidDemoParms(height > 0, format("Invalid height [%s]", args[1]));
		}
		catch (ConvException exc)
			throw new InvalidDemoParms(format("Invalid height [%s]", args[1]));

		enforce!InvalidDemoParms(args[2] == "flat" || args[2] == "on-off" || args[2] == "path",
			"Option algorithm must be one of the following values: flat, on-off, path");
		renderer = args[2];

		try
		{	
			/// angle of view
			angle = to!float(args[3]);
			enforce!InvalidDemoParms(isFinite(angle), format("Invalid angle [%s]", args[3]));
		}
		catch (ConvException exc)
			throw new InvalidDemoParms(format("Invalid angle [%s]", args[3]));

		pfmOutput = args[4];
		pngOutput = args[5];

		/// pgc initialization: seed and sequence
		try
		{	
			initialState = to!int(args[6]);
			enforce!InvalidDemoParms(initialState > 0, format("Invalid initialState [%s]", args[6]));
		}
		catch (ConvException exc)
			throw new InvalidDemoParms(format("Invalid initialState [%s]", args[6]));

		try
		{
			initialSequence = to!int(args[7]);
			enforce!InvalidDemoParms(initialSequence > 0, format("Invalid initialSequence [%s]", args[7]));
		}
		catch (ConvException exc)
			throw new InvalidDemoParms(format("Invalid initialSequence [%s]", args[7]));

		try
		{
			/// number of rays shot
			numberOfRays = to!int(args[8]);
			enforce!InvalidDemoParms(numberOfRays > 0, format("Invalid numberOfRays [%s]", args[8]));
		}
		catch (ConvException exc)
			throw new InvalidDemoParms(format("Invalid numberOfRays [%s]", args[8]));
		
		try
		{
			/// depth travelled by the ray
			depth = to!int(args[9]);
			enforce!InvalidDemoParms(depth > 0, format("Invalid depth [%s]", args[9]));
		}
		catch (ConvException exc)
			throw new InvalidDemoParms(format("Invalid depth [%s]", args[9]));

		try
		{	
			/// number of samples per pixel 	
			immutable int samplesPerPixel = to!int(args[10]);
			enforce!InvalidDemoParms(samplesPerPixel >= 0, format(
				"Invalid samplesPerPixel [%s]. It must be a perfect square: 0, 1, 4, 9...", args[10]));

			samplesPerSide = cast(immutable int)(sqrt(cast(double)samplesPerPixel));
			enforce!InvalidDemoParms((samplesPerSide * samplesPerSide) == samplesPerPixel, format(
				"Invalid samplesPerPixel [%s]. It must be a perfect square: 0, 1, 4, 9...", args[10]));
		}
		catch (ConvException exc)
			throw new InvalidDemoParms(format(
				"Invalid samplesPerPixel [%s]. It must be a perfect square: 0, 1, 4, 9...", args[10]));
		
		/// kind of camera: orthogonal vs perspective
		if (args[11] != "") orthogonal = true;
	}

	/// Return the aspect ratio of the image
	pure nothrow @nogc @safe float aspRat()
	{
		return cast(float)(width) / height;
	}
}