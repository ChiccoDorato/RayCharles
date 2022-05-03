import commandr;
import hdrimage : HDRImage, InvalidPFMFileFormat;
import std.conv;
import std.exception : enforce;
import std.file : isFile;
import std.format : format;
import std.math : isNaN;
import std.stdio : writeln;
import std.string : isNumeric;

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

bool potentialFloat(string arg)
{
	try
	{
		if (!isNaN(to!float(arg))) return true;
		return false;
	}
	catch (std.conv.ConvException exc) return false;
}

bool potentialPositive(T)(string arg)
in (is(T == int) || is(T == float))
{
	try
	{
		if (to!T(arg) > 0) return true;
		return false;
	}
	catch (std.conv.ConvException exc) return false;
}

void main(string[] args)
{ 
	auto rayC = new Program("RayCharles")
		.add(new Command("pfm2png")
			.add(new Argument("pfmInputFileName", "name of the pfm file to convert")
				.acceptsFiles())
			.add(new Argument("pngOutputFileName", "name of the png file to create/override"))
			.add(new Option("f", "factor", "multiplicative factor. Default: 0.2")
				.defaultValue("0.2")
				.validateEachWith(arg => potentialPositive!float(arg), "must be a positive floating point"))
			.add(new Option("g", "gamma", "gamma correction value. Default: 1.0")
				.defaultValue("1.0")
				.validateEachWith(arg => potentialPositive!float(arg), "must be a positive floating point")))
		.add(new Command("demo")
			.add(new Option(null, "width", "width in pixels of the image to render. Default: 640")
				.defaultValue("640")
				.validateEachWith(arg => potentialPositive!int(arg), "must be a positive integer"))
			.add(new Option(null, "height", "height in pixels of the image to render. Default: 480")
				.defaultValue("480")
				.validateEachWith(arg => potentialPositive!int(arg), "must be a positive integer"))
			.add(new Option("a", "angleDeg", "angle of view in degree. Default: 0.0")
				.defaultValue("0.0")
				.validateEachWith(arg => potentialFloat(arg), "must be a floating point"))
			.add(new Option("pfm", "pfmOutput", "name of the pfm file to create/override"))
			.add(new Option("png", "pngOutput", "name of the png file to crete/override"))
			.add(new Flag("o", "orthogonal", "use an orthogonal camera. Default: perspective camera")))
		.parse(args);

	rayC
		.on("pfm2png", (rayC)
			{
				try
				{
					HDRImage image = new HDRImage(rayC.arg("pfmInputFileName"));
					writeln("File "~rayC.arg("pfmInputFileName")~" has been read from disk");

					image.normalizeImage(to!float(rayC.option("factor")));
					image.clampImage;

					image.writePNG(rayC.arg("pngOutputFileName").dup, to!float(rayC.option("gamma")));
					writeln("File "~rayC.arg("pngOutputFileName")~" has been written to disk");
				}
				catch (InvalidPFMFileFormat exc)
				{
					writeln(format("File [%s] is not a correct PFM file", rayC.arg("pfmInputFileName")));
					return;
				}
			}
		)
		.on("demo", (rayC)
			{
				import cameras : OrthogonalCamera, PerspectiveCamera;
				import geometry : Vec;
				import shapes : Shape, World;
				import transformations : rotationZ, Transformation, translation;

				int w = to!int(rayC.option("width")), h = to!int(rayC.option("height"));
				float angle = to!float(rayC.option("angleDeg"));

				Shape[] s;
				World world = World(s);
				Transformation cameraTr = rotationZ(angle) * translation(Vec(-1.0, 0.0, 0.0));
				if (rayC.flag("orthogonal")) OrthogonalCamera camera;
				else PerspectiveCamera camera;
				return;
			}
		);
}