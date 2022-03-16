module app;

import std.stdio;
import std.conv; // Conversion into different types
import std.math; 



bool areClose(float a, float b, float epsilon=1e-5){

return abs(a-b)<epsilon;
}





struct color{
	float r=0, g=0, b=0;

	color opBinary(string op)(color rhs){
		static if(op == "+" || op == "-" || op == "*"){
			mixin ("return color(r"~op~"rhs.r, g"~op~"rhs.g, b"~op~"rhs.b);");
		}
		else static assert(0, "Operation "~op~" not defined");
	}

	color opBinary(string op:"*")(float alfa){
		mixin ("return color(r"~op~"alfa, g"~op~"alfa, b"~op~"alfa);");
	}

	color opBinaryRight(string op:"*")(float alfa){
		mixin ("return color(r"~op~"alfa, g"~op~"alfa, b"~op~"alfa);");
	}

	bool colorAreClose(color y){

	return areClose(r, y.r) && areClose(g, y.g) && areClose(b, y.b);
	}




unittest{
		HDRImage img = new HDRImage(7,4);
// Unittests
		// Check that valid/invalid coordinates are properly flagged
		assert (img.validCoordinates(img, 0, 0)); 
		assert (img.validCoordinates(img, 6, 3));
		assert (! img.validCoordinates(img, -1, 0));
		assert (! img.validCoordinates(img, 0, -1));
		assert (! img.validCoordinates(img, 7, 0));
		assert (! img.validCoordinates(img, 0, 4));

		// Check that indices in the array are calculated correctly:
		// this kind of test would have been harder to write
		// in the old implementation
		assert (img.pixel_offset(img, 3, 2) == 17);
	
	// Test 1

		color col = {1.0, 2.0, 3.0};
		assert (col.colorAreClose(color(0.999999, 2.0, 3.0)) );

		assert (!col.colorAreClose(color(3.0, 4.0, 5.0)));
		assert (!col.colorAreClose(color(0.99, 2.0, 3.0)));
	// Test 2

		color col1 = {1.0, 2.0, 3.0};  
		color col2 = {5.0, 7.0, 9.0};  

		assert ((col1 + col2).colorAreClose(color(6.0, 9.0, 12.0)));
		assert ((col1 - col2).colorAreClose(color(-4.0, -5.0, -6.0)));
		assert ((col1 * col2).colorAreClose(color(5.0, 14.0, 27.0)));

		color prod_col = color(1.0, 2.0, 3.0) * 2.0;

		assert (prod_col.colorAreClose(color(2.0, 4.0, 6.0)));
		
		assert ((col1*2).colorAreClose(color(2.0, 4.0, 6.0)));
		assert ((2*col1).colorAreClose(color(2.0, 4.0, 6.0)));


	// Test 3

			void test_image_creation(){
				HDRImage img = new HDRImage(7,4);

				assert (img.width == 7);
				assert (img.height == 4);
			}
		test_image_creation();

			void test_coordinates(){
				HDRImage img = new HDRImage(7,4);

				assert (img.validCoordinates(img, 0, 0));
				assert (img.validCoordinates(img, 6, 3));
				assert (!img.validCoordinates(img, -1, 0));
				assert (!img.validCoordinates(img, 0, -1));
				assert (!img.validCoordinates(img, 7, 0));
				assert (!img.validCoordinates(img, 0, 4));
			}
		test_coordinates();

	}

}

/////////////////////////////////////////////////////////////////////////////

class HDRImage{
	int width, height;
	color[] pixels;
	
	this(int w, int h){
		width = w;
		height = h;
		pixels.length = width*height;
	}

// Nuova implementazione

	bool validCoordinates(int x, int y){
		return (x >= 0 && x < this.width && 
				y >= 0 && y < this.height);
	}

	int pixelOffset(int x, int y){
		return y * width + x;
	}

	color getPixel(int x, int y){
    assert (validCoordinates(x, y));
    return pixels[pixelOffset(x, y)];
	}

	void setPixel(int x, int y, color new_color){
    assert (validCoordinates(x, y));
    pixels[pixelOffset(x, y)] = new_color;
	}
	
}

///////////////////////////////////////////////////////////////////////////////////
// Main

void main(string[] args)    
{
	if(args.length != 3){
		writeln("Passare le dimensioni dell'immagine");
		return;
	}

	int w = to!int(args[1]);
	int h = to!int(args[2]);
	HDRImage image = new HDRImage(w,h);




	color b = {100,100,100};	// Creo colore b
	
	image.setPixel(0, 0, b); 		// Setto il pixel in posizione 0y+0 del colore b
	color a = image.getPixel(0,0);	// Prendo il pixel in posixione 0y+0, lo assegno ad a 

	writeln("a", a); 

	
	color c1 = {1.0, 1.0, 1.0};
	color c2 = {2.0, 2.0, 2.0};


assert ((c1 + c2) == color(3.0, 3.0, 3.0)); // Modificando un valore si ha un Assert Error
	writeln("La somma funziona!");
assert ((2 * c1) == color(2.0, 2.0, 2.0));	// Modificando un valore si ha un Assert Error
	writeln("Il prodotto per scalare funziona!");

}