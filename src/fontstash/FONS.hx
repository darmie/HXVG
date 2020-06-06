package fontstash;

import sys.io.File;
import haxe.ds.IntMap;
import truetype.FontInfo;
import haxe.io.Bytes;
import polygonal.ds.ArrayList;

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

	public static final APREC = 16;
	public static final ZPREC = 7;

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
	?prevGlyph:Glyph,
	?str:String,
	?currentIndex:Int,
	?next:Int,
	?end:Int,
	?utf8state:Int,
	?bitmapOption:Int,
	?fontstash:Context
}

@:allow(Context)
@:forward(x, y, nextx, nexty, scale, spacing, codepoint, isize, iblur, font, prevGlyphIndex, str, next, end, utf8state, bitmapOption, currentIndex, prevGlyph)
abstract TextIter(TTextIter) from TTextIter to TTextIter {
	public inline function new(t:TTextIter) {
		this = t;
	}

	public function Next(quad:Quad):Bool {
		this.currentIndex = this.next;
		if (this.currentIndex == this.end) {
			quad = {};
			return false;
		}

		var current = this.next;
		var stash = this.fontstash;
		var font = this.font;

		this.codepoint = this.str.charCodeAt(current);
		current++;

		this.x = this.nextx;
		this.y = this.nexty;
		var glyph = stash.getGlyph(font, this.codepoint, this.isize, this.iblur);
		var prevGlyphIndex = -1;
		if(this.prevGlyph != null){
			prevGlyphIndex = this.prevGlyph.index;
		}
		if(glyph != null){
			var q = stash.getQuad(font, this.prevGlyphIndex, glyph, this.scale, this.spacing, this.nextx, this.nexty);
			quad = q.quad;
			this.nextx = q.x;
			this.nexty = q.y;
		} 
		this.prevGlyph = glyph;
		this.next = current;
		return true;
	}
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

	public function new(?width:Int, ?height:Int) {
		this.renderer = new Renderer();
		renderer.width = width == null ? FONS.INIT_FONTIMAGE_SIZE : width;
		renderer.height = height == null ? FONS.INIT_FONTIMAGE_SIZE : height;
		renderer.flags = FONS_ZERO_TOPLEFT;

		atlas = new Atlas(
			renderer.width,
			renderer.height,
			FONS.INIT_ATLAS_NODES
		);

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

	public function getFontByName(name:String):Font {
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
		stash.textureData = Bytes.alloc(w * h);
		// Reset dirty rect
		stash.dirtyRect[0] = w;
		stash.dirtyRect[1] = h;
		stash.dirtyRect[2] = 0;
		stash.dirtyRect[3] = 0;

		// reset cached glyphs
		for (font in fonts) {
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
			name: name,
			data: data,
			freeData: freeData,
			font: fontInstance,
			ascender: Std.int(metrics.ascent / fh),
			descender: Std.int(metrics.descent / fh),
			lineh: Std.int((fh + metrics.lineGap) / fh)
		};

		fonts.push(font);
		return font;
	}

	public function textBounds(x:Float, y:Float, string:String, end:String, bounds:Array<Float>):Float {
		var prevGlyphIndex = -1;
		var size = Std.int(state.size * 10.0);
		var blur = Std.int(state.blur);
		if (state.font == null)
			return 0;
		var font:Font = state.font;

		var scale = font.getPixelHeightScale(state.size);
		y += getVerticalAlign(font, state.align, size);
		var minX = x;
		var maxX = x;
		var minY = y;
		var maxY = y;
		var startX = x;
		for (i in 0...string.length) {
			var codePoint = string.charCodeAt(i);
			var glyph = getGlyph(font, codePoint, size, blur);
			if (glyph != null) {
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

	public function getGlyph(font:Font, codePoint:Int, size:Int, blur:Int):Glyph {
		if(size < 0) return null;
		if(blur > 20) blur = 20;

		var pad = blur +2;
		var glyphkey:GlyphKey = {
			codePoint: codePoint,
			size:      size,
			blur:      blur,
		};

		var hasGlyph = font.glyphs.exists(glyphkey);
		if(hasGlyph) return font.glyphs.get(glyphkey);

		var scale = font.getPixelHeightScale(size / 10.0);
		var index = font.getGlyphIndex(codePoint);
		var bitmap = font.buildGlyphBitmap(index, scale);
		
		var advance = bitmap.advance;
		var x0 = bitmap.x0;
		var y0 = bitmap.y0;
		var x1 = bitmap.x1;
		var y1 = bitmap.y1;

		var gw = x1 - x0 + pad*2;
		var gh = y1 - y0 + pad*2;

		var rect = atlas.addRect(gw, gh);
		var gx = rect.bestX;
		var gy = rect.bestY;

		var gr = gx + gw;
		var gb = gy + gh;

		var width = renderer.width;

		var glyph:Glyph = {
			codepoint: codePoint,
			index:     index,
			size:      size,
			blur:      blur,
			x0:        gx,
			y0:        gy,
			x1:        gr,
			y1:        gb,
			xAdv:      Std.int(scale * advance * 10.0),
			xOff:      x0 - pad,
			yOff:      y0 - pad,
		};

		font.glyphs.set(glyphkey, glyph);

		// Rasterize
		font.renderGlyphBitmap(textureData, gx+pad, gy+pad, x1-x0, y1-y0, width, scale, scale, index);

		// Make sure there is one pixel empty border
		var y = gy;
		while(y < gb){
			textureData.set(gx+y*width, 0);
			textureData.set(gr-1+y*width, 0);
			y++;
		}
		var x = gx;
		while(x < gr){
			textureData.set(x+gy*width, 0);
			textureData.set(x+(gb-1)*width, 0);
			x++;
		}

		if (blur > 0) {
			this.nscratch = 0;
			this.blur(gx, gy, gw, gh, blur);
		}

		dirtyRect[0] = FONS.__mini(dirtyRect[0], gx);
		dirtyRect[1] = FONS.__mini(dirtyRect[1], gy);
		dirtyRect[2] = FONS.__maxi(dirtyRect[2], gr);
		dirtyRect[3] = FONS.__maxi(dirtyRect[3], gb);


		return glyph;
	}

	function blur(x:Int, y:Int, width:Int, height:Int, blur:Int){
		var sigma = blur * 0.57735; // 1 / sqrt(3)
		var alpha = Std.int((1<<FONS.APREC) * (1.0 - Math.exp(-2.3/(sigma+1.0))));
		blurRows(x, y, width, height, alpha);
		blurCols(x, y, width, height, alpha);
		blurRows(x, y, width, height, alpha);
		blurCols(x, y, width, height, alpha);
	}

	function blurRows(x0:Int, y0:Int, w:Int, h:Int, alpha:Int) {
		var b = y0 +h;
		var r = x0 +w;

		var texture = textureData;
		var textureWidth = renderer.width;
		var x = x0;
		while(x < r){
			var z = 0; // force zero border
			var y = 1 + y0;
			while (y < b) {
				var offset = x + y*textureWidth;
				z += (alpha * ((Std.int(texture.get(offset)) << FONS.ZPREC) - z)) >> FONS.APREC;
				texture.set(offset,  z >> FONS.ZPREC);
				y++;
			}
			texture.set(x+(b-1)*textureWidth, 0); // force zero border
			z = 0;
			var _y = b - 2;
			while(_y >= y0) {
				var offset = x + _y*textureWidth;
				z += (alpha * ((Std.int(texture.get(offset)) << FONS.ZPREC) - z)) >> FONS.APREC;
				texture.set(offset, z >> FONS.ZPREC);
				_y--;
			}
			texture.set(x+y0*textureWidth, 0);
			x++;
		}
	}

	function blurCols(x0:Int, y0:Int, w:Int, h:Int, alpha:Int) {
		var b = y0 +h;
		var r = x0 +w;

		var texture = textureData;
		var textureWidth = renderer.width;
		var y = y0;
		while(y < b){
			var z = 0; // force zero border
			var yOffset = y * textureWidth;
			var x = 1 + x0;
			while(x < r){
				var offset = x + yOffset;
				z += (alpha * ((Std.int(texture.get(offset)) << FONS.ZPREC) - z)) >> FONS.APREC;
				texture.set(offset, z >> FONS.ZPREC);
				x++;
			}
			texture.set(r-1+yOffset, 0);
			z = 0;
			var x = r - 2;
			while(x >= x0){
				var offset = x + yOffset;
				z += (alpha * ((Std.int(texture.get(offset)) << FONS.ZPREC) - z)) >> FONS.APREC;
				texture.set(offset, z >> FONS.ZPREC);
				x--;
			}
			texture.set(x0+yOffset, 0);
			y++;
		}
	}

	public function getQuad(font:Font, prevGlyphIndex:Int, glyph:Glyph, scale:Float, spacing:Float, originalX:Float, originalY:Float):{quad:Quad, x:Float, y:Float} {
		var ret:{?quad:Quad, ?x:Float, ?y:Float} = {};
		ret.x = originalX;
		ret.y = originalY;

		if (prevGlyphIndex != -1) {
			var adv = (font.getGlyphKernAdvance(prevGlyphIndex, glyph.index)) * scale;
			ret.x += (Std.int(adv + spacing + 0.5));
		}
		var xOff = (Std.int(glyph.xOff + 1));
		var yOff = (Std.int(glyph.yOff + 1));
		var x0 = (Std.int(glyph.x0 + 1));
		var y0 = (Std.int(glyph.y0 + 1));
		var x1 = (Std.int(glyph.x1 - 1));
		var y1 = (Std.int(glyph.y1 - 1));
		// only support FONS_ZERO_TOPLEFT
		var rx = (Std.int(ret.x + xOff));
		var ry = (Std.int(ret.y + yOff));

		ret.quad = {
			x0: rx,
			y0: ry,
			x1: rx + x1 - x0,
			y1: ry + y1 - y0,
			s0: x0 * itw,
			t0: y0 * ith,
			s1: x1 * itw,
			t1: y1 * ith,
		};

		ret.x += Std.int(glyph.xAdv/10.0 + 0.5);
		return ret;
	}

	public function textIterInit(x:Float, y:Float, str:String, ?end:String, ?bitmapOption:Int):TextIter {
		if (state.font == null)
			return null;

		var font = state.font;

		if ((state.align & FONS_ALIGN_LEFT) != 0) {
			// do nothing
		} else if ((state.align & FONS_ALIGN_RIGHT) != 0) {
			x -= textBounds(x, y, str, "", []);
		} else if ((state.align & FONS_ALIGN_CENTER) != 0) {
			x -= textBounds(x, y, str, "", []) * 0.5;
		}
		y += getVerticalAlign(font, state.align, state.size * 10.0);

		

		var iter:TextIter = new TextIter({
			font: font,
			x: x,
			y: y,
			nextx: x,
			nexty: y,
			spacing: state.spacing,
			isize: Std.int(state.size * 10.0),
			iblur: Std.int(state.blur),
			scale: font.getPixelHeightScale(state.size),
			currentIndex: 0,
			next: 0,
			end: str.length,
			str: str,
			codepoint: 0,
			prevGlyphIndex: -1,
			bitmapOption: bitmapOption,
			fontstash: this
		});

		return iter;
	}

	public function validateTexture():Array<Int> {
		var stash = this;
		if (stash.dirtyRect[0] < stash.dirtyRect[2] && stash.dirtyRect[1] < stash.dirtyRect[3]) {
			var dirty = [];
			dirty = stash.dirtyRect.slice(0, 4);
			stash.dirtyRect[0] = stash.renderer.width;
			stash.dirtyRect[1] = stash.renderer.height;
			stash.dirtyRect[2] = 0;
			stash.dirtyRect[3] = 0;
			return dirty;
		}
		return null;
	}

	public function getTextureData():{?data:Bytes, ?width:Int, ?height:Int} {
		return {data: textureData, width: renderer.width, height: renderer.height};
	}

	function flush() {
		// Flush texture
		this.validateTexture();
		// Flush triangles
		if(this.verts.length > 0){
			this.verts = [];
		}
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

	public inline function getGlyphIndex(codePoint:Int):Int {
		return this.font.findGlyphIndex(codePoint);
	}

	public inline  function getPixelHeightScale(size:Float):Float {
		return this.font.scaleForPixelHeight(size);
	}

	public inline  function getGlyphKernAdvance(glyph1:Int, glyph2:Int):Float {
		return this.font.getGlyphKernAdvance(glyph1, glyph2);
	}

	public inline function buildGlyphBitmap(index:Int, scale:Float):{advance:Int, lsb:Int, x0:Int, y0:Int, x1:Int, y1:Int} {
		var m = this.font.getGlyphHMetrics(index);
		var box = this.font.getGlyphBitmapBoxSubpixel(index, scale, scale, 0, 0);

		return {advance: m.ascent, lsb:m.descent, x0:box.ix0, y0:box.iy0, x1:box.ix1, y1:box.iy1};
	}

	public inline  function renderGlyphBitmap(data:Bytes, offsetX:Int, offsetY:Int, outWidth:Int, outHeight:Int, outStride:Int, scaleX:Float, scaleY:Float, index:Int) {
		this.font.makeGlyphBitmapSubpixel(data.sub(offsetY*outStride+offsetX, data.length - (offsetY*outStride+offsetX)), outWidth, outHeight, outStride, scaleX, scaleY, 0, 0, index);
	}
}
