import commandr;
import hdrimage : HDRImage, InvalidPFMFileFormat;
import parameters;
import std.file : FileException;
import std.format : format;
import std.stdio : writeln;

void main(string[] args)
{ 
	auto rayC = new Program("RayCharles", "1.0")
		.add(new Command("pfm2png")
			.add(new Argument("pfmInputFileName",
				"name of the pfm file to convert"))
			.add(new Argument("pngOutputFileName",
				"name of the png file to create/override"))
			.add(new Option("f", "factor",
				"multiplicative factor. Default: 0.2")
				.defaultValue("0.2"))
			.add(new Option("g", "gamma",
				"gamma correction value. Default: 1.0")
				.defaultValue("1.0")))
		.add(new Command("demo")
			.add(new Option("W", "width",
				"width in pixels of the image to render. Default: 640")
				.defaultValue("640"))
			.add(new Option("H", "height",
				"height in pixels of the image to render. Default: 480")
				.defaultValue("480"))
			.add(new Option("alg", "algorithm",
				"algorithm to render an image. Default: flat, options: flat, on-off")
				.defaultValue("flat"))
			.add(new Option("a", "angleDeg",
				"angle of view in degree. Default: 0.0")
				.defaultValue("0.0"))
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
				Pfm2pngParameters* parms;
				try parms = new Pfm2pngParameters(
					[rayC.arg("pfmInputFileName"),
					rayC.arg("pngOutputFileName"),
					rayC.option("factor"),
					rayC.option("gamma")]);
				catch (FileException exc)
				{
					writeln("Error! ", exc.msg);
					return;
				}
				catch (InvalidPfm2pngParms exc)
				{
					writeln("Error! ", exc.msg);
					return;
				}

				try
				{
					HDRImage image = new HDRImage(parms.pfmInput);
					writeln("File "~parms.pfmInput~" has been read from disk");

					image.normalizeImage(parms.factor);
					image.clampImage;

					image.writePNG(parms.pngOutput.dup, parms.gamma);
					writeln("File "~parms.pngOutput~" has been written to disk");
				}
				catch (InvalidPFMFileFormat exc)
				{
					writeln(format("Error! [%s] is not a PFM file: ", parms.pfmInput), exc.msg);
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
				import renderer : FlatRenderer, OnOffRenderer, Renderer;
				import shapes : AABox, Shape, Sphere, World;
				import transformations : rotationZ, rotationY, scaling, Transformation, translation;
				import materials : CheckeredPigment, Material, DiffuseBRDF, UniformPigment;

				DemoParameters* parms;
				try parms = new DemoParameters(
					[rayC.option("width"),
					rayC.option("height"),
					rayC.option("algorithm"),
					rayC.option("angleDeg"),
					rayC.option("pfmOutput"),
					rayC.option("pngOutput"),
					rayC.flag("orthogonal") == true ? "o" : ""]);
				catch (InvalidDemoParms exc)
				{
					writeln("Error! ", exc.msg);
					return;
				}

				immutable Transformation decimate = scaling(Vec(0.05, 0.05, 0.05));

				immutable Color sphereColor = Color(0.8, 0.02, 0.02);
				UniformPigment p = new UniformPigment(sphereColor);
				DiffuseBRDF sphereBRDF = new DiffuseBRDF(p);
				Material m = Material(sphereBRDF);

	Vec translVec = {1.0, 2.0, 4.0}, scaleVec = {2.0, 3.0, -0.8};
    Transformation scale = scaling(scaleVec);
    Transformation rotY = rotationY(30);
    Transformation transl = translation(translVec);
	Material boxM = {emittedRadiance : new CheckeredPigment(Color(1,0,0), Color(0,1,0))};

				Shape[14] s = [new Sphere(translation(Vec(0.0, 0.0, -0.2)) * decimate, m),
					new Sphere(translation(Vec(0.0, 0.2, 0.0)) * decimate, m),
					new Sphere(translation(Vec(0.0, 0.4, 0.2)) * decimate, m),
					new Sphere(translation(Vec(0.0, 0.4, 0.4)) * decimate, m),
					new Sphere(translation(Vec(0.0, 0.3, 0.5)) * decimate, m),
					new Sphere(translation(Vec(0.0, 0.1, 0.5)) * decimate, m),
					new Sphere(translation(Vec(0.0, 0.0, 0.4)) * decimate, m),
					new Sphere(translation(Vec(0.0, -0.1, 0.5)) * decimate, m),
					new Sphere(translation(Vec(0.0, -0.3, 0.5)) * decimate, m),
					new Sphere(translation(Vec(0.0, 0.0, 0.4)) * decimate, m),
					new Sphere(translation(Vec(0.0, -0.2, 0.0)) * decimate, m),
					new Sphere(translation(Vec(0.0, -0.4, 0.2)) * decimate, m),
					new Sphere(translation(Vec(0.0, -0.4, 0.4)) * decimate, m),
					new AABox(transl *rotY * scale, boxM)];	

				World world = World(s);

				Transformation cameraTr = rotationZ(parms.angle) * translation(Vec(-1.0, 0.0, 0.0));
				Camera camera;
				if (parms.orthogonal) camera = new OrthogonalCamera(parms.aspRat, cameraTr);
				else camera = new PerspectiveCamera(1.0, parms.aspRat, cameraTr);

				HDRImage image = new HDRImage(parms.width, parms.height);
				ImageTracer tracer = ImageTracer(image, camera);

				Renderer renderer;
				if (parms.renderer == "flat")
				{
					renderer = new FlatRenderer(world);
					tracer.fireAllRays((Ray r) => renderer.call(r));
				}
				else
				{
					renderer = new OnOffRenderer(world);
					tracer.fireAllRays((Ray r) => renderer.call(r));
				}

				image.writePFMFile(parms.pfmOutput);
				image.normalizeImage(0.1, 0.1);
				image.clampImage;
				image.writePNG(parms.pngOutput.dup);
			}
		);
}