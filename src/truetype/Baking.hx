/// This is based on implementation at https://github.com/shibukawa/nanovgo/blob/master/fontstashmini/truetype/baking.go
package truetype;

import polygonal.ds.ArrayList;
import haxe.io.Bytes;

typedef BakedChar = {
	// coordinates of bbox in bitmap
	?x0:U16,
	?y0:U16,
	?x1:U16,
	?y1:U16,

	?xoff:Float,
	?yoff:Float,
	?xadvance:Float
}

typedef AlignedQuad = {
	// top-left
	?x0:Float,
	?y0:Float,
	?s0:Float,
	?t0:Float,

	// bottom-right
	?x1:Float,
	?y1:Float,
	?s1:Float,
	?t1:Float
}

class Baking {
	/**
	 * Call getBakedQuad with charIndex = 'character - firstChar', and it creates
	 * the quad you need to draw and advances the current position.
	 *
	 * The coordinate system used assumes y increases downwards.
	 *
	 * Characters will extend both above and below the current position.
	 * @param charData
	 * @param pw
	 * @param ph
	 * @param charIndex
	 * @param xpos
	 * @param ypos
	 * @param openglFillRule
	 */
	public static function getBakedQuad(charData:Array<BakedChar>, pw:Int, ph:Int, charIndex:Int, xpos:Float, ypos:Float,
			?openglFillRule:Bool):{pos:Float, alignedQuad:AlignedQuad} {
		var q:AlignedQuad = {};
		var d3dBias = -0.5;
		if (openglFillRule) {
			d3dBias = 0;
		}
		var ipw = 1 / pw;
		var iph = 1 / ph;
		var b = chardata[charIndex];

		var roundX = Math.floor(xpos + b.xoff + 0.5);
		var roundY = Math.floor(ypos + b.yoff + 0.5);

		q.x0 = roundX + d3dBias;
		q.y0 = roundY + d3dBias;
		q.x1 = roundX + (b.x1 - b.x0) + d3dBias;
		q.y1 = roundY + (b.y1 - b.y0) + d3dBias;

		q.s0 = b.x0 * ipw;
		q.t0 = b.y0 * iph;
		q.s1 = b.x1 * ipw;
		q.t1 = b.y1 * iph;

		return {pos: xpos + b.xadvance, alignedQuad: q};
	}

	/**
	 * offset is the font location (use offset=0 for plain .ttf), pixelHeight is the height of font in pixels. pixels is the bitmap to be filled in characters to bake. This uses a very crappy packing.
	 * @param data
	 * @param offset
	 * @param pixelHeight
	 * @param pixels
	 * @param pw
	 * @param ph
	 * @param firstChar
	 * @param numChars
	 */
	public static function bakeFontBitmap(data:Bytes, offset:Int, pixelHeight:Float, pixels:Bytes, pw:Int, ph:Int, firstChar:Int,
			numChars:Int):{chardata:Bytes, bottomY:Int, rtPixels:Bytes} {


		var f:FontInfo = new FontInfo(data, offset);
		var chardata:ArrayList<BakedChar> = new ArrayList<BakedChar>(96);
		// background of 0 around pixels
		pixels.fill(0, pw * ph, 0);
		var x = 1;
		var y = 1;
		var bottomY = 1;

		var scale = f.scaleForPixelHeight(pixelHeight);
		for (i in 0...numChars) {
			var g = f.findGlyphIndex(firstChar + i);
			var hmetrics = f.getGlyphHMetrics(g);
			var ascent = hmetrics.ascent;
			var bitmapBox = f.getGlyphBitmapBox(g, scale, scale);
			var x0 = bitmapBox.x0;
			var y0 = bitmapBox.y0;
			var x1 = bitmapBox.x1;
			var y1 = bitmapBox.y1;

			var gw = x1 - x0;
			var gh = y1 - y0;

			if ((x + gw + 1) >= pw) {
				// advance to next row
				y = bottomY;
				x = 1;
			}
			if ((y + gh + 1) >= ph) {
				// check if it fits vertically AFTER potentially moving to next row
				bottomY = -i;
				// throw "Doesn't fit";
				return {chardata: chardata, bottomY: bottomY, rtPixels: null};
			}
			if (!((x + gw) < pw)) {
				// "Error x+gw<pw"
				return {chardata: chardata, bottomY: bottomY, rtPixels: null};
			}
			if (!((y + gh) < ph)) {
				// "Error y+gh<ph"
				return {chardata: chardata, bottomY: bottomY, rtPixels: null};
			}
			var tmp = f.makeGlyphBitmap(pixels.sub(x + y * pw, (pixels.length - x + y * pw)), gw, gh, pw, scale, scale, g);
			pixels.blit(x + y * pw, tmp, 0, tmp.length);
			if (chardata.get(i) == null) {
				chardata.set(i, {});
			}
			chardata.get(i).x0 = x;
			chardata.get(i).y0 = y;
			chardata.get(i).x1 = x + gw;
			chardata.get(i).y1 = y + gh;
			chardata.get(i).xadvance = scale * advance;
			chardata.get(i).xoff = x0;
			chardata.get(i).yoff = y0;
			x = x + gw + 2;
			if (y + gh + 2 > bottomY) {
				bottomY = y + gh + 2;
			}
		}
		
		var rtPixels = pixels;

		return {chardata: chardata, bottomY: bottomY, rtPixels: rtPixels};
	}
}
