import geometry;
import hdrimage;
import std.conv;
import std.file : isFile, FileException;
import std.format : format;
import std.stdio : writeln;
import transformations;

struct Parameters
{
	string inputPFMFile, outputPNGFile;
	float factor = 0.2, gamma = 1.0;

	this(string[] args)
	{
		if (args.length != 5)
			throw new Exception("USAGE: executable inputPFMFile factor gamma outputPNGFile");
		
		if (!args[1].isFile)
			throw new FileException(format("Invalid input file [%s] ", args[1]));
		inputPFMFile = args[1];

		try factor = to!float(args[2]);
		catch (std.conv.ConvException exc)
			throw new std.conv.ConvException(format("Invalid factor [%s]", args[2]));

		try gamma = to!float(args[3]);
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

	HDRImage image = new HDRImage(params.inputPFMFile);
	writeln("File "~params.inputPFMFile~" has been read from disk");

	image.normalizeImage(params.factor);
	image.clampImage;

	image.writePNG(params.outputPNGFile.dup,params.gamma);
	writeln("File "~params.outputPNGFile~" has been written to disk");
}