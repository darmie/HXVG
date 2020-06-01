package nanovg;

enum abstract Solidity(Int) from Int to Int {
    inline function new(i:Int) {
        this = i;
    }

    /**
     * CCW
     */
    var SOLID = 1;

    /**
     * CW
     */
    var HOLE;
}