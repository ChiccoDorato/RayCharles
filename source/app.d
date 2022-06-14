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
			import cameras;
			import geometry : Point, Vec, vecX, vecZ;
			import hdrimage : black, Color, white;
			import materials;
			import pcg;
			import ray;
			import renderers;
			import shapes;
			import std.algorithm : max, min;
			import std.math : PI;
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

			auto cameraTr = rotationZ(30 - 0.25 * parms.angle) * rotationY(0.015 * parms.angle)
				* translation(Vec(-1.4 + 0.75 * PI / 60.0 * 0.14 * parms.angle, 0.0, 1.4));
			Camera camera;
			if (parms.orthogonal) camera = new OrthogonalCamera(parms.aspRat, cameraTr);
			else camera = new PerspectiveCamera(1.0, parms.aspRat, cameraTr);

			auto image = new HDRImage(parms.width, parms.height);
			auto tracer = ImageTracer(image, camera, parms.samplesPerSide);

/// A Plane as a sky
			auto skyPig = new UniformPigment(black);
			auto skyEmittedRadiance = new UniformPigment(Color(1.0, 0.9, 0.5));
			auto skyMaterial = Material(new DiffuseBRDF(skyPig), skyEmittedRadiance);
			immutable skyTransl = translation(Vec(0.0, 0.0, 0.4));
			immutable skyScale = scaling(Vec(200.0, 200.0, 200.0));

/// ***********************************************************************************************
/// Decomment here to have the image required as homework
/// ***********************************************************************************************
			// immutable groundColor1 = Color(0.3, 0.5, 0.1), groundColor2 = Color(0.1, 0.2, 0.5);
			// auto groundPig = new CheckeredPigment(groundColor1, groundColor2);
			// auto groundMaterial = Material(new DiffuseBRDF(groundPig));

			// auto spherePig = new UniformPigment(Color(0.3, 0.4, 0.8));
			// // auto spherePig = new ImagePigment(new HDRImage("worldmap.pfm"));
			// auto sphereMaterial = Material(new DiffuseBRDF(spherePig));

			// auto mirrorPig = new UniformPigment(Color(0.6, 0.2, 0.3));
			// auto mirrorMaterial = Material(new SpecularBRDF(mirrorPig));

			// World world = World([new Sphere(skyTransl * skyScale, skyMaterial),
			// 	new Plane(Transformation(), groundMaterial),
			// 	new Sphere(translation(vecZ), sphereMaterial),
			// 	new Sphere(translation(Vec(1.0, 2.5, 0.0)), mirrorMaterial)
			// 	]);

/// ***********************************************************************************************
/// Decomment here for the table
/// ***********************************************************************************************
			immutable groundColor1 = Color(0.3, 0.5, 0.1), groundColor2 = Color(0.1, 0.2, 0.5);
			auto groundPig = new CheckeredPigment(groundColor1, groundColor2);
			auto groundMaterial = Material(new DiffuseBRDF(groundPig));

			auto topPig = new UniformPigment(Color(0.75, 0.6, 0.2));
			auto topMaterial = Material(new DiffuseBRDF(topPig));
			immutable topWidth = 0.86, topLength = 1.5, topHeight = 0.03, topDist = -0.3;
			immutable edge = topLength / 2.0;
			immutable topScale = scaling(Vec(topWidth, topLength, topHeight));

			auto legPig = new UniformPigment(Color(0.82, 0.64, 0.1));
			auto legMaterial = Material(new DiffuseBRDF(legPig));
			immutable legR = 0.027, legH = 0.75;
			immutable xMinLeg = 0.068, xMaxLeg = topWidth - xMinLeg, yLeg = edge - xMinLeg;

			auto spherePig = new ImagePigment(new HDRImage("worldmap.pfm"));
			auto sphereMaterial = Material(new DiffuseBRDF(spherePig));
			immutable sphereR = 0.14;

			// sphereOmega is the angular velocity in degrees per frame (dpf), e.g. 3.0dpm and 30fps -> 90°/s
			// Same idea for g = 9.81m/s^2: 30fps -> 9.81 / 900 m/f^2
			immutable omega = 3.0, yVel = -omega * PI / 180.0 * sphereR, yTransl = yVel * parms.angle;
			immutable parabY = yTransl - (-edge);
			immutable parabZ = parabY > 0.0 ?
				0.0 : -9.81 / (810_000.0 * 2.0 * yVel * yVel) * parabY * parabY;

			// Wait for the translation until pipe is defined
			immutable sphereScale = scaling(Vec(sphereR, sphereR, sphereR));
			immutable sphereRot = rotationX(omega * parms.angle);
			immutable xCenter = topDist + topWidth / 2.0;

			auto pipePig = new UniformPigment(Color(0.62, 0.1, 0.3));
			auto pipeMaterial = Material(new DiffuseBRDF(pipePig));
			immutable pipeR = 1.6 * sphereR;
			// Sphere enter the cylinderShell when angle = 300.0
			immutable cylYPos = yVel * 300.0, parabY300 = cylYPos - (-edge);
			immutable parabZ300 = -9.81 / (810_000.0 * 2.0 * yVel * yVel) * parabY300 * parabY300;
			immutable pipeMax = Point(xCenter, cylYPos, legH + topHeight + sphereR + parabZ300);
			immutable pipeMin = Point(xCenter, pipeMax.y + parabY300, pipeMax.z + parabZ300);

			auto supportPig = new UniformPigment(Color(0.62, 0.1, 0.3));
			auto supportMaterial = Material(new DiffuseBRDF(supportPig));
			immutable supportR = 0.03;
			immutable pipeDiff = pipeMax - pipeMin, pipeInf = Vec(pipeMax.x, pipeMax.y, pipeMax.z - pipeR);
			immutable support1H = pipeMax.z - 0.28 * pipeDiff.z, support2H = pipeMax.z - 0.72 * pipeDiff.z;

			// When parms.angle = 355.0 the sphere touches the bottom of the pipe
			immutable pipeZMin = sphereR + parabZ300 + parabZ300 / parabY300 * (yTransl - pipeMax.y) - pipeR;
			immutable sphereTransl = translation(Vec(xCenter,
				yTransl,
				legH + topHeight + sphereR + max(parabZ, pipeZMin)));

			World world = World([new Sphere(skyTransl * skyScale, skyMaterial),
				new Plane(Transformation(), groundMaterial),
				new CylinderShell(legR, legH, Vec(topDist + xMinLeg, yLeg, 0.0), legMaterial),
				new CylinderShell(legR, legH, Vec(topDist + xMaxLeg, yLeg, 0.0), legMaterial),
				new CylinderShell(legR, legH, Vec(topDist + xMaxLeg, -yLeg, 0.0), legMaterial),
				new CylinderShell(legR, legH, Vec(topDist + xMinLeg, -yLeg, 0.0), legMaterial),
				new AABox(translation(Vec(topDist, -edge, legH)) * topScale, topMaterial),
				new Sphere(sphereTransl * sphereRot * sphereScale, sphereMaterial),
				new CylinderShell(pipeR, pipeMin, pipeMax, pipeMaterial),
				new CylinderShell(supportR, -support1H, pipeInf - 0.72 * pipeDiff, supportMaterial),
				new CylinderShell(supportR, -support2H, pipeInf - 0.28 * pipeDiff, supportMaterial)
				]);

/// ***********************************************************************************************
/// Decomment here for the wood
/// ***********************************************************************************************
			// immutable groundColor1 = Color(0.1, 0.5, 0.1), groundColor2 = Color(0.1, 0.5, 0.5);
			// auto groundPig = new CheckeredPigment(groundColor1, groundColor2);
			// auto groundMaterial = Material(new DiffuseBRDF(groundPig));

			// auto mirrorPig = new UniformPigment(Color(0.1, 0.4, 0.7));
			// auto mirrorMaterial = Material(new SpecularBRDF(mirrorPig));

        	// // This is a tree
			// auto cylinderPig = new ImagePigment(new HDRImage("corteccia.pfm"));
			// auto cylinderMaterial = Material(new DiffuseBRDF(cylinderPig));

			// auto spherePig = new ImagePigment(new HDRImage("foglie.pfm"));
			// auto sphereMaterial = Material(new DiffuseBRDF(spherePig));

			// World world = World([new Sphere(skyScale * skyTransl, skyMaterial),
			//  	new Plane(Transformation(), groundMaterial),

			// 	new Cylinder(translation(Vec(2.0, 2.0, 0.0)), cylinderMaterial, 0.4),
			// 	new Sphere(translation(Vec(2.0, 2.0, 2.2)) * scaling(Vec(0.8, 0.8, 1.2)), sphereMaterial),
			//  	new Sphere(translation(Vec(1.6, 1.6, 2.0)) * scaling(Vec(0.3, 0.3, 0.3)), sphereMaterial),
			//  	new Sphere(translation(Vec(2.4, 2.4, 2.5)) * scaling(Vec(0.3, 0.3, 0.3)), sphereMaterial),

			// 	new Cylinder(translation(Vec(-2.0, -2.0, 0.0)), cylinderMaterial, 0.4),
			// 	new Sphere(translation(Vec(-2.0, -2.0, 2.2)) * scaling(Vec(0.8, 0.8, 1.2)), sphereMaterial),
			//  	new Sphere(translation(Vec(-1.6, -1.6, 2.0)) * scaling(Vec(0.3, 0.3, 0.3)), sphereMaterial),
			//  	new Sphere(translation(Vec(-2.4, -2.4, 2.5)) * scaling(Vec(0.3, 0.3, 0.3)), sphereMaterial),

			// 	new Cylinder(translation(Vec(-2.0, 2.0, 0.0)), cylinderMaterial, 0.4),
			// 	new Sphere(translation(Vec(-2.0, 2.0, 2.0)) * scaling(Vec(0.8, 0.8, 1.2)), sphereMaterial),
			//  	new Sphere(translation(Vec(-1.6, 1.6, 2.0)) * scaling(Vec(0.3, 0.3, 0.3)), sphereMaterial),
			//  	new Sphere(translation(Vec(-2.4, 2.4, 2.5)) * scaling(Vec(0.3, 0.3, 0.3)), sphereMaterial),

			// 	new Sphere(translation(Vec(0.0, 0.0, 0.0)) * scaling(Vec(1.5, 1.5, 1.5)), mirrorMaterial)
			// ]);
///************************************************************************************************************

			// Renderer: flat, on-off, path
			Renderer renderer;
			if (parms.renderer == "on-off") renderer = new OnOffRenderer(world);
			else if (parms.renderer == "flat") renderer = new FlatRenderer(world);
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