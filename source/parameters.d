module parameters;

import std.conv;
import std.exception : enforce;
import std.file : isFile;
import std.format : format;
import std.math : isFinite, sqrt, trunc;

class InvalidPfm2pngParms : Exception
{
    pure @nogc @safe this(string msg, string file = __FILE__, size_t line = __LINE__)
    {
        super(msg, file, line);
    }
}

struct Pfm2pngParameters
{
	string pfmInput, pngOutput;
	immutable float factor, gamma;

	@safe this(in string[] args)
	{	
		assert(args.length == 4);

		enforce(args[0].isFile);
		pfmInput = args[0];

		pngOutput = args[1];

		try
		{
			factor = to!float(args[2]);
			enforce!InvalidPfm2pngParms(isFinite(factor) && factor > 0,
				"Factor must be a positive number");
		}
		catch (ConvException exc)
			throw new InvalidPfm2pngParms(format("Invalid factor [%s]", args[2]));

		try
		{
			gamma = to!float(args[3]);
			enforce!InvalidPfm2pngParms(isFinite(gamma) && gamma > 0,
				"Gamma must be a positive number");
		}
		catch (ConvException exc)
			throw new InvalidPfm2pngParms(format("Invalid gamma [%s]", args[3]));
	}
}

class InvalidDemoParms : Exception
{
    pure @nogc @safe this(string msg, string file = __FILE__, size_t line = __LINE__)
    {
        super(msg, file, line);
    }
}

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

	pure @safe this(in string[] args)
	{		
		assert(args.length == 12);

		try
		{
			width = to!int(args[0]);
			enforce!InvalidDemoParms(width > 0, format("Invalid width [%s]", args[0]));
		}
		catch (ConvException exc)
			throw new InvalidDemoParms(format("Invalid width [%s]", args[0]));
		
		try
		{
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
			angle = to!float(args[3]);
			enforce!InvalidDemoParms(isFinite(angle), format("Invalid angle [%s]", args[3]));
		}
		catch (ConvException exc)
			throw new InvalidDemoParms(format("Invalid angle [%s]", args[3]));

		pfmOutput = args[4];
		pngOutput = args[5];

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
			numberOfRays = to!int(args[8]);
			enforce!InvalidDemoParms(numberOfRays > 0, format("Invalid numberOfRays [%s]", args[8]));
		}
		catch (ConvException exc)
			throw new InvalidDemoParms(format("Invalid numberOfRays [%s]", args[8]));
		
		try
		{
			depth = to!int(args[9]);
			enforce!InvalidDemoParms(depth > 0, format("Invalid depth [%s]", args[9]));
		}
		catch (ConvException exc)
			throw new InvalidDemoParms(format("Invalid depth [%s]", args[9]));

		try
		{	
			immutable int samplesPerPixel = to!int(args[10]);
			enforce!InvalidDemoParms(samplesPerPixel >= 0,
				format("Invalid samplesPerPixel [%s]. It must be a perfect square.", args[10]));

			samplesPerSide = cast(immutable int)(sqrt(cast(double)samplesPerPixel));
			enforce!InvalidDemoParms((samplesPerSide * samplesPerSide) == samplesPerPixel,
			format("Invalid samplesPerPixel [%s]. It must be a perfect square.", args[10]));
		}
		catch (ConvException exc)
			throw new InvalidDemoParms(
				format("Invalid samplesPerPixel [%s]. It must be a perfect square.", args[10]));
		
		if (args[11] != "") orthogonal = true;
	}

	pure nothrow @nogc @safe float aspRat()
	{
		return cast(float)(width) / height;
	}
}