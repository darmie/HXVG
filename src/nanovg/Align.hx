package nanovg;

/**
 * Nanovg Align
 */
enum abstract Align(Int) from Int to Int {
    inline function new(i:Int) {
        this = i;
    }
    
	// Horizontal align

	/**
	 * Default, align text horizontally to left.
	 */
	var LEFT = 1 << 0;

	/**
	 * Align text horizontally to center.
	 */
	var CENTER = 1 << 1;

	/**
	 * Align text horizontally to right.
	 */
	var RIGHT = 1 << 2;

	// Vertical align

	/**
	 * Align text vertically to top.
	 */
	var TOP = 1 << 3;

	/**
	 * Align text vertically to middle.
	 */
	var MIDDLE = 1 << 4;

	/**
	 * Align text vertically to bottom.
	 */
	var BOTTOM = 1 << 5;

	/**
	 * Default, align text vertically to baseline.
	 */
	var BASELINE = 1 << 6;
}
