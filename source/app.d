import hdrimage;
import std.conv;
import std.exception : enforce;
import std.file : isFile;
import std.format : format;
import std.stdio : writeln;

struct Parameters
{
	string inputPFMFile, outputPNGFile;
	float factor = 0.2, gamma = 1.0;

	this(string[] args)
	{
		enforce(args.length == 5, "USAGE: executable inputPFMFile factor gamma outputPNGFile");
		
		enforce(args[1].isFile);
		inputPFMFile = args[1];

		try
		{
			factor = to!float(args[2]);
			enforce(factor > 0, "Factor must be a positive number");
		}
		catch (std.conv.ConvException exc)
			throw new std.conv.ConvException(format("Invalid factor [%s]", args[2]));

		try
		{
			gamma = to!float(args[3]);
			enforce(gamma > 0, "Gamma must be a positive number");
		}
		catch (std.conv.ConvException exc)
			throw new std.conv.ConvException(format("Invalid gamma [%s]", args[3]));

		outputPNGFile = args[4];
	}
}

void main(string[] args)
{ 
	Parameters* params;
	try params = new Parameters(args);
	catch (Exception exc)
	{
		writeln("Error! ", exc.msg);
		return;
	}

	try
	{
		HDRImage image = new HDRImage(params.inputPFMFile);
		writeln("File "~params.inputPFMFile~" has been read from disk");

		image.normalizeImage(params.factor);
		image.clampImage;

		image.writePNG(params.outputPNGFile.dup, params.gamma);
		writeln("File "~params.outputPNGFile~" has been written to disk");
	}
	catch (InvalidPFMFileFormat exc)
	{
		writeln(format("File [%s] is not a correct PFM file", params.inputPFMFile));
		return;
	}
}