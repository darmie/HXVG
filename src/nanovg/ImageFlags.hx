package nanovg;

enum abstract ImageFlags(Int) from Int to Int {
    inline function new(i:Int) {
        this = i;
    }
	var GENERATE_MIPMAPS = 1 << 0; // Generate mipmaps during creation of the image.
	var REPEATX = 1 << 1; // Repeat image in X direction.
	var REPEATY = 1 << 2; // Repeat image in Y direction.
	var FLIPY = 1 << 3; // Flips (inverses) image in Y direction when rendered.
	var PREMULTIPLIED = 1 << 4; // Image data has premultiplied alpha.
	var NEAREST = 1 << 5; // Image interpolation is Nearest instead Linear
}
