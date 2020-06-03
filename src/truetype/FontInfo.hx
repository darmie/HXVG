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
    
    public function new() {
        
    }
}
