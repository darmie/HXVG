package nanovg;


/**
 * Nanovg CompositeOperation
 */
enum abstract CompositeOperation(Int) from Int to Int {
    var SOURCE_OVER;
	var SOURCE_IN;
	var SOURCE_OUT;
	var ATOP;
	var DESTINATION_OVER;
	var DESTINATION_IN;
	var DESTINATION_OUT;
	var DESTINATION_ATOP;
	var LIGHTER;
	var COPY;
	var XOR;
}


/**
 * Nanovg CompositeOperationState
 */
typedef CompositeOperationState = {
        var ?srcRGB:Int;
        var ?dstRGB:Int;
        var ?srcAlpha:Int;
        var ?dstAlpha:Int;
}