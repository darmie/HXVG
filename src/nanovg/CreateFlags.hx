package nanovg;

/**
 * Nanovg create flags
 */
enum abstract CreateFlags(Int) from Int to Int {
	inline function new(i:Int) {
		this = i;
	}

	/**
	 * Flag indicating if geometry based anti-aliasing is used (may not be needed when using MSAA).
	 */
	var ANTIALIAS = 1 << 0;

	/**
	 * Flag indicating if strokes should be drawn using stencil buffer. The rendering will be a little
	 * slower, but path overlaps (i.e. self-intersecting or sharp turns) will be drawn just once.
	 */
	var STENCIL_STROKES = 1 << 1;

	/**
	 * Flag indicating that additional debug checks are done.
	 */
	var DEBUG = 1 << 2;
}
