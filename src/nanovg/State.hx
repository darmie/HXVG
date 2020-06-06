package nanovg;

import nanovg.LineCap;
import nanovg.Align;
import nanovg.Scissor;
import nanovg.Paint;
import nanovg.CompositeOperationState;
import fontstash.FONS.Font;

typedef State = {
    ?compositeOperation:CompositeOperationState,
    ?shapeAntiAlias:Int,
    ?fill:Paint,
    ?stroke:Paint,
    ?strokeWidth:Float,
	?miterLimit:Float,
	?lineJoin:LineCap,
	?lineCap:LineCap,
	?alpha:Float,
	?xform:Matrix,
	?scissor:Scissor,
	?fontSize:Float,
	?letterSpacing:Float,
	?lineHeight:Float,
	?fontBlur:Float,
	?textAlign:Align,
	?font:Font
}