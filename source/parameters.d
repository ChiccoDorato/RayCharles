module parameters;

import std.conv;
import std.exception : enforce;
import std.file : isFile;
import std.format : format;
import std.math : isFinite;

class InvalidPfm2pngParms : Exception
{
    this(string msg, string file = __FILE__, size_t line = __LINE__)
    {
        super(msg, file, line);
    }
}

struct Pfm2pngParameters
{
	string pfmInput, pngOutput;
	float factor, gamma;

	this(in string[] args)
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
    this(string msg, string file = __FILE__, size_t line = __LINE__)
    {
        super(msg, file, line);
    }
}

struct DemoParameters
{
	int width, height;
	float angle;
	string pfmOutput, pngOutput;
	bool orthogonal;

	this(in string[] args)
	{		
		assert(args.length == 6);

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
		
		try
		{
			angle = to!float(args[2]);
			enforce!InvalidDemoParms(isFinite(angle), format("Invalid angle [%s]", args[2]));
		}
		catch (ConvException exc)
			throw new InvalidDemoParms(format("Invalid angle [%s]", args[2]));
		
		pfmOutput = args[3];
		pngOutput = args[4];
		if (args[5] != "") orthogonal = true;
	}

	immutable(float) aspRat()
	{
		return cast(float)(width) / height;
	}
}