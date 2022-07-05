import commandr;
import hdrimage : HDRImage;
import parameters;
import std.stdio : writeln;

void main(string[] args)
{ 
	auto rayC = new Program("RayCharles", "1.0")
	///********************* pfm2png ********************
		.add(new Command("pfm2png")
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
					writeln(format(
						"File %s has been read from disk",
						parms.pfmInput
						));

					image.normalizeImage(parms.factor);
					image.clampImage;

					image.writePNG(parms.pngOutput, parms.gamma);
					writeln(format(
						"File %s has been written to disk",
						parms.pngOutput
						));
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
				if (scene.camera.isNull) scene.cameraWarning;
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
				writeln("Rendering completed in ", timeElapsed);

				image.writePFMFile(parms.pfmOutput);
				writeln("HDR image written to ", parms.pfmOutput);

				image.normalizeImage(1.0);
				image.clampImage;

				image.writePNG(parms.pngOutput.dup);
				writeln("PNG image written to ", parms.pngOutput);
			}
		);
}