package truetype;

import haxe.io.Bytes;

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
        
    }

    public function getFontVMetrics():{ascent:Int, descent:Int, lineGap:Int} {
        return {ascent:-1, descent:-1, lineGap:-1};
	}


	function findTable(data:Bytes, offset:Int, tag:String):Int{
		var numTables:Int = u16(data, offset+4);
		var tableDir = offset + 12;
		for(i in 0...numTables){
			var loc = tableDir + 16*i;
			if(data.getString(loc, loc+4) == tag){
				return u32(data, loc+8);
			}
		}

		return 0;
	}
	

	function u32(b:Bytes, i:Int):U32{
		return b.get(i) << 24 | b.get(i+1) << 16 | b.get(i+2) << 8 | b.get(i+3);
	}

	function u16(b:Bytes, i:Int):U16 {
		return b.get(i) << 8 | b.get(i+1);
	}

	function isFont(data:Bytes):Bool{
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

	function tag4(data:Bytes, c0:I8, c1:I8, c2:I8, c3:I8){
		return data.get(0) == c0 && data.get(1) == c1 && data.get(2) == c2 && data.get(3) == c3;
	}
}
