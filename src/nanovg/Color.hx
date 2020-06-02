package nanovg;

import haxe.io.FPHelper;

typedef TColor = {
	?r:Float,
	?g:Float,
	?b:Float,
	?a:Float
}

/**
 * Nanovg Color
 */
@:forward(r, g, b, a)
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

	@:to public function toArray() {
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
		return RGBA(r, g, b, 255);
	}

	/**
	 * Returns a color value from red, green, blue values. Alpha will be set to 1.0f.
	 * @param r
	 * @param g
	 * @param b
	 * @return Color
	 */
	public static function RGBf(r:Float, g:Float, b:Float):Color {
		return RGBAf(r, g, b, 255);
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
		var color:Color = new Color({});
		color.r = r / 255.0;
		color.g = g / 255.0;
		color.b = b / 255.0;
		color.a = a / 255.0;

		return color;
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
		var color:Color = new Color({});
		color.r = r;
		color.g = g;
		color.b = b;
		color.a = a;

		return color;
	}

	/**
	 * Linearly interpolates from color c0 to c1, and returns resulting color value.
	 * @param c0
	 * @param c1
	 * @param u
	 */
	public static function lerpRGBA(c0:Color, c1:Color, u:Float):Color {
		var i:Int;
		var oneminu:Float;
		var cint = [];

		u = MathExt.clamp(u, 0.0, 1.0);
		oneminu = 1.0 - u;
		for (i in 0...4) {
			cint[i] = c0.toArray()[i] * oneminu + c1.toArray()[i] * u;
		}
		return fromArray(cint);
	}

	/**
	 * Sets transparency of a color value.
	 * @param c0
	 * @param a
	 */
	public static function transRGBA(c0:Color, a:Int):Color {
		c0.a = a / 255.0;
		return c0;
	}

	/**
	 * Sets transparency of a color value.
	 * @param c0
	 * @param a
	 */
	public static function transRGBAf(c0:Color, a:Float):Color {
		c0.a = a;
		return c0;
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
		return HSLA(h,s,l,255);
    }
    
    static function hue(h:Float, m1:Float, m2:Float) {
        if (h < 0) h += 1;
        if (h > 1) h -= 1;
        if (h < 1.0/6.0)
            return m1 + (m2 - m1) * h * 6.0;
        else if (h < 3.0/6.0)
            return m2;
        else if (h < 4.0/6.0)
            return m1 + (m2 - m1) * (2.0/3.0 - h) * 6.0;
        return m1;
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
		var m1:Int, m2:Int;
        var col:Color = new Color({});
        
        h = h % 1.0;
        if (h < 0.0) h += 1.0;
        s = MathExt.clamp(s, 0.0, 1.0);
        l = MathExt.clamp(l, 0.0, 1.0);
        m2 = FPHelper.floatToI32(l <= 0.5 ? (l * (1 + s)) : (l + s - l * s));
        m1 = FPHelper.floatToI32(2 * l - m2);
        col.r = MathExt.clamp(hue(h + 1.0/3.0, m1, m2), 0.0, 1.0);
        col.g = MathExt.clamp(hue(h, m1, m2), 0.0, 1.0);
        col.b = MathExt.clamp(hue(h - 1.0/3.0, m1, m2), 0.0, 1.0);
        col.a = a/255.0;
        return col;
	}
}
