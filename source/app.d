import commandr;
import hdrimage : HDRImage, InvalidPFMFileFormat;
import std.conv;
import std.exception : enforce;
import std.file : isFile;
import std.format : format;
import std.math : isNaN;
import std.stdio : writeln;
import std.string : isNumeric;

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

struct pfm2pngParameters
{
	string inputPFMFile, outputPNGFile;
	float factor = 0.2, gamma = 1.0;

	this(string[] args)
	{		
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
	auto rayC = new Program("RayCharles", "1.0")
		.add(new Command("pfm2png")
			.add(new Argument("pfmInputFileName",
				"name of the pfm file to convert")
				.acceptsFiles())
			.add(new Argument("pngOutputFileName",
				"name of the png file to create/override"))
			.add(new Option("f", "factor",
				"multiplicative factor. Default: 0.2")
				.defaultValue("0.2")
				.validateEachWith(arg => potentialPositive!float(arg),
					"must be a positive floating point"))
			.add(new Option("g", "gamma",
				"gamma correction value. Default: 1.0")
				.defaultValue("1.0")
				.validateEachWith(arg => potentialPositive!float(arg),
					"must be a positive floating point")))
		.add(new Command("demo")
			.add(new Option(null, "width",
				"width in pixels of the image to render. Default: 640")
				.defaultValue("640")
				.validateEachWith(arg => potentialPositive!int(arg),
					"must be a positive integer"))
			.add(new Option(null, "height",
				"height in pixels of the image to render. Default: 480")
				.defaultValue("480")
				.validateEachWith(arg => potentialPositive!int(arg),
					"must be a positive integer"))
			.add(new Option("a", "angleDeg",
				"angle of view in degree. Default: 0.0")
				.defaultValue("0.0")
				.validateEachWith(arg => potentialFloat(arg),
					"must be a floating point"))
			.add(new Option("pfm", "pfmOutput",
				"name of the pfm file to create/override. Default: output.pfm")
				.defaultValue("output.pfm"))
			.add(new Option("png", "pngOutput",
				"name of the png file to crete/override. Default: output.png")
				.defaultValue("output.png"))
			.add(new Flag("o", "orthogonal",
				"use an orthogonal camera. Default: perspective camera")))
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
				import cameras : Camera, ImageTracer, OrthogonalCamera, PerspectiveCamera;
				import geometry : Vec;
				import hdrimage : Color;
				import ray : Ray;
				import shapes : Shape, Sphere, World;
				import transformations : rotationZ, scaling, Transformation, translation;

				int w = to!int(rayC.option("width")), h = to!int(rayC.option("height"));
				float aspRat = cast(float)(w) / h;
				float angle = to!float(rayC.option("angleDeg"));

				Transformation decimate = scaling(Vec(0.1, 0.1, 0.1));
				Shape[10] s = [new Sphere(translation(Vec(0.5, 0.5, 0.5)) * decimate),
					new Sphere(translation(Vec(0.5, -0.5, 0.5)) * decimate),
					new Sphere(translation(Vec(-0.5, -0.5, 0.5)) * decimate),
					new Sphere(translation(Vec(-0.5, 0.5, 0.5)) * decimate),
					new Sphere(translation(Vec(0.5, 0.5, -0.5)) * decimate),
					new Sphere(translation(Vec(0.5, -0.5, -0.5)) * decimate),
					new Sphere(translation(Vec(-0.5, -0.5, -0.5)) * decimate),
					new Sphere(translation(Vec(-0.5, 0.5, -0.5)) * decimate),
					new Sphere(translation(Vec(0.0, 0.0, -0.5)) * decimate),
					new Sphere(translation(Vec(0.0, 0.5, 0.0)) * decimate)];
				World world = World(s);

				Transformation cameraTr = rotationZ(angle) * translation(Vec(-1.0, 0.0, 0.0));
				Camera camera;
				if (rayC.flag("orthogonal")) camera = new OrthogonalCamera(aspRat, cameraTr);
				else camera = new PerspectiveCamera(1.0, aspRat, cameraTr);
				
				HDRImage image = new HDRImage(w, h);
				ImageTracer tracer = ImageTracer(image, camera);
				tracer.fireAllRays((Ray r) => world.rayIntersection(r).isNull ?
					Color(1e-5, 1e-5, 1e-5) : Color(255.0, 255.0, 255.0));

				//image.writePFMFile(rayC.option("pfmOutput"));
				image.normalizeImage(0.1);
				image.clampImage;
				image.writePNG(rayC.option("pngOutput").dup);
			}
		);
}