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
	///********************* render ********************
		.add(new Command("render")
			.add(new Argument("inputSceneName",
				"name of the file defining the scene"))
			.add(new Option("W", "width",
				"width in pixels of the image to render. Default: 640")
				.defaultValue("640"))
			.add(new Option("H", "height",
				"height in pixels of the image to render. Default: 480")
				.defaultValue("480"))
			.add(new Option("alg", "algorithm",
				"algorithm to render an image. Default: path, options: flat, on-off, path")
				.defaultValue("path"))
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
				"maximum number of rays reflections. Effective only when --algorithm=path. Default: 3")
				.defaultValue("3"))
			.add(new Option("spp", "samplesPerPixel",
				"number of samples per pixel. Allowed perfect squares only. Default: 0")
				.defaultValue("0"))
			.add(new Option("df", "declareFloat",
				"declare a variable. The syntax is --declareFloat=NAME:VALUE, e.g. --declareFloat=clock:150")
				.repeating))
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
				writeln(format("Error! %s is not a PFM file: ", parms.pfmInput), exc.msg);
				return;
			}
		})
		.on("render", (rayC)
		{
			import cameras;
			import hdrimage : black, Color, white;
			import materials;
			import pcg;
			import ray;
			import renderers;
			import shapes;
			import tokens;
			import transformations;

			RenderParameters* parms;
			try parms = new RenderParameters(
				[rayC.arg("inputSceneName"),
				rayC.option("width"),
				rayC.option("height"),
				rayC.option("algorithm"),
				rayC.option("pfmOutput"),
				rayC.option("pngOutput"),
				rayC.option("initialState"),
				rayC.option("initialSequence"),
				rayC.option("numberOfRays"),
				rayC.option("depth"),
				rayC.option("samplesPerPixel")],
				rayC.options("declareFloat")
				);
			catch (FileException exc)
			{
				writeln("Error! ", exc.msg);
				return;
			}
			catch (InvalidRenderParms exc)
			{
				writeln("Error! ", exc.msg);
				return;
			}

			auto inputStream = InputStream(parms.sceneFileName);
			Scene scene;
			try
			{
				scene = inputStream.parseScene(parms.variableTable);
			}
			catch (GrammarError exc)
			{
				writeln("Error! ", exc.msg);
				return;
			}

			auto image = new HDRImage(parms.width, parms.height);
			if (scene.cam.isNull)
				writeln("\nWARNING: no camera provided. A default perspective camera will be used\n");
			auto camera = scene.cam.get(new PerspectiveCamera());
			auto tracer = ImageTracer(image, camera, parms.samplesPerSide);

/// ***********************************************************************************************
/// Decomment here for the table
/// ***********************************************************************************************
			// immutable topDist = -0.3, edge = topLength / 2.0;

			// // sphereOmega is the angular velocity in degrees per frame (dpf), e.g. 3.0dpm and 30fps -> 90°/s
			// // Same idea for g = 9.81m/s^2: 30fps -> 9.81 / 900 m/f^2
			// immutable omega = 3.0, yVel = -omega * PI / 180.0 * sphereR, yTransl = yVel * parms.variableTable["clock"];
			// immutable parabY = yTransl - (-edge);
			// immutable parabZ = parabY > 0.0 ?
			// 	0.0 : -9.81 / (810_000.0 * 2.0 * yVel * yVel) * parabY * parabY;

			// // Wait for the translation until pipe is defined
			// immutable sphereRot = rotationX(omega * parms.variableTable["clock"]);
			// immutable xCenter = topDist + topWidth / 2.0;

			// auto pipePig = new UniformPigment(Color(0.62, 0.1, 0.3));
			// auto pipeMaterial = Material(new DiffuseBRDF(pipePig));
			// immutable pipeR = 1.6 * sphereR;
			// // Sphere enter the cylinderShell when angle = 300.0
			// immutable cylYPos = yVel * 300.0, parabY300 = cylYPos - (-edge);
			// immutable parabZ300 = -9.81 / (810_000.0 * 2.0 * yVel * yVel) * parabY300 * parabY300;
			// immutable pipeMax = Point(xCenter, cylYPos, legH + topHeight + sphereR + parabZ300);
			// immutable pipeMin = Point(xCenter, pipeMax.y + parabY300, pipeMax.z + parabZ300);

			// auto supportPig = new UniformPigment(Color(0.62, 0.1, 0.3));
			// auto supportMaterial = Material(new DiffuseBRDF(supportPig));
			// immutable supportR = 0.03;
			// immutable pipeDiff = pipeMax - pipeMin, pipeInf = Vec(pipeMax.x, pipeMax.y, pipeMax.z - pipeR);
			// immutable support1H = pipeMax.z - 0.28 * pipeDiff.z, support2H = pipeMax.z - 0.72 * pipeDiff.z;

			// // When parms.variableTable["clock"] = 355.0 the sphere touches the bottom of the pipe
			// immutable pipeZMin = sphereR + parabZ300 + parabZ300 / parabY300 * (yTransl - pipeMax.y) - pipeR;
			// immutable sphereTransl = translation(Vec(xCenter,
			// 	yTransl,
			// 	legH + topHeight + sphereR + max(parabZ, pipeZMin)));

			// World world = World([
			// 	new Sphere(sphereTransl * sphereRot * sphereScale, sphereMaterial),
			// 	new CylinderShell(pipeR, pipeMin, pipeMax, pipeMaterial),
			// 	new CylinderShell(supportR, -support1H, pipeInf - 0.72 * pipeDiff, supportMaterial),
			// 	new CylinderShell(supportR, -support2H, pipeInf - 0.28 * pipeDiff, supportMaterial)
			// 	]);
///************************************************************************************************************

			// Renderer: flat, on-off, path
			Renderer renderer;
			switch (parms.renderer)
			{
				case ValidRenderers.flat:
					writeln("Using flat renderer");
					renderer = new FlatRenderer(scene.world);
					break;

				case ValidRenderers.onoff:
					writeln("Using on-off renderer");
					renderer = new OnOffRenderer(scene.world);
					break;

				case ValidRenderers.path:
				writeln("Using a path tracer");
					auto randGen = new PCG(parms.initialState, parms.initialSequence);
					renderer = new PathTracer(scene.world, black, randGen, parms.numberOfRays, parms.depth);
					break;

				default:
					return;
			}

			MonoTime startRendering = MonoTime.currTime;
			tracer.fireAllRays((Ray r) => renderer.call(r));
			MonoTime endRendering = MonoTime.currTime;
			Duration timeElapsed = endRendering - startRendering;
			writeln("Rendering completed in ", timeElapsed);

			image.writePFMFile(parms.pfmOutput);
			writeln("HDR image written to ", parms.pfmOutput);
			image.normalizeImage(1.0);
			image.clampImage;
			image.writePNG(parms.pngOutput.dup);
			writeln("PNG image written to ", parms.pngOutput);
		});
}