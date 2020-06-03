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

	public static final INIT_FONTIMAGE_SIZE = 512;
	public static final MAX_FONTIMAGE_SIZE = 2048;
    public static final MAX_FONTIMAGES = 4;
    
    public static function __mini(a:Int, b:Int) {
        if (a < b) {
            return a;
        }
        return b;
    }

    public static function __maxi(a:Int, b:Int) {
        if (a > b) {
            return a;
        }
        return b;
    }
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
	public inline function new(t:TTextIter) {
		this = t;
	}

	public function next(quad:Quad):Int {
		return 0;
	}
}

typedef TAtlas = {
	?width:Int,
	?height:Int,
	?nodes:Array<AtlasNodes>,
	?nnodes:Int,
	?cnodes:Int
}

abstract Atlas(TAtlas) from TAtlas to TAtlas {
	inline function new(atlas:TAtlas) {
		this = atlas;
	}

	public function addRect(w:Int, height:Int):{?bestX:Int, ?bestY:Int} {
		return {};
    }
    
    public function reset(w:Int, height:Int) {
        
    }
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
		textureData = Bytes.alloc(renderer.width * renderer.height);
		verts = [];
		tcoords = [];
		dirtyRect = [renderer.width, renderer.height, 0, 0];
		state = {
			size: 12.0,
			font: null,
			blur: 0.0,
			spacing: 0.0,
			align: FONS_ALIGN_LEFT | FONS_ALIGN_BASELINE
        };
        
        addWhiteRect(2, 2);
	}

	public function setSize(size:Float):Void
		state.size = size;

	public function setSpacing(spacing:Float):Void
		state.spacing = spacing;

	public function setBlur(blur:Float):Void
		state.blur = blur;

	public function setAlign(align:Align):Void
		state.align = align;

	public function setFont(font:Font)
		state.font = font;

	public function vertMetrics():{?ascender:Float, ?descender:Float, ?lineh:Float} {
		if (state.font == null && fonts.indexOf(state.font) == -1)
			return {ascender: -1, descender: -1, lineh: -1};
		var font = state.font;
		var iSize = state.size * 10.0;

		return {ascender: font.ascender * iSize / 10.0, descender: font.descender * iSize / 10.0, lineh: font.lineh * iSize / 10.0};
	}

	public function lineBounds(y:Float):{?minY:Float, ?maxY:Float} {
		if (state.font == null && fonts.indexOf(state.font) == -1)
			return {minY: -1, maxY: -1};
		var font = state.font;
		var iSize = state.size * 10.0;

		y += getVerticalAlign(font, state.align, iSize);

		// FontStash mini support only ZERO_TOPLEFT
		var miny = y - font.ascender * iSize / 10.0;
		return {
			minY: miny,
			maxY: miny + font.lineh * iSize / 10.0
		};
	}

	function getVerticalAlign(font:Font, align:Align, iSize:Float):Float {
		// FontStash mini support only ZERO_TOPLEFT
		if ((align & FONS_ALIGN_BASELINE) != 0) {
			return 0.0;
		} else if ((align & FONS_ALIGN_TOP) != 0) {
			return font.ascender * iSize / 10.0;
		} else if ((align & FONS_ALIGN_MIDDLE) != 0) {
			return (font.ascender + font.descender) / 2.0 * iSize / 10.0;
		} else if ((align & FONS_ALIGN_BOTTOM) != 0) {
			return font.descender * iSize / 10.0;
		}
		return 0.0;
	}

	function addWhiteRect(w:Int, h:Int) {
		var r = atlas.addRect(w, h);
		var gx = r.bestX;
		var gy = r.bestY;

		var gr = gx + w;
		var gb = gy + h;

		for (y in gy...gb) {
			for (x in gx...gr) {
				textureData.set(x + y * this.renderer.width, 0xff);
			}
		}

		dirtyRect[0] = FONS.__mini(dirtyRect[0], gx);
		dirtyRect[1] = FONS.__mini(dirtyRect[1], gy);
		dirtyRect[2] = FONS.__maxi(dirtyRect[2], gr);
		dirtyRect[3] = FONS.__maxi(dirtyRect[3], gb);
	}

	public function getFontByName(name:String):Dynamic {
		for (font in fonts) {
			if (font.name == name) {
				return font;
			}
		}
		return null;
    }
    
    public function getFontName():String {
        return state.font.name;
    }

	public function resetAtlas(w:Int, h:Int):Void {
        var stash = this;
        // Flush pending glyphs
        stash.flush();
        // Reset atlas
        stash.atlas.reset(w, h);

        // Clear texture data
        stash.textureData = Bytes.alloc(w*h);
        // Reset dirty rect
        stash.dirtyRect[0] = w;
        stash.dirtyRect[1] = h;
        stash.dirtyRect[2] = 0;
        stash.dirtyRect[3] = 0;

        // reset cached glyphs
        for(font in fonts){
            font.glyphs = new Map<GlyphKey, Glyph>();
        }

        stash.renderer.width = w;
        stash.renderer.height = h;
        stash.itw = Std.int(1.0 / w);
        stash.ith = Std.int(1.0 / h);
        // Add white rect at 0, 0 for debug drawing
        stash.addWhiteRect(2, 2);
    }

	public function addFont(name:String, path:String):Font {
		var fontFile = File.read(path);
		var data = fontFile.readAll();
		fontFile.close();

		return addFontMem(name, data, 1);
	}

	public function addFontMem(name:String, data:Bytes, freeData:Int):Font {
        var fontInstance = new FontInfo(data, 0);
        var metrics = fontInstance.getFontVMetrics();
        var fh:Float = cast(metrics.ascent - metrics.descent);
        var font:Font = {
            glyphs: new Map<GlyphKey, Glyph>(),
            name:      name,
            data:      data,
            freeData:  freeData,
            font:      fontInstance,
            ascender:  Std.int(metrics.ascent / fh),
            descender: Std.int(metrics.descent / fh),
            lineh:     Std.int((fh + metrics.lineGap) / fh)
        };

        fonts.push(font);
		return font;
	}

	public function textBounds(x:Float, y:Float, string:String, end:String, bounds:Array<Float>):Float {
        var prevGlyphIndex = -1;
        var size = Std.int(state.size * 10.0);
        var blur = Std.int(state.blur);
        if(state.font == null) return 0;
        var font:Font = state.font;

        var scale = font.getPixelHeightScale(state.size);
        y += getVerticalAlign(font, state.align, size);
        var minX = x;
        var maxX = x;
        var minY = y;
        var maxY = y;
        var startX = x;
        for(i in 0...string.length){
            var codePoint = string.charCodeAt(i);
            var glyph = getGlyph(font, codePoint, size, blur);
            if(glyph != null){
                var q = getQuad(font, prevGlyphIndex, glyph, scale, state.spacing, x, y);
                x = q.x;
                y = q.y;
                if (q.quad.x0 < minX) {
                    minX = q.quad.x0;
                }
                if (q.quad.x1 > maxX) {
                    maxX = q.quad.x1;
                }
                if (q.quad.y0 < minY) {
                    minY = q.quad.y0;
                }
                if (q.quad.y1 > maxY) {
                    maxY = q.quad.y1;
                }
                prevGlyphIndex = glyph.index;
            } else {
                prevGlyphIndex = -1;
            }
        }
        var advance = x - startX;
        if ((state.align & FONS_ALIGN_LEFT) != 0) {

            // do nothing
        } else if ((state.align & FONS_ALIGN_RIGHT) != 0) {
            minX -= advance;
            maxX -= advance;
        } else if ((state.align & FONS_ALIGN_CENTER) != 0) {
            minX -= advance * 0.5;
            maxX -= advance * 0.5;
        }
        bounds = [minX, minY, maxX, maxY];
		return advance;
    }
    
    function getGlyph(font:Font, codePoint:Int, size:Int, blur:Int):Glyph {
        return null;
    }

    function getQuad(font:Font, prevGlyphIndex:Int, glyph:Dynamic, scale:Float, spacing:Float, x:Float, y:Float):{quad:Quad, x:Float, y:Float} {
        return null;
    }

	public function textIterInit(x:Float, y:Float, str:String, ?end:String, ?bitmapOption:Int):TextIter {
		return {};
	}

	public function validateTexture(dirty:Array<Int>):Int {
		return 0;
	}

	public function getTextureData(width:Int, height:Int):Array<Int> {
		return null;
    }
    
    function flush() {
        
    }
}

typedef State = {
	?font:Font,
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

typedef TFont = {
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

@:forward(font, name, data, freeData, ascender, descender, lineh, glyphs, lut)
abstract Font(TFont) from TFont to TFont {
    inline function new(f:TFont) {
        this = f;
    }

    public function getPixelHeightScale(size:Float):Float{
        return 0;
    }
}