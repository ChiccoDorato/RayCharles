# RayCharles
A simple ray tracer which generates photorealistic images in pfm and png format. It also allows to convert an input pfm image into a new png image.

## Installation
To run the program on Linux, MacOS or Windows a D compiler is needed. Even though not mandatory, we strongly recommend to download also the package manager DUB. All the informations given here assume that the user has installed DUB.

**Compiler.** D official compiler `dmd` - version 2.098 or later - works perfectly fine, but latest version of `ldc2` offers better performances, generating images in roughly one third of the time. The D official site provides [downloads](https://dlang.org/download.html), including third-party downloads, and further informations about compilers. Note that `gdc`, part of `gcc` starting with version 9.0, is not supported at the moment.

**Package manger.** Details about DUB installation are provided on [DUB github page](https://github.com/dlang/dub#Installation) - latest version is the best choice. Be aware that upgrades via package management system may install a newer version than the [last official release](https://github.com/dlang/dub/releases) but that most of the times it should not alarm.

**Other requisites.** The highly portable FOSS FFmpeg has been used in the script RayCharles.sh to generate animations. If you want to take full advantage of RayCharles capabilities go [here](https://ffmpeg.org/download.html) to download it.

## Usage
This command-line interface implements two functionalities: `render` generates a photorealistic image for a scene given in input as a txt, while `pfm2png` allows to convert a pfm file into a png one.

Moreover, a dedicated script allows to render a scene with different angles and create animations. This function uses the ldc2 compiler: if you feel confident read below to know how to select the compiler and modify properly the script.

**Render.** In order to use the ray tracer open the shell, enter the unzipped directory, then build and run through

```bash
$ dub run -- render inputScene.txt
```

which saves the files output.pfm and output.png in the directory. The generation of new images will override any existing file in the directory with the same name. This could be very unfortunate since the output may be produced in several minutes. To avoid the risk you can give names of your choice: this and other features are available for consultation typing `dub run -- render --help`, or simply `./RayCharles render --help` if the building has already been done.

You can try this command with the scenes supplied in the examples directory, to learn how to give life to your own ideas [see below](#write-a-scene).

IMPORTANT: to reduce the execution time require the use of a specific compiler through `dub run --compiler ldc2 -- render` (DUB uses `dmd` by default).

**Pfm2png.** The same remains valid for the `pfm2png` command, except it requires two compulsory argument, i.e. the name of the image to convert and the output png file (the extension .png can be omitted). Using the alternative approach of building first and then executing:

```bash
$ dub build
$ ./RayCharles pfm2png image.pfm image.png
```

Again, `dub build --compiler ldc2` select another compiler (not particularly useful for this command). For more informations use the `--help` option.

**Animations.** It is also possible to generate animations: declare a variable named "angle" in the txt file to render and a camera which uses this variable, then type in the shell

```bash
$ ./RayCharles.sh inputScene.txt animationName
```

and the file animationName.mp4 will be inserted into the animations subdirectory. All the frames are collected in the pngFrames subdirectory. By default the images are rendered with `--depth 3` and `--samplesPerPixels 4` (see render help menu). Feel free to edit the script as you wish.

## Examples
**Render.**

<img src="generatedImages/scarecrow.png" width="480"/>

**Pfm2png.**

| <img src="generatedImages/memorial-f02.png" width="380"/> | <img src="generatedImages/memorial-f04.png" width="380"/> |
| :---: | :---: |
| Gamma = 1.0, factor = 0.2 | Gamma = 1.0, factor = 0.4 |

**Animations.**

| ![Globe rolling on table](animations/rolling.gif) | ![Igloo with giant penguins](animations/igloo.gif) |
| :---: | :---: |

## Write a scene
Surely not professional, but cool images! We don't doubt you have better ideas and a far way superior imagination to create memorable scenes. The quesition is: how?

A fast way is to take a cue from the files in the examples directory. Familiarizing with them is quite straightforward nonetheless we provide a thorough description of the syntax which is used by RayCharles. Keep in mind that although spaces and endline characters are ignored they can still make the file more readable for humans. Also comments might help: `# This is a comment in a scene`.

Let's start from the numerical types:
- **Declare numerical variables:** `float newVariable(value)`, where the name of the variable must begin with an alphanumeric character or with the underscore and the value must be a number. All the variables can be overridden in the command line with `--declareFloat`.
- **Colors:** `[r, g, b]`, where r, g and b are three non negative numbers quantifying red, green and blue respectively.
- **Vectors:** `(x, y, z)`, where x points inside the monitor, y towards left and z up. Every component is a real number.

Now it is possible to move on and start to describe a scene. Before shapes can enter the scene with their concreteness, one should know the position from which they are observed and how to place them.
- **Camera:** `camera(typeOfCamera, transformation, aspectRatio, distance)`. Two types of camera are supported, orthogonal and perspective. Transformations are explained right below and can be composed with *, being applied in right-to-left order. The aspect ratio is preferable to be equal to the width of the image over its height, while distance represent the distance of the observer from the screen (note that can be modified by the transformation).
- **Transformations:** desired transformation ca be obtained combining the following commands.
    1. `identity`, useful if the object (or the observer) need not be moved.
    2. `translation([x, y, z])` translates by a vector whose syntax is the one mentioned above.
    3. `rotationX(angle)` rotates along x-axis by angle, which can be a number or the name of a variable declared as mentioned above. Angle must be expressed in degrees.
    4. `rotationY(angle)`, analogous to the previous along y-axis.
    5. `rotationZ(angle)`, analogous to the previous along z-axis.
    6. `scaling([x, y, z])` stretches the components along an axis by the corresponding vecotr component. For example, if one wants to double the height of an object keeping unvaried his other sizes, they will apply `scaling([1.0, 1.0, 2.0])`.

## License
The code is released under the GPL-3.0 [license](LICENSE).
