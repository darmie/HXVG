package nanovg;

typedef GlyphPosition = {
    /**
     * Position of the glyph in the input string.
     */
    var str:String;

    /**
     * The x-coordinate of the logical glyph position.
     */
    var x:Float;

   // The bounds of the glyph shape.
    var minx:Float;
    var maxx:Float;
}