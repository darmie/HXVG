package truetype;

import polygonal.ds.ArrayList;
import haxe.io.Bytes;
import truetype.TrueType;

class FontInfo {
	var data:Bytes; // contains the .ttf file
	var fontStart:Int; // offset of start of font
	var loca:Int; // table location as offset from start of .ttf
	var head:Int;
	var glyf:Int;
	var hhea:Int;
	var hmtx:Int;
	var kern:Int;
	var numGlyphs:Int; // number of glyphs, needed for range checking
	var indexMap:Int; // a cmap mapping for our chosen character encoding
	var indexToLocFormat:Int; // format needed to map from glyph index to glyph

	/**
	 * Given an offset into the file that defines a font, this function builds the
	 * necessary cached info for the rest of the system.
	 * @param data
	 * @param offset
	 */
	public function new(data:Bytes, offset:Int) {
		if ((data.length - offset) < 12) {
			throw "TTF data is too short";
		}

		this.data = data;
		this.fontStart = offset;

		var cmap = findTable(data, offset, "cmap");
		loca = findTable(data, offset, "loca");
		head = findTable(data, offset, "head");
		glyf = findTable(data, offset, "glyf");
		hhea = findTable(data, offset, "hhea");
		hmtx = findTable(data, offset, "hmtx");
		kern = findTable(data, offset, "kern");

		if (cmap == 0 || loca == 0 || head == 0 || glyf == 0 || hhea == 0 || hmtx == 0) {
			throw "Required table not found";
		}

		var t = findTable(data, offset, "maxp");
		if (t != 0) {
			numGlyphs = u16(data, t + 4);
		} else {
			numGlyphs = 0xfff;
		}

		var numTables = u16(data, cmap + 2);
		for (i in 0...numTables) {
			var encodingRecord = cmap + 4 + 8 * i;
			switch Std.int(u16(data, encodingRecord)) {
				case PLATFORM_ID_MICROSOFT:
					{
						switch (u16(data, encodingRecord + 2)) {
							case MS_EID_UNICODE_FULL | MS_EID_UNICODE_BMP: {
									indexMap = cmap + (u32(data, encodingRecord + 4));
								}
						}
					}
				case _:
			}
		}

		if (indexMap == 0) {
			throw "Unknown cmap encoding table";
		}

		indexToLocFormat = Std.int(u16(data, head + 50));
	}

	/**
	 * Each .ttf/.ttc file may have more than one font. Each font has a sequential
	 * index number starting from 0. Call this function to get the font offset for
	 * a given index; it returns -1 if the index is out of range. A regular .ttf
	 * file will only define one font and it always be at offset 0, so it will return
	 * '0' for index 0, and -1 for all other indices. You can just skip this step
	 * if you know it's that kind of font.
	 *
	 * @param data
	 * @param index
	 */
	public static function getFontOffsetForIndex(data:Bytes, index:Int) {
		if (isFont(data)) {
			if (index == 0) {
				return 0;
			} else {
				return -1;
			}
		}

		// Check if it's a TTC
		if (data.getString(0, 4) == "ttcf") {
			if (u32(data, 4) == 0x00010000 || u32(data, 4) == 0x00020000) {
				var n:Int = u32(data, 8);
				if (index >= n) {
					return -1;
				}
				return Std.int(u32(data, 12 + index * 14));
			}
		}
		return -1;
	}

	public function getFontVMetrics():{ascent:Int, descent:Int, lineGap:Int} {
		var font = this;
		var a:I16 = u16(font.data, font.hhea + 4);
		var d:I16 = u16(font.data, font.hhea + 6);
		var l:I16 = u16(font.data, font.hhea + 8);
		return {ascent: a, descent: d, lineGap: l};
	}

	public function findGlyphIndex(unicodeCodepoint:Int):Int {
		var format = Std.int(u16(data, indexMap));
		if (format == 0) { // apple byte encoding
			var numBytes = Std.int(u16(data, indexMap + 2));
			if (unicodeCodepoint < numBytes - 6) {
				return Std.int(data.get(indexMap + 6 + unicodeCodepoint));
			}
			return 0;
		} else if (format == 6) {
			var first = Std.int(u16(data, indexMap + 6));
			var count = Std.int(u16(data, indexMap + 8));
			if (unicodeCodepoint >= first && unicodeCodepoint < first + count) {
				return Std.int(u16(data, indexMap + 10 + (unicodeCodepoint - first) * 2));
			}
			return 0;
		} else if (format == 2) {
			throw "TODO: high-byte mapping for japanese/chinese/korean";
		} else if (format == 4) {
			var segcount = Std.int(u16(data, indexMap + 6) >> 1);
			var searchRange = Std.int(u16(data, indexMap + 8) >> 1);
			var entrySelector = Std.int(u16(data, indexMap + 10));
			var rangeShift = Std.int(u16(data, indexMap + 12) >> 1);

			var endCount = indexMap + 14;
			var search = endCount;

			if (unicodeCodepoint > 0xffff) {
				return 0;
			}

			if (unicodeCodepoint >= Std.int(u16(data, search + rangeShift * 2))) {
				search += rangeShift * 2;
			}

			search -= 2;
			while (entrySelector > 0) {
				searchRange >>= 1;
				// start := int(u16(data, search+2+segcount*2+2))
				// end := int(u16(data, search+2))
				// start := int(u16(data, search+searchRange*2+segcount*2+2))
				var end = Std.int(u16(data, search + searchRange * 2));
				if (unicodeCodepoint > end) {
					search += searchRange * 2;
				}
				entrySelector--;
			}

			search += 2;

			var item = ((search - endCount) >> 1);

			if (!(unicodeCodepoint <= Std.int(u16(data, endCount + 2 * item)))) {
				throw "unicode codepoint doesn't match";
			}

			var start = Std.int(u16(data, indexMap + 14 + segcount * 2 + 2 + 2 * item));
			// end := int(u16(data, indexMap+14+2+2*item))
			if (unicodeCodepoint < start) {
				return 0;
			}

			var offset = Std.int(u16(data, indexMap + 14 + segcount * 6 + 2 + 2 * item));
			if (offset == 0) {
				return unicodeCodepoint + Std.int(u16(data, indexMap + 14 + segcount * 4 + 2 + 2 * item));
			}
			return Std.int(u16(data, offset + (unicodeCodepoint - start) * 2 + indexMap + 14 + segcount * 6 + 2 + 2 * item));
		} else if (format == 12 || format == 13) {
			var ngroups = Std.int(u32(data, indexMap + 12));
			var low = 0;
			var high = ngroups;
			while (low < high) {
				var mid = low + ((high - low) >> 1);
				var startChar = Std.int(u32(data, indexMap + 16 + mid * 12));
				var endChar = Std.int(u32(data, indexMap + 16 + mid * 12 + 4));
				if (unicodeCodepoint < startChar) {
					high = mid;
				} else if (unicodeCodepoint > endChar) {
					low = mid + 1;
				} else {
					var startGlyph = Std.int(u32(data, indexMap + 16 + mid * 12 + 8));
					if (format == 12) {
						return startGlyph + unicodeCodepoint - startChar;
					} else { // format == 13
						return startGlyph;
					}
				}
			}
			return 0; // not found
		}

		return 0; // "Glyph not found!";
	}

	public function getGlyphKernAdvance(glyph1:Int, glyph2:Int):Int {
		var data = kern;

		// we only look at the first table. it must be 'horizontal' and format 0.
		if (kern == 0) {
			return 0;
		}

		if (u16(this.data, data + 2) < 1) { // number of tables, need at least 1
			return 0;
		}
		if (u16(this.data, data + 8) != 1) { // horizontal flag must be set in format
			return 0;
		}

		var l = 0;
		var r = Std.int(u16(this.data, data + 10)) - 1;

		var g1:U32 = cast glyph1;
		var g2:U32 = cast glyph2;
		var needle = g1 << 16 | g2;

		while (l <= r) {
			var m = (l + r) >> 1;
			var straw:U32 = u32(this.data, data + 18 + (m * 6)); // note: unaligned read
			if (needle < straw) {
				r = m - 1;
			} else if (needle > straw) {
				l = m + 1;
			} else {
				var v:I16 = cast u16(this.data, data + 22 + (m * 6));
				return Std.int(v);
			}
		}
		return 0;
	}

	public function getCodepointBitmapBox(codepoint:Int, scaleX:Float, scaleY:Float) {
		return getCodepointBitmapBoxSubpixel(codepoint, scaleX, scaleY, 0, 0);
	}

	public function getCodepointBitmapBoxSubpixel(codepoint:Int, scaleX:Float, scaleY:Float, shiftX:Float, shiftY:Float) {
		return getGlyphBitmapBoxSubpixel(findGlyphIndex(codepoint), scaleX, scaleY, shiftX, shiftY);
	}

	public function getCodepointBitmap(scaleX:Float, scaleY:Float, codePoint:Int, xoff:Int, yoff:Int) {
		return getCodepointBitmapSubpixel(scaleX, scaleY, 0., 0., codePoint, xoff, yoff);
	}

	public function getCodepointBitmapSubpixel(scaleX:Float, scaleY:Float, shiftX:Float, shiftY:Float, codePoint:Int, xoff:Int, yoff:Int) {
		return getGlyphBitmapSubpixel(scaleX, scaleY, shiftX, shiftY, findGlyphIndex(codePoint), xoff, yoff);
	}

	public function getGlyphBitmapSubpixel(scaleX:Float, scaleY:Float, shiftX:Float, shiftY:Float, glyph:Int, xoff:Int,
			yoff:Int):{?pixels:Bytes, ?width:Int, ?height:Int} {
		var gbm:Bitmap = {};
		var width:Int, height:Int;
		var vertices = getGlyphShape(glyph);
		if (scaleX == 0) {
			scaleX = scaleY;
		}
		if (scaleY == 0) {
			if (scaleX == 0) {
				return {pixels: null, width: 0, height: 0};
			}
			scaleY = scaleX;
		}

		var box = getGlyphBitmapBoxSubpixel(glyph, scaleX, scaleY, shiftX, shiftY);
		// now we get the size
		gbm.w = box.ix1 - box.ix0;
		gbm.h = box.iy1 - box.iy0;
		gbm.pixels = null;

		var width = gbm.w;
		var height = gbm.h;
		xoff = box.ix0;
		yoff = box.iy0;

		if (gbm.w != 0 && gbm.h != 0) {
			gbm.pixels = Bytes.alloc(gbm.w * gbm.h);
			gbm.stride = gbm.w;

			TrueType.rasterize(gbm, 0.35, vertices, scaleX, scaleY, shiftX, shiftY, box.ix0, box.iy0, true);
		}

		return {pixels: gbm.pixels, width: width, height: height};
	}

	public function getCodepointHMetrics(codepoint:Int) {
		return getGlyphHMetrics(findGlyphIndex(codepoint));
	}

	public function getCodepointKernAdvance(ch1:Int, ch2:Int) {
		if (kern == 0) {
			return 0;
		}
		return getGlyphKernAdvance(findGlyphIndex(ch1), findGlyphIndex(ch2));
	}

	public function makeGlyphBitmapSubpixel(output:Bytes, outW:Int, outH:Int, outStride:Int, scaleX:Float, scaleY:Float, shiftX:Float, shiftY:Float,
			glyph:Int):Bytes {
		var gbm:Bitmap = {};
		var vertices = getGlyphShape(glyph);
		var box = getGlyphBitmapBoxSubpixel(glyph, scaleX, scaleY, shiftX, shiftY);
		gbm.w = outW;
		gbm.h = outH;
		gbm.stride = outStride;

		if (gbm.w > 0 && gbm.h > 0) {
			gbm.pixels = output;
			TrueType.rasterize(gbm, 0.35, vertices, scaleX, scaleY, shiftX, shiftY, box.ix0, box.iy0, true);
		}
		return gbm.pixels;
	}

	public function getGlyphBitmapBoxSubpixel(glyph:Int, scaleX:Float, scaleY:Float, shiftX:Float, shiftY:Float):{
		?ix0:Int,
		?iy0:Int,
		?ix1:Int,
		?iy1:Int
	} {
		var ret:{
			?ix0:Int,
			?iy0:Int,
			?ix1:Int,
			?iy1:Int
		} = {};
		var box = getGlyphBox(glyph);
		if (!box.result) {
			box.x0 = 0;
			box.y0 = 0;
			box.x1 = 0;
			box.y1 = 0;
		}

		ret.ix0 = Std.int(Math.floor((box.x0) * scaleX + shiftX));
		ret.iy0 = -Std.int(Math.ceil((box.y1) * scaleY + shiftY));
		ret.ix1 = Std.int(Math.ceil((box.x1) * scaleX + shiftX));
		ret.iy1 = -Std.int(Math.floor((box.y0) * scaleY + shiftY));

		return ret;
	}

	public function getGlyphShape(glyphIndex:Int):ArrayList<Vertex> {
		var g = getGlyphOffset(glyphIndex);
		if (g < 0) {
			return null;
		}

		var vertices:ArrayList<Vertex>;
		var n:I16 = u16(data, g);
		var numberOfContours:Int = n;
		var numVertices = 0;

		if (numberOfContours > 0) {
			var flags:U8;
			var endPtsOfContours = g + 10;
			var ins:Int = u16(data, g + 10 + numberOfContours * 2);
			var points = g + 10 + numberOfContours * 2 + 2 + ins;

			var l = u16(data.sub(endPtsOfContours, data.length - endPtsOfContours), numberOfContours * 2 - 2);
			var n:Int = 1 + l;
			var m = n + 2 * numberOfContours;
			vertices = new ArrayList<Vertex>(m);

			var nextMove = 0;
			var flagcount = 0;

			// in first pass, we load uninterpreted data into the allocated array
			// above, shifted to the end of the array so we won't overwrite it when
			// we create our final data starting from the front
			var off = m - n; // starting offset for uninterpreted data, regardless of how m ends up being calculated
			// first load flags
			for (i in 0...n) {
				if (flagcount == 0) {
					flags = data.get(points);
					points++;
					if (flags & 8 != 0) {
						flagcount = data.get(points);
						points++;
					}
				} else {
					flagcount--;
				}
				vertices.get(off + i).type = flags;
			}
			// now load x coordinates
			var x = 0;
			for (i in 0...n) {
				flags = vertices.get(off + i).type;
				if (flags & 2 != 0) {
					var dx = data.get(points);
					points++;
					// ???
					if (flags & 16 != 0) {
						x += dx;
					} else {
						x -= dx;
					}
				} else {
					if (flags & 16 == 0) {
						var k:I16 = data.get(points) * 256 + data.get(points + 1);
						x = x + k;
						points += 2;
					}
				}
				vertices.get(off + i).x = x;
			}
			// now load y coordinates
			var y = 0;
			for (i in 0...n) {
				flags = vertices.get(off + i).type;
				if (flags & 4 != 0) {
					var dy = data.get(points);
					points++;
					// ???
					if (flags & 32 != 0) {
						y += dy;
					} else {
						y -= dy;
					}
				} else {
					if (flags & 32 == 0) {
						var k1:I16 = data.get(points);
						var k2:I16 = data.get(points + 1);
						var k:Int = k1 * 256 + k2;
						y = y + k;
						points += 2;
					}
				}
				vertices.get(off + i).y = y;
			}
			// now convert them to our format
			numVertices = 0;
			var sx:Int, sy:Int, cx:Int, cy:Int, scx:Int, scy:Int;
			var wasOff:Bool, startOff:Bool;
			var j:Int;
			var i = 0;
			while (i < n) {
				flags = vertices.get(off + i).type;
				x = vertices.get(off + i).x;
				y = vertices.get(off + i).y;
				if (nextMove == i) {
					if (i != 0) {
						numVertices = TrueType.closeShape(vertices, numVertices, wasOff, startOff, sx, sy, scx, scy, cx, cy);
					}

					// now start the new one
					startOff = flags & 1 == 0;
					if (startOff) {
						// if we start off with an off-curve point, then when we need to find a point on the curve
						// where we can start, and we need to save some state for when we wrap around.
						scx = x;
						scy = y;
						if (vertices.get(off + i + 1).type & 1 == 0) {
							// next point is also a curve point, so interpolate an on-point curve
							sx = (x + vertices.get(off + i + 1).x) >> 1;
							sy = (y + vertices.get(off + i + 1).y) >> 1;
						} else {
							// otherwise just use the next point as our start point
							sx = vertices.get(off + i + 1).y;
							sy = vertices.get(off + i + 1).y;
							i++;
						}
					} else {
						sx = x;
						sy = y;
					}
					vertices.set(numVertices, {
						type: vmove,
						x: sx,
						y: sy,
						cx: 0,
						cy: 0
					});
					numVertices++;
					wasOff = false;
					var k:Int = u16(data.sub(endPtsOfContours, data.length - endPtsOfContours), j * 2);
					nextMove = 1 + k;
					j++;
				} else {
					if (flags & 1 == 0) { // if it's a curve
						if (wasOff) { // two off-curve control points in a row means interpolate an on-curve midpoint
							vertices.set(numVertices, {
								type: vcurve,
								x: (cx + x) >> 1,
								y: (cy + y) >> 1,
								cx: cx,
								cy: cy
							});
							numVertices++;
						}
						cx = x; 
						cy = y;
						wasOff = true;
					} else {
						if (wasOff) {
							vertices.set(numVertices, {
								type: vcurve,
								x: x,
								y: y,
								cx: cx,
								cy: cy
							});
							numVertices++;
						} else {
							vertices.set(numVertices, {
								type: vline,
								x: x,
								y: y,
								cx: 0,
								cy: 0
							});
							numVertices++;
						}
						wasOff = false;
					}
				}
				i++;
			}
			numVertices = TrueType.closeShape(vertices, numVertices, wasOff, startOff, sx, sy, scx, scy, cx, cy);
		} else if (numberOfContours == -1) {
			// Compound shapes.
			var more = true;
			var comp = g + 10;
			var numVertices = 0;
			vertices = null;

			while(more){
				var mtx:ArrayList<Float> = new ArrayList<Float>(6, [1, 0, 0, 1, 0, 0]);
				var flags:Int = u16(data, comp);
				comp += 2;
				var gidx:Int = u16(data, comp);
				comp += 2;

				if (flags&2 != 0) { // XY values
					if (flags&1 != 0) { // shorts
						mtx.set(4 , u16(data, comp));
						comp += 2;
						mtx.set(5, u16(data, comp));
						comp += 2;
					} else {
						mtx.set(4, data.get(comp));
						comp++;
						mtx.set(5, data.get(comp));
						comp++;
					}
				} else {
					// @TODO handle matching point
					throw "Handle matching point";
				}
				if ((flags&(1<<3)) != 0) { // WE_HAVE_A_SCALE
					mtx.set(3,  (u16(data, comp)) / 16384);
					comp += 2;
					mtx.set(0, mtx.get(3));
					mtx.set(1, 0);
					mtx.set(2, 0);
				} else if (flags&(1<<6) != 0) { // WE_HAVE_AN_X_AND_YSCALE
					mtx.set(0, (u16(data, comp))/ 16384);
					comp += 2;
					mtx.set(1, 0);
					mtx.set(2, 0);
					mtx.set(3, (u16(data, comp))/ 16384);
					comp += 2;
				} else if (flags&(1<<7) != 0) { // WE_HAVE_A_TWO_BY_TWO
					mtx.set(0, (u16(data, comp))/ 16384);
					comp += 2;
					mtx.set(1, (u16(data, comp))/ 16384);
					comp += 2;
					mtx.set(2, (u16(data, comp))/ 16384);
					comp += 2;
					mtx.set(3, (u16(data, comp))/ 16384);
					comp += 2;
				}
				// Find transformation scales.
				var m = Math.sqrt(mtx.get(0)*mtx.get(0) + mtx.get(1)*mtx.get(1));
				var n = Math.sqrt(mtx.get(2)*mtx.get(2) + mtx.get(3)*mtx.get(3));

				// Get indexed glyph.
				var compVerts = getGlyphShape(gidx);
				var compNumVerts = compVerts.size;
				if ((compNumVerts) > 0) {
					// Transform vertices.
					for(i in 0...compNumVerts){
						var v = i;
						var x = compVerts.get(v).x;
						var y = compVerts.get(v).y;
						compVerts.get(v).x = Std.int(m * (mtx.get(0)*(x) + mtx.get(2)*(y) + mtx.get(4)));
						compVerts.get(v).y = Std.int(n * (mtx.get(1)*(x) + mtx.get(3)*(y) + mtx.get(5)));
						x = compVerts.get(v).cx;
						y = compVerts.get(v).cy;
						compVerts.get(v).cx = Std.int(m * (mtx.get(0)*(x) + mtx.get(2)*(y) + mtx.get(4)));
						compVerts.get(v).cy = Std.int(n * (mtx.get(1)*(x) + mtx.get(3)*(y) + mtx.get(5)));
					}
					vertices = compVerts;
					numVertices += compNumVerts;
				}
				// More components?
				more = flags&(1<<5) != 0;
			}
		} else if (numberOfContours < 0) {
			// @TODO other compound variations?
			throw "Possibly other compound variations";
		} // numberOfContours == 0, do nothing
		return vertices;
	}

	public function getGlyphHMetrics(glyphIndex:Int):{ascent:Int, descent:Int} {
		var font = this;
		var numOfLongHorMetrics = Std.int(u16(data, hhea + 34));
		if (glyphIndex < numOfLongHorMetrics) {
			var a:I16 = u16(font.data, font.hmtx + 4 * glyphIndex);
			var d:I16 = u16(font.data, font.hmtx + 4 * glyphIndex + 2);
			return {ascent: a, descent: d};
		}
		var a:I16 = u16(font.data, font.hmtx + 4 * (numOfLongHorMetrics - 1));
		var d:I16 = u16(font.data, font.hmtx + 4 * numOfLongHorMetrics + 2 * (glyphIndex - numOfLongHorMetrics));
		return {ascent: a, descent: d};
	}

	public function scaleForPixelHeight(height:Float):Float {
		var fheight:Float = u16(data, hhea + 4) - u16(data, hhea + 6);
		return height / fheight;
	}

	public function getGlyphBitmapBox(glyph:Int, scaleX:Float, scaleY:Float):Dynamic {
		return getGlyphBitmapBoxSubpixel(glyph, scaleX, scaleY, 0, 0);
	}

	public function getGlyphBox(glyph:Int):{
		?result:Bool,
		?x0:Int,
		?y0:Int,
		?x1:Int,
		?y1:Int
	} {
		var ret:{
			?result:Bool,
			?x0:Int,
			?y0:Int,
			?x1:Int,
			?y1:Int
		} = {};
		var font = this;
		var g = font.getGlyphOffset(glyph);
		if (g < 0) {
			ret.result = false;
			return ret;
		}

		ret.x0 = Std.int(u16(font.data, g + 2));
		ret.y0 = Std.int((u16(font.data, g + 4)));
		ret.x1 = Std.int((u16(font.data, g + 6)));
		ret.y1 = Std.int((u16(font.data, g + 8)));

		ret.result = true;

		return ret;
	}

	public function getGlyphOffset(glyphIndex:Int):Int {
		var font = this;
		if (glyphIndex >= font.numGlyphs) {
			// Glyph index out of range
			return -1;
		}
		if (font.indexToLocFormat >= 2) {
			// Unknown index-glyph map format
			return -1;
		}

		var g1:Int, g2:Int;

		if (font.indexToLocFormat == 0) {
			g1 = font.glyf + Std.int(u16(font.data, font.loca + glyphIndex * 2)) * 2;
			g2 = font.glyf + Std.int(u16(font.data, font.loca + glyphIndex * 2 + 2)) * 2;
		} else {
			g1 = font.glyf + Std.int(u32(font.data, font.loca + glyphIndex * 4));
			g2 = font.glyf + Std.int(u32(font.data, font.loca + glyphIndex * 4 + 4));
		}

		if (g1 == g2) {
			// length is 0
			return -1;
		}
		return g1;
	}

	public function makeCodepointBitmap(output:Bytes, outW:Int, outH:Int, outStride:Int, scaleX:Float, scaleY:Float, codepoint:Int):Bytes {
		return makeCodepointBitmapSubpixel(output, outW, outH, outStride, scaleX, scaleY, 0, 0, codepoint);
	}

	public function makeCodepointBitmapSubpixel(output:Bytes, outW:Int, outH:Int, outStride:Int, scaleX:Float, scaleY:Float, shiftX:Float, shiftY:Float,
			codepoint:Int):Bytes {
		return makeGlyphBitmapSubpixel(output, outW, outH, outStride, scaleX, scaleY, shiftX, shiftY, findGlyphIndex(codepoint));
	}

	public function makeGlyphBitmap(output:Bytes, outW:Int, outH:Int, outStride:Int, scaleX:Float, scaleY:Float, glyph:Int):Bytes {
		return makeGlyphBitmapSubpixel(output, outW, outH, outStride, scaleX, scaleY, 0, 0, glyph);
	}

	function findTable(data:Bytes, offset:Int, tag:String):Int {
		var numTables:Int = u16(data, offset + 4);
		var tableDir = offset + 12;
		for (i in 0...numTables) {
			var loc = tableDir + 16 * i;
			if (data.getString(loc, loc + 4) == tag) {
				return u32(data, loc + 8);
			}
		}

		return 0;
	}

	static function u32(b:Bytes, i:Int):U32 {
		return b.get(i) << 24 | b.get(i + 1) << 16 | b.get(i + 2) << 8 | b.get(i + 3);
	}

	static function u16(b:Bytes, i:Int):U16 {
		return b.get(i) << 8 | b.get(i + 1);
	}

	static function isFont(data:Bytes):Bool {
		if (tag4(data, '1'.charCodeAt(0), 0, 0, 0)) {
			return true;
		}
		if (data.getString(0, 4) == "typ1") {
			return true;
		}
		if (data.getString(0, 4) == "OTTO") {
			return true;
		}
		if (tag4(data, 0, 1, 0, 0)) {
			return true;
		}
		return false;
	}

	static function tag4(data:Bytes, c0:I8, c1:I8, c2:I8, c3:I8) {
		return data.get(0) == c0 && data.get(1) == c1 && data.get(2) == c2 && data.get(3) == c3;
	}
}
