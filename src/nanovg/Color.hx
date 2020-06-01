package nanovg;

typedef TColor = {
    r:Float,
    g:Float,
    b:Float,
    a:Float
}

/**
 * Nanovg Color
 */
abstract Color(TColor) {
    inline function new(color:TColor) {
        this = color;
    }

    @:from
    static public function fromArray(c:Array<Float>) {
        return new Color({
            r: c[0],
            g: c[1],
            b: c[2],
            a: c[3]
        });
    }

    @:to public function toArray(){
        return [this.r, this.g, this.b, this.a];
    }

    //
    // Color utils
    //
    // Colors in NanoVG are stored as unsigned ints in ABGR format.


    /**
     * Returns a color value from red, green, blue values. Alpha will be set to 255 (1.0f).
     * @param r 
     * @param g 
     * @param b 
     * @return Color
     */
    public static function RGB(r:Int, g:Int, b:Int):Color {
        return null;
    }

    /**
     * Returns a color value from red, green, blue values. Alpha will be set to 1.0f.
     * @param r 
     * @param g 
     * @param b 
     * @return Color
     */
    public static function RGBf(r:Float, g:Float, b:Float):Color {
        return null;
    }

    /**
     * Returns a color value from red, green, blue values and alpha values
     * @param r 
     * @param g 
     * @param b 
     * @param a 
     * @return Color
     */
    public static function RGBA(r:Int, g:Int, b:Int, a:Int):Color {
        return null;
    }

    /**
     * Returns a color value from red, green, blue values and alpha values
     * @param r 
     * @param g 
     * @param b 
     * @param a 
     * @return Color
     */
    public static function RGBAf(r:Float, g:Float, b:Float, a:Float):Color {
        return null;
    }

    /**
     * Linearly interpolates from color c0 to c1, and returns resulting color value.
     * @param c0 
     * @param c1 
     * @param u 
     */
    public static function lerpRGBA(c0:Color, c1:Color, u:Float):Color {
        return null;
    }

    /**
     * Sets transparency of a color value.
     * @param c0 
     * @param a 
     */
    public static function transRGBA(c0:Color, a:Int):Color {
        return null;
    }

    /**
     * Sets transparency of a color value.
     * @param c0 
     * @param a 
     */
    public static function transRGBAf(c0:Color, a:Float):Color {
        return null;
    }

    /**
     * Returns color value specified by hue, saturation and lightness.
     * HSL values are all in range [0..1], alpha will be set to 255.
     * @param h 
     * @param s 
     * @param l 
     * @return Color
     */
    public static function HSL(h:Float, s:Float, l:Float):Color {
        return null;
    }

    /**
     * Returns color value specified by hue, saturation and lightness.
     * HSL values are all in range [0..1], alpha will be set to 255.
     * @param h 
     * @param s 
     * @param l 
     * @param a 
     */
    public static function HSLA(h:Float, s:Float, l:Float, a:Int):Color {
        return null;
    }


}