package nanovg;

import haxe.io.Bytes;
import haxe.ds.Either;

//
// Text
//
// NanoVG allows you to load .ttf files and use the font to render text.
//
// The appearance of the text can be defined by setting the current text style
// and by specifying the fill color. Common text and font settings such as
// font size, letter spacing and text align are supported. Font blur allows you
// to create simple text effects such as drop shadows.
//
// At render time the font face can be set based on the font handles or name.
//
// Font measure functions return values in local space, the calculations are
// carried in the same resolution as the final rendering. This is done because
// the text glyph positions are snapped to the nearest pixels sharp rendering.
//
// The local space means that values are not rotated or scale as per the current
// transformation. For example if you set font size to 12, which would mean that
// line height is 16, then regardless of the current scaling and rotation, the
// returned line height is always 16. Some measures may vary because of the scaling
// since aforementioned pixel snapping.
//
// While this may sound a little odd, the setup allows you to always render the
// same way regardless of scaling. I.e. following works regardless of scaling:
//
//		var txt:String = "Text me up.";
//		ctx.textBounds(x,y, txt, NULL, bounds);
//		ctx.beginPath();
//		ctx.roundedRect(bounds[0],bounds[1], bounds[2]-bounds[0], bounds[3]-bounds[1]);
//		ctx.fill(vg);
//
// Note: currently only solid color fill is supported for text.
class Font {
	var context:Context;

	/**
	 * Creates font by loading it from the disk from specified file name.
	 *
	 * @param ctx
	 * @param name
	 * @param fileName
	 */
	public function new(ctx:Context, name:String, fileName:String) {
		context = ctx;
	}

	/**
	 * fontIndex specifies which font face to load from a .ttf/.ttc file.
	 * @param name
	 * @param fileName
	 * @param fontIndex
	 */
	public static function createAtIndex(name:String, fileName:String, fontIndex:Int):Font {
		return null;
	}

	/**
	 * Creates font by loading it from the specified memory chunk.
	 * @param name
	 * @param data
	 * @param freeData
	 */
	public static function createFromMem(name:String, data:Bytes, freeData:Int):Font {
		return null;
	}

	/**
	 * fontIndex specifies which font face to load from a .ttf/.ttc file.
	 * @param name
	 * @param data
	 * @param freeData
	 * @param fontIndex
	 * @return Font
	 */
	public static function createFromMemAtIndex(name:String, data:Bytes, freeData:Int, fontIndex:Int):Font {
		return null;
	}

	/**
	 * Finds a loaded font of specified name, and returns handle to it, or null if the font is not found.
	 * @param name
	 * @return Font
	 */
	public static function findFont(name:String):Font {
		return null;
	}

	/**
	 * Adds a fallback font by handle.
	 * @param fallbackFont
	 */
	public function fallbackFont(fallbackFont:FontFace) {}

	/**
	 * Resets fallback fonts by handle.
	 */
	public static function resetFallbackFonts(baseFont:FontFace) {}


	function flushTextTexture(){

	}

	function allocTextAtlas():Bool{
		return false;
	}

}

/**
 * FontFace abstract type that can be one of Font or String (name of the font)
 */
abstract FontFace(Either<Font, String>) from Either<Font, String> to Either<Font, String> {
	@:from inline static function fromA(a:Font):FontFace {
		return Left(a);
	}

	@:from inline static function fromB(b:String):FontFace {
		return Right(b);
	}

	@:to inline function toA():Null<Font>
		return switch (this) {
			case Left(a): a;
			default: null;
		}

	@:to inline function toB():Null<String>
		return switch (this) {
			case Right(b): b;
			default: null;
		}
}
