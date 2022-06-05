import commandr;
import core.time;
import hdrimage : HDRImage, InvalidPFMFileFormat;
import parameters;
import std.file : FileException;
import std.format : format;
import std.stdio : writeln;

void main(string[] args)
{ 
	auto rayC = new Program("RayCharles", "1.0")
	///********************* pfm2png ********************
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
	///********************* demo ********************
		.add(new Command("demo")
			.add(new Option("W", "width",
				"width in pixels of the image to render. Default: 640")
				.defaultValue("640"))
			.add(new Option("H", "height",
				"height in pixels of the image to render. Default: 480")
				.defaultValue("480"))
			.add(new Option("alg", "algorithm",
				"algorithm to render an image. Default: path, options: flat, on-off, path")
				.defaultValue("path"))
			.add(new Option("a", "angleDeg",
				"angle of view in degree. Default: 0.0")
				.defaultValue("0.0"))
			.add(new Option("pfm", "pfmOutput",
				"name of the pfm file to create/override. Default: output.pfm")
				.defaultValue("output.pfm"))
			.add(new Option("png", "pngOutput",
				"name of the png file to crete/override. Default: output.png")
				.defaultValue("output.png"))
			.add(new Option("initState", "initialState",
				"initial seed for the random generator. Default: 45")
				.defaultValue("45"))
			.add(new Option("initSeq", "initialSequence",
				"identifier of the sequence produced by a random generator. Default: 54")
				.defaultValue("54"))
			.add(new Option("n", "numberOfRays",
				"number of rays departing from each surface point. Effective only when --algorithm=path. Default: 10")
				.defaultValue("10"))
			.add(new Option("d", "depth",
				"maximum number of rays reflections. Effective only when --algorithm=path. Default: 2")
				.defaultValue("2"))
			.add(new Option("spp", "samplesPerPixel",
				"number of samples per pixel. Allowed perfect squares only. Default: 0")
				.defaultValue("0"))
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
				writeln("File " ~ parms.pfmInput ~ " has been read from disk");

				image.normalizeImage(parms.factor);
				image.clampImage;
				image.writePNG(parms.pngOutput.dup, parms.gamma);
				writeln("File " ~ parms.pngOutput ~ " has been written to disk");
			}
			catch (InvalidPFMFileFormat exc)
			{
				writeln(format("Error! [%s] is not a PFM file: ", parms.pfmInput), exc.msg);
				return;
			}
		})
		.on("demo", (rayC)
		{
			import cameras : Camera, ImageTracer, OrthogonalCamera, PerspectiveCamera;
			import geometry : Vec, vecZ;
			import hdrimage : black, Color, white;
			import materials : CheckeredPigment, DiffuseBRDF, ImagePigment, Material, SpecularBRDF, UniformPigment;
			import pcg;
			import ray;
			import renderers;
			import shapes;
			import std.math : cos, PI, sin;
			import transformations;

			DemoParameters* parms;
			try parms = new DemoParameters(
				[rayC.option("width"),
				rayC.option("height"),
				rayC.option("algorithm"),
				rayC.option("angleDeg"),
				rayC.option("pfmOutput"),
				rayC.option("pngOutput"),
				rayC.option("initialState"),
				rayC.option("initialSequence"),
				rayC.option("numberOfRays"),
				rayC.option("depth"),
				rayC.option("samplesPerPixel"),
				rayC.flag("orthogonal") == true ? "o" : ""]);
			catch (InvalidDemoParms exc)
			{
				writeln("Error! ", exc.msg);
				return;
			}

			Transformation cameraTr = translation(Vec(-3.0, 0.0, 4.0));
			Camera camera;
			if (parms.orthogonal) camera = new OrthogonalCamera(parms.aspRat, cameraTr);
			else camera = new PerspectiveCamera(1.0, parms.aspRat, cameraTr);

			HDRImage image = new HDRImage(parms.width, parms.height);
			ImageTracer tracer = ImageTracer(image, camera, parms.samplesPerSide);

/// A Plane as a sky
			UniformPigment skyPig = new UniformPigment(black);
			DiffuseBRDF skyBRDF = new DiffuseBRDF(skyPig);
			UniformPigment skyEmittedRadiance = new UniformPigment(Color(0.62, 0.68, 0.73));
			Material skyMaterial = Material(skyBRDF, skyEmittedRadiance);
			Transformation skyTransl = translation(Vec(0.0, 0.0, 0.4));
			Transformation skyScale = scaling(Vec(200.0, 200.0, 200.0));
/// ***********************************************************************************************
/// Decomment here to have the image required as homework 
/// ***********************************************************************************************
			immutable Color groundColor1 = {0.3, 0.5, 0.1}, groundColor2 = {0.1, 0.2, 0.5};
			CheckeredPigment groundPig = new CheckeredPigment(groundColor1, groundColor2);
			DiffuseBRDF groundBRDF = new DiffuseBRDF(groundPig);
			Material groundMaterial = Material(groundBRDF);

			// immutable Color cylinderColor = {0.69, 0.8, 0.46};
			// UniformPigment cyliderPig = new UniformPigment(cylinderColor);
			// DiffuseBRDF cylinderBRDF = new DiffuseBRDF(cyliderPig);
			// Material cylinderMaterial = Material(cylinderBRDF);

			immutable Color shellColor = {0.3, 0.3, 0.78};
			UniformPigment shellPig = new UniformPigment(shellColor);
			DiffuseBRDF shellBRDF = new DiffuseBRDF(shellPig);
			Material shellMaterial = Material(shellBRDF);

			// immutable Color sphereColor = {0.8, 0.75, 0.3};
			// UniformPigment spherePig = new UniformPigment(sphereColor);
			// DiffuseBRDF sphereBRDF = new DiffuseBRDF(spherePig);
			// Material sphereMaterial = Material(sphereBRDF);

			// immutable Color mirrorColor = {0.6, 0.2, 0.3};
			// UniformPigment mirrorPig = new UniformPigment(mirrorColor);
			// SpecularBRDF mirrorBRDF = new SpecularBRDF(mirrorPig);
			// Material mirrorMaterial = Material(mirrorBRDF);
			
			import geometry : Point;
			World world = World([new Sphere(skyTransl * skyScale, skyMaterial),
				new Plane(Transformation(), groundMaterial),
				//new Cylinder(translation(Vec(0.0, -0.65, 0.0)) * scaling(Vec(0.64, 0.64, 2.0)), cylinderMaterial),
				new CylinderShell(translation(Vec(0.0, 1.0, 4.0)) * rotationY(45), shellMaterial),
				new CylinderShell(1.0, Point(0.0, 1.0, 4.0), Point(0.0, 0.0, 5.0), shellMaterial)
				//new Sphere(translation(Vec(0.0, -1.0, 3.2)) * scaling(Vec(0.76, 0.76, 0.76)), sphereMaterial),
				//new Sphere(translation(Vec(1.0, 2.5, 0.0)), mirrorMaterial)
				]);

/// ***********************************************************************************************
/// Decomment here for the wood
/// ***********************************************************************************************
// 			immutable Color groundColor1 = {0.1, 0.5, 0.1}, groundColor2 = {0.1, 0.5, 0.5};
// 			CheckeredPigment groundPig = new CheckeredPigment(groundColor1, groundColor2);
// 			DiffuseBRDF groundBRDF = new DiffuseBRDF(groundPig);
// 			Material groundMaterial = Material(groundBRDF);

// 			immutable Color mirrorColor = {0.1, 0.4, 0.7};
// 			UniformPigment mirrorPig = new UniformPigment(mirrorColor);
// 			SpecularBRDF mirrorBRDF = new SpecularBRDF(mirrorPig);
// 			Material mirrorMaterial = Material(mirrorBRDF);

//          // This is a tree
// 			HDRImage cylinderImg = new HDRImage("corteccia.pfm");
// 			ImagePigment cylinderPig = new ImagePigment(cylinderImg);
// 			DiffuseBRDF cylinderBRDF = new DiffuseBRDF(cylinderPig);
// 			Material cylinderMaterial = Material(cylinderBRDF);

// 			HDRImage sphereImg = new HDRImage("foglie.pfm");
// 			ImagePigment spherePig = new ImagePigment(sphereImg);
// 			DiffuseBRDF sphereBRDF = new DiffuseBRDF(spherePig);
// 			Material sphereMaterial = Material(sphereBRDF);

// 			World world = World([new Sphere(skyScale * skyTransl, skyMaterial),
// 			 	new Plane(Transformation(), groundMaterial),

// 				new Cylinder(translation(Vec(2.0, 2.0, 0.0)), cylinderMaterial, 0.4),
// 				new Sphere(translation(Vec(2.0, 2.0, 2.2)) * scaling(Vec(0.8, 0.8, 1.2)), sphereMaterial),
// 			 	new Sphere(translation(Vec(1.6, 1.6, 2.0)) * scaling(Vec(0.3, 0.3, 0.3)), sphereMaterial),
// 			 	new Sphere(translation(Vec(2.4, 2.4, 2.5)) * scaling(Vec(0.3, 0.3, 0.3)), sphereMaterial),

// 				new Cylinder(translation(Vec(-2.0, -2.0, 0.0)), cylinderMaterial, 0.4),
// 				new Sphere(translation(Vec(-2.0, -2.0, 2.2)) * scaling(Vec(0.8, 0.8, 1.2)), sphereMaterial),
// 			 	new Sphere(translation(Vec(-1.6, -1.6, 2.0)) * scaling(Vec(0.3, 0.3, 0.3)), sphereMaterial),
// 			 	new Sphere(translation(Vec(-2.4, -2.4, 2.5)) * scaling(Vec(0.3, 0.3, 0.3)), sphereMaterial),

// 				new Cylinder(translation(Vec(-2.0, 2.0, 0.0)), cylinderMaterial, 0.4),
// 				new Sphere(translation(Vec(-2.0, 2.0, 2.0)) * scaling(Vec(0.8, 0.8, 1.2)), sphereMaterial),
// 			 	new Sphere(translation(Vec(-1.6, 1.6, 2.0)) * scaling(Vec(0.3, 0.3, 0.3)), sphereMaterial),
// 			 	new Sphere(translation(Vec(-2.4, 2.4, 2.5)) * scaling(Vec(0.3, 0.3, 0.3)), sphereMaterial),

// 				new Sphere(translation(Vec(0.0, 0.0, 0.0)) * scaling(Vec(1.5, 1.5, 1.5)), mirrorMaterial)
// 			]);
///************************************************************************************************************
			// Renderer: flat, on-off, path
			Renderer renderer;
			if (parms.renderer == "flat") renderer = new FlatRenderer(world);
			else if (parms.renderer == "on-off") renderer = new OnOffRenderer(world);
			else
			{
				PCG randomGenerator = new PCG(parms.initialState, parms.initialSequence);
				renderer = new PathTracer(world, black, randomGenerator, parms.numberOfRays, parms.depth, 5);
			}
			MonoTime startRendering = MonoTime.currTime;
			tracer.fireAllRays((Ray r) => renderer.call(r));
			MonoTime endRendering = MonoTime.currTime;
			Duration timeElapsed = endRendering - startRendering;
			writeln("Rendering completed in ", timeElapsed);

			image.writePFMFile(parms.pfmOutput);
			image.writePNG(parms.pngOutput.dup);
		});
}