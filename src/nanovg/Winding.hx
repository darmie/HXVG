package nanovg;


/**
 * Nanovg Winding
 */
enum abstract Winding(Int) from Int to Int {

    inline function new(i:Int) {
        this = i;
    }

    /**
     * Counter clockwise
     * 
     * Winding for solid shapes
     */
    var CCW:Winding = 1; 

    /**
     * Clockwise
     * 
     * Winding for holes
     */
    var CW:Winding;
}