package nanovg;

/**
 * Nanovg Paint
 */
typedef Paint = {
    var xform:Array<Float>;
    var extent:Array<Float>;

    var radius:Float;
    var feather:Float;
    var innerColor:Color;
    var outerColor:Color;

    var image:Int;
}