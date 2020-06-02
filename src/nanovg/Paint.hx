package nanovg;

/**
 * Nanovg Paint
 */
typedef TPaint = {
    var ?xform:Matrix;
    var ?extent:Array<Float>;

    var ?radius:Float;
    var ?feather:Float;
    var ?innerColor:Color;
    var ?outerColor:Color;

    var ?image:Image;
}

@:forward(xform,extent, radius, feather, innerColor, outerColor, image)
abstract Paint(TPaint) from TPaint to TPaint {
    public inline function new(p:TPaint) {
        this = p;
    }
    public function setPaintColor(color:Color) {
		this.xform.transformIdentity();
        this.radius = 0.0;
        this.feather = 1.0;
        this.innerColor = color;
        this.outerColor = color;
	}
}