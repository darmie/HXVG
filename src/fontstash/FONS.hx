package fontstash;

import sys.io.File;
import haxe.ds.IntMap;
import truetype.FontInfo;
import haxe.io.Bytes;

class FONS {
	public static final INVALID = -1;
	public static final VERTEX_COUNT = 1024;
	public static final SCRATCH_BUF_SIZE = 16000;
	public static final INIT_FONTS = 4;
	public static final INIT_GLYPHS = 256;
    public static final INIT_ATLAS_NODES = 256;
    
    public static final INIT_FONTIMAGE_SIZE  =512;
    public static final MAX_FONTIMAGE_SIZE   =2048;
    public static final MAX_FONTIMAGES       =4;
}

enum abstract Flags(Int) from Int to Int {
	var FONS_ZERO_TOPLEFT = 1;
	var FONS_ZERO_BOTTOMLEFT = 2;
}

enum abstract Align(Int) from Int to Int {
	// Horizontal align
	var FONS_ALIGN_LEFT = 1 << 0; // Default
	var FONS_ALIGN_CENTER = 1 << 1;
	var FONS_ALIGN_RIGHT = 1 << 2;
	// Vertical align
	var FONS_ALIGN_TOP = 1 << 3;
	var FONS_ALIGN_MIDDLE = 1 << 4;
	var FONS_ALIGN_BOTTOM = 1 << 5;
	var FONS_ALIGN_BASELINE = 1 << 6; // Default
}

enum abstract GlyphBitmap(Int) from Int to Int {
	var FONS_GLYPH_BITMAP_OPTIONAL = 1;
	var FONS_GLYPH_BITMAP_REQUIRED = 2;
}

enum abstract ErrorCode(Int) from Int to Int {
	// Font atlas is full.
	var FONS_ATLAS_FULL = 1;
	// Scratch memory used to render glyphs is full, requested size reported in 'val', you may need to bump up FONS_SCRATCH_BUF_SIZE.
	var FONS_SCRATCH_FULL = 2;
	// Calls to fonsPushState has created too large stack, if you need deep state stack bump up FONS_MAX_STATES.
	var FONS_STATES_OVERFLOW = 3;
	// Trying to pop too many states fonsPopState().
	var FONS_STATES_UNDERFLOW = 4;
}

class Renderer {
	public var width:Int;
	public var height:Int;
	public var flags:Flags;

	public function new(?width:Int, ?height:Int) {};

	public function resize(width:Int, height:Int) {}

	public function update(rect:Array<Int>, data:Bytes) {}

	public function draw(verts:Array<Float>, tcoords:Array<Float>, colors:Array<Int>, nverts:Int) {}

	public function delete() {}
}

typedef Quad = {
	?x0:Float,
	?y0:Float,
	?s0:Float,
	?t0:Float,
	?x1:Float,
	?y1:Float,
	?s1:Float,
	?t1:Float
}

typedef TTextIter = {
	?x:Float,
	?y:Float,
	?nextx:Float,
	?nexty:Float,
	?scale:Float,
	?spacing:Float,
	?codepoint:Int,
	?isize:Int,
	?iblur:Int,
	?font:Dynamic,
	?prevGlyphIndex:Int,
	?str:String,
	?next:String,
	?end:String,
	?utf8state:Int,
	?bitmapOption:Int
}

@:forward(x, y, nextx, nexty, scale, spacing, codepoint, isize, iblur, font, prevGlyphIndex, str, next, end, utf8state, bitmapOption)
abstract TextIter(TTextIter) from TTextIter to TTextIter {

    public inline function new(t:TTextIter){
        this = t;
    }
    public  function next(quad:Quad):Int {
		return 0;
	}

}

typedef Atlas = {
	?width:Int,
	?height:Int,
	?nodes:Array<AtlasNodes>,
	?nnodes:Int,
	?cnodes:Int
}

typedef AtlasNodes = {
	?x:Int,
	?y:Int,
	?width:Int
}

class Context {
	public var renderer:Renderer;
	var itw:Int;
	var ith:Int;
	var textureData:Bytes;
	var dirtyRect:Array<Int>;
	var fonts:Array<Font>;
	var atlas:Atlas;
	var verts:Array<Float>;
	var tcoords:Array<Float>;
	var scratch:Bytes;
	var nscratch:Int;
	var state:State;

	public function new(renderer:Renderer) {
        this.renderer = renderer;
        renderer.width = FONS.INIT_FONTIMAGE_SIZE; 
        renderer.height = FONS.INIT_FONTIMAGE_SIZE;
        renderer.flags = FONS_ZERO_TOPLEFT;

		atlas = {
			width: renderer.width,
			height: renderer.height,
			nnodes: FONS.INIT_ATLAS_NODES
		};

		fonts = [];
		itw = Std.int(1.0 / renderer.width);
        ith = Std.int(1.0 / renderer.height);
        textureData = Bytes.alloc(renderer.width*renderer.height);
        verts = [];
        tcoords = [];
        dirtyRect = [renderer.width, renderer.height, 0, 0];
        state = {
            size:    12.0,
			font:    0,
			blur:    0.0,
			spacing: 0.0,
			align:   FONS_ALIGN_LEFT | FONS_ALIGN_BASELINE
        };

	}

	public function setSize(size:Float):Void {}

	public function setSpacing(size:Float):Void {}

	public function setBlur(size:Float):Void {}

	public function setAlign(size:Float):Void {}

	public function setFont(font:Int) {}

	public function vertMetrics(ascender:Float, descender:Float, lineh:Float):Void {}

	public function lineBounds(a:Float, b:Float, c:Float):Void {}

	public function getFontByName(name:String):Int {
		return 0;
	}

	public function resetAtlas(w:Int, h:Int):Void {}

    public function addFont(name:String, path:String):Int {
        var fontFile = File.read(path);
        var data = fontFile.readAll();
        fontFile.close();

        return addFontMem(name, data, 1);
    }

    public function addFontMem(name:String, data:Bytes, freeData:Int):Int {
        return 0;
    }

	public function textBounds(x:Float, y:Float, string:String, end:String, bounds:Array<Float>):Float {
		return 0;
	}

	public function textIterInit(x:Float, y:Float, str:String, end:String, bitmapOption:Int):TextIter {
		return {};
	}

	
	public function validateTexture(dirty:Array<Int>):Int {
		return 0;
	}

	public function getTextureData(width:Int, height:Int):Array<Int> {
		return null;
	}
}

typedef State = {
	?font:Dynamic,
	?align:Align,
	?size:Float,
	?blur:Float,
	?spacing:Float
}

typedef GlyphKey = {
	?codePoint:Int,
	?size:Int,
	blur:Int
}

typedef Glyph = {
	?codepoint:Int,
	?index:Int,
	?size:Int,
	?blur:Int,
	?x0:Int,
	?y0:Int,
	?x1:Int,
	?y1:Int,
	?xAdv:Int,
	?xOff:Int,
	?yOff:Int
}

typedef Font = {
	?font:FontInfo,
	?name:String,
	?data:Bytes,
	?freeData:Int,
	?ascender:Int,
	?descender:Int,
	?lineh:Int,
	?glyphs:Map<GlyphKey, Glyph>,
	?lut:Array<Int>
}
