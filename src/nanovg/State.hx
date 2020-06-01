package nanovg;

import nanovg.LineCap;
import nanovg.Align;
import nanovg.Scissor;
import nanovg.Paint;
import nanovg.CompositeOperationState;

typedef State = {
    compositeOperation:Null<CompositeOperationState>,
    shapeAntiAlias:Null<Int>,
    fill:Null<Paint>,
    stroke:Null<Paint>,
    strokeWidth:Null<Float>,
	miterLimit:Null<Float>,
	lineJoin:Null<LineCap>,
	lineCap:Null<Int>,
	alpha:Null<Float>,
	xform:Array<Float>,
	scissor:Null<Scissor>,
	fontSize:Null<Float>,
	letterSpacing:Null<Float>,
	lineHeight:Null<Float>,
	fontBlur:Null<Float>,
	textAlign:Null<Align>,
	font:Null<Font>
}