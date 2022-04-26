
# RayCharles
<!-- A ray tracer which generates basic photorealistic images. -->
A command-line interface that saves a new `.png` image from an input `.pfm` image.

## Installation
The program runs on Linux, MacOS and Windows, but a D compiler is needed. D official compiler `dmd` is recommended - version 2.098 or later
is guaranteed to work. Latest version of `ldc` is also supported.

The D official site provides [downloads](https://dlang.org/download.html), including third-party downloads, and further informations about compilers for
all the operating systems.

## Usage
Open the shell, enter the unzipped directory and build and run by the command

```bash
dub run -- image.pfm factor gamma image.png
```

where the `.png` extension can be omitted and both `gamma` and `factor` must be positive numbers. While the former is the
[gamma correction](https://en.wikipedia.org/wiki/Gamma_correction), which depends solely on the monitor and should then be fixed, the latter can be
adjusted accordingly to the desired result - typical values are less than one.

Once the building is done, it is possible to run by

```bash
./RayCharles image.pfm factor gamma image.png
```

## Example
If the directory `Source code` contains the file `memorial.pfm`, the file `memorial.png` can be generated through

```bash
dub run -- memorial.pfm 0.1 1 memorial
```

## License
The code is released under the GPL-3.0 [license](LICENSE).
