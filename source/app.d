import colored;
import commandr;
import hdrimage : HDRImage;
import parameters;
import std.stdio : writeln;

void main(string[] args)
{ 
	auto rayC = new Program("RayCharles", "1.0")
	///********************* pfm2png ********************
		.add(new Command("pfm2png")
<<<<<<< HEAD
			.add(new Argument(
				"pfmInputFileName",
				"name of the pfm file to convert"
				))
			.add(new Argument(
				"pngOutputFileName",
				"name of the png file to create/override"
				))
			.add(new Option(
				"f",
				"factor",
				"multiplicative factor. Default: 0.2"
				).defaultValue("0.2"))
			.add(new Option(
				"g",
				"gamma",
				"gamma correction value. Default: 1.0"
				).defaultValue("1.0")))
	///********************* render ********************
		.add(new Command("render")
			.add(new Argument(
				"inputSceneName",
				"name of the file defining the scene"
				))
			.add(new Option(
				"W",
				"width",
				"width in pixels of the image to render. Default: 640"
				).defaultValue("640"))
			.add(new Option(
				"H",
				"height",
				"height in pixels of the image to render. Default: 480"
				).defaultValue("480"))
			.add(new Option(
				"alg",
				"algorithm",
				"algorithm to render an image.
				Default: path, options: flat, onoff, path"
				).defaultValue("path"))
			.add(new Option(
				"pfm",
				"pfmOutput",
				"name of the pfm file to create/override. Default: output.pfm"
				).defaultValue("output.pfm"))
			.add(new Option(
				"png",
				"pngOutput",
				"name of the png file to crete/override. Default: output.png"
				).defaultValue("output.png"))
			.add(new Option(
				"initState",
				"initialState",
				"initial seed for the random generator. Default: 45"
				).defaultValue("45"))
			.add(new Option(
				"initSeq",
				"initialSequence",
				"identifier of the sequence produced by a random generator.
				Default: 54"
				).defaultValue("54"))
			.add(new Option(
				"n",
				"numberOfRays",
				"number of rays departing from each surface point.
				Effective only when --algorithm=path. Default: 10"
				).defaultValue("10"))
			.add(new Option(
				"d",
				"depth",
				"maximum number of rays reflections.
				Effective only when --algorithm=path. Default: 3"
				).defaultValue("3"))
			.add(new Option(
				"spp",
				"samplesPerPixel",
				"number of samples per pixel.
				Allowed perfect squares only. Default: 0"
				).defaultValue("0"))
			.add(new Option(
				"df",
				"declareFloat",
				"declare a variable. The syntax is --declareFloat=NAME:VALUE,
				e.g. --declareFloat=clock:150"
				).repeating))
		.parse(args);

	rayC
		.on(
			"pfm2png",
			(rayC)
			{
				import hdrimage : InvalidPFMFileFormat;
				import std.format : format;

				Pfm2pngParameters* parms;
				try parms = new Pfm2pngParameters([
					rayC.arg("pfmInputFileName"),
					rayC.arg("pngOutputFileName"),
					rayC.option("factor"),
					rayC.option("gamma")
					]);
				catch (InvalidPfm2pngParms exc)
				{
					exc.printError;
					return;
				}

				try
				{
					auto image = new HDRImage(parms.pfmInput);
					writeln(
						"Executed: ".bold.green,
						parms.pfmInput.bold,
						" has been read from disk"
						);
=======
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
				"algorithm to render an image. Default: flat, options: flat, on-off, path")
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
			.add(new Option("initState", "initialState",
				"initial seed for the random generator. Default: 45")
				.defaultValue("45"))
			.add(new Option("initSeq", "initialSequence",
				"Identifier of the sequence produced by a random generator. Default: 54")
				.defaultValue("54"))
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
				MonoTime startReading = MonoTime.currTime;
				HDRImage image = new HDRImage(parms.pfmInput);
				MonoTime endReading = MonoTime.currTime;
				Duration timeElapsedForReading = endReading - startReading;
				writeln("File " ~ parms.pfmInput ~ " has been read from disk");
>>>>>>> origin/pathtracing

				MonoTime startPixelOps = MonoTime.currTime;
				image.normalizeImage(parms.factor);
				image.clampImage;
				MonoTime endPixelOps = MonoTime.currTime;
				Duration timeElapsedForPixelOps = endPixelOps - startPixelOps;

				MonoTime startWriting = MonoTime.currTime;
				image.writePNG(parms.pngOutput.dup, parms.gamma);
				MonoTime endWriting = MonoTime.currTime;
				Duration timeElapsedForWriting = endWriting - startWriting;
				writeln("File " ~ parms.pngOutput ~ " has been written to disk");

<<<<<<< HEAD
					image.writePNG(parms.pngOutput, parms.gamma);
					if (!parms.isOutputPNG) writeln(
						"Warning: ".bold.cyan,
						rayC.arg("pngOutputFileName").bold,
						" automatically renamed to ",
						parms.pngOutput.bold
						);
					writeln(
						"Executed: ".bold.green,
						parms.pngOutput.bold,
						" has been written to disk"
						);
				}
				catch (InvalidPFMFileFormat exc) exc.printError(parms.pfmInput);
			}
		)
		.on(
			"render",
			(rayC)
			{
				import cameras;
				import core.time : Duration, MonoTime;
				import hdrimage : black;
				import pcg;
				import ray;
				import renderers;
				import tokens : GrammarError, InputStream, Scene;

				RenderParameters* parms;
				try parms = new RenderParameters(
					[
						rayC.arg("inputSceneName"),
						rayC.option("width"),
						rayC.option("height"),
						rayC.option("algorithm"),
						rayC.option("pfmOutput"),
						rayC.option("pngOutput"),
						rayC.option("initialState"),
						rayC.option("initialSequence"),
						rayC.option("numberOfRays"),
						rayC.option("depth"),
						rayC.option("samplesPerPixel")
					],
					rayC.options("declareFloat")
					);
				catch (InvalidRenderParms exc)
				{
					exc.printError;
					return;
				}

				auto inputStream = InputStream(parms.sceneFileName);
				Scene scene;
				try scene = inputStream.parseScene(parms.variableTable);
				catch (GrammarError exc)
				{
					exc.printError;
					return;
				}

				auto image = new HDRImage(parms.width, parms.height);
				if (scene.camera.isNull) scene.printCameraWarning;
				auto camera = scene.camera.get(new PerspectiveCamera());
				auto tracer = ImageTracer(image, camera, parms.samplesPerSide);

				// Renderer: flat, onoff, path
				Renderer renderer;
				switch (parms.renderer)
				{
					case Renderers.flat:
						writeln("Using flat renderer");
						renderer = new FlatRenderer(scene.world);
						break;

					case Renderers.onoff:
						writeln("Using onoff renderer");
						renderer = new OnOffRenderer(scene.world);
						break;

					case Renderers.path:
					writeln("Using a path tracer");
						auto randGen = new PCG(
							parms.initialState,
							parms.initialSequence
							);
						renderer = new PathTracer(
							scene.world,
							black,
							randGen,
							parms.numberOfRays,
							parms.depth
							);
						break;

					default:
						return;
				}

				auto startRendering = MonoTime.currTime;
				tracer.fireAllRays((Ray r) => renderer.call(r));
				auto endRendering = MonoTime.currTime;
				Duration timeElapsed = endRendering - startRendering;
				writeln(
					"Executed: ".bold.green,
					"rendering completed in ",
					timeElapsed
					);

				image.writePFMFile(parms.pfmOutput);
				if (!parms.isOutputPFM) writeln(
					"Warning: ".bold.cyan,
					rayC.option("pfmOutput").bold,
					" automatically renamed to ",
					parms.pfmOutput.bold
					);
				writeln(
					"Executed: ".bold.green,
					"HDR image written to ",
					parms.pfmOutput.bold
					);

				image.normalizeImage(1.0);
				image.clampImage;

				image.writePNG(parms.pngOutput.dup);
				if (!parms.isOutputPNG) writeln(
					"Warning: ".bold.cyan,
					rayC.option("pngOutput").bold,
					" automatically renamed to ",
					parms.pngOutput.bold
					);
				writeln(
					"Executed: ".bold.green,
					"PNG image written to ",
					parms.pngOutput.bold);
=======
				writeln("\nReading\t\t\t", timeElapsedForReading, "\nPixel operations\t",
					timeElapsedForPixelOps, "\nWriting\t\t\t", timeElapsedForWriting);
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
			import materials : CheckeredPigment, DiffuseBRDF, Material, SpecularBRDF, UniformPigment;
			import pcg;
			import ray;
			import renderers;
			import shapes;
			import transformations : rotationZ, scaling, Transformation, translation;
			
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
				rayC.flag("orthogonal") == true ? "o" : ""]);
			catch (InvalidDemoParms exc)
			{
				writeln("Error! ", exc.msg);
				return;
			}

			Transformation cameraTr = rotationZ(parms.angle) * translation(Vec(-1.0, 0.0, 1.0));
			Camera camera;
			if (parms.orthogonal) camera = new OrthogonalCamera(parms.aspRat, cameraTr);
			else camera = new PerspectiveCamera(1.0, parms.aspRat, cameraTr);

			HDRImage image = new HDRImage(parms.width, parms.height);
			ImageTracer tracer = ImageTracer(image, camera);

			immutable Color skyColor = black;
			UniformPigment skyPig = new UniformPigment(skyColor);
			DiffuseBRDF skyBRDF = new DiffuseBRDF(skyPig);
			UniformPigment skyEmittedRadiance = new UniformPigment(Color(1.0, 0.9, 0.5));
			Material skyMaterial = Material(skyBRDF, skyEmittedRadiance);
			Transformation skyTransl = translation(Vec(0.0, 0.0, 0.4,));
			Transformation skyScale = scaling(Vec(200.0, 200.0, 200.0));

			immutable Color groundColor1 = {0.3, 0.5, 0.1}, groundColor2 = {0.1, 0.2, 0.5};
			CheckeredPigment groundPig = new CheckeredPigment(groundColor1, groundColor2);
			DiffuseBRDF groundBRDF = new DiffuseBRDF(groundPig);
			Material groundMaterial = Material(groundBRDF);

			immutable Color sphereColor = {0.3, 0.4, 0.8};
			UniformPigment spherePig = new UniformPigment(sphereColor);
			DiffuseBRDF sphereBRDF = new DiffuseBRDF(spherePig);
			Material sphereMaterial = Material(sphereBRDF);

			immutable Color mirrorColor = {0.6, 0.2, 0.3};
			UniformPigment mirrorPig = new UniformPigment(mirrorColor);
			SpecularBRDF mirrorBRDF = new SpecularBRDF(mirrorPig);
			Material mirrorMaterial = Material(mirrorBRDF);
			
			World world = World([new Sphere(skyScale * skyTransl, skyMaterial),
				new Plane(Transformation(), groundMaterial),
				new Sphere(translation(vecZ), sphereMaterial),
				new Sphere(translation(Vec(1.0, 2.5, 0.0)), mirrorMaterial)]);

			Renderer renderer;
			if (parms.renderer == "flat") renderer = new FlatRenderer(world);
			else if (parms.renderer == "on-off") renderer = new OnOffRenderer(world);
			else
			{
				PCG randomGenerator = new PCG(parms.initialState, parms.initialSequence);
				renderer = new PathTracer(world, black, randomGenerator);
>>>>>>> origin/pathtracing
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