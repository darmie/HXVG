package nanovg;

enum abstract BlendFactor(Int) from Int to Int {
    inline function new(i:Int) {
        this = i;
    }

    var ZERO = 1<<0;
	var ONE = 1<<1;
	var SRC_COLOR = 1<<2;
	var ONE_MINUS_SRC_COLOR = 1<<3;
	var DST_COLOR = 1<<4;
	var ONE_MINUS_DST_COLOR = 1<<5;
	var SRC_ALPHA = 1<<6;
	var ONE_MINUS_SRC_ALPHA = 1<<7;
	var DST_ALPHA = 1<<8;
	var ONE_MINUS_DST_ALPHA = 1<<9;
	var SRC_ALPHA_SATURATE = 1<<10;
}