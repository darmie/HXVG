package nanovg;


/**
 * Nanovg CompositeOperation
 */
enum CompositeOperation {
    SOURCE_OVER;
	SOURCE_IN;
	SOURCE_OUT;
	ATOP;
	DESTINATION_OVER;
	DESTINATION_IN;
	DESTINATION_OUT;
	DESTINATION_ATOP;
	LIGHTER;
	COPY;
	XOR;
}


/**
 * Nanovg CompositeOperationState
 */
typedef CompositeOperationState = {
        var srcRGB:Int;
        var dstRGB:Int;
        var srcAlpha:Int;
        var dstAlpha:Int;
}