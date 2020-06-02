package nanovg;

import haxe.ds.Vector;
import nanovg.Renderer.IRenderer;
import nanovg.Font.FontFace;
import nanovg.CompositeOperationState.CompositeOperation;
import nanovg.Align;
import nanovg.DrawCommands;
import nanovg.PointFlags;

/**
 * Nanovg Context
 */
class Context {
	static final NVG_INIT_FONTIMAGE_SIZE = 512;
	static final NVG_MAX_FONTIMAGE_SIZE = 2048;
	static final NVG_MAX_FONTIMAGES = 4;

	static final NVG_PI = Math.PI;

	static final NVG_INIT_COMMANDS_SIZE = 256;
	static final NVG_INIT_POINTS_SIZE = 128;
	static final NVG_INIT_PATHS_SIZE = 16;
	static final NVG_INIT_VERTS_SIZE = 256;
	static final NVG_MAX_STATES = 32;

	static final NVG_KAPPA90 = 0.5522847493;

	var renderer:IRenderer;
	var commands:Array<Float>;
	var ncommands:Int;
	var ccommands:Int;
	var commandx:Float;
	var commandy:Float;
	var states:Array<State>;
	var nstates:Int;
	var cache:PathCache;
	var tessTol:Float;
	var distTol:Float;
	var fringeWidth:Float;
	var devicePxRatio:Float;
	var fontImages:Array<Image>;
	var fontImageIdx:Int;
	var drawCallCount:Int;
	var fillTriCount:Int;
	var strokeTriCount:Int;
	var textTriCount:Int;

	public function new(renderer:IRenderer) {
		this.renderer = renderer;
		for (i in 0...NVG_MAX_FONTIMAGES) {
			this.fontImages[i] = null;
		}

		commands = new Array<Float>();
		ncommands = 0;
		ccommands = NVG_INIT_COMMANDS_SIZE;

		cache = allocPathCache();

		save();
		reset();

		setDevicePixelRatio(1.0);

		// Todo: fonts render setup
	}

	public function internalRenderer():IRenderer {
		return renderer;
	}

	/**
	 * Begin drawing a new frame
	 *
	 * Calls to nanovg drawing API should be wrapped in beginFrame() & endFrame()
	 * beginFrame() defines the size of the window to render to in relation currently
	 * set viewport (i.e. glViewport on GL backends). Device pixel ration allows to
	 * control the rendering on Hi-DPI devices.
	 *
	 * For example, GLFW returns two dimension for an opened window: window size and
	 * frame buffer size. In that case you would set windowWidth/Height to the window size
	 * devicePixelRatio to: frameBufferWidth / windowWidth.
	 */
	public function beginFrame(windowWidth:Float, windowHeight:Float, devicePixelRatio:Float) {
		nstates = 0;
		save();
		reset();
		setDevicePixelRatio(devicePixelRatio);
		this.renderer.viewport(windowWidth, windowHeight, devicePixelRatio);

		this.drawCallCount = 0;
		this.fillTriCount = 0;
		this.strokeTriCount = 0;
		this.textTriCount = 0;
	}

	/**
	 * Cancels drawing the current frame.
	 */
	public function cancelFrame() {
		this.renderer.cancel();
	}

	/**
	 * Ends drawing flushing remaining render state.
	 */
	public function endFrame() {
		renderer.flush();
		if (fontImageIdx == 0) {
			var fontImage = fontImages[0];
			var i:Int, j:Int, iw:Int, ih:Int;
			// delete images that smaller than current one
			if (fontImage == null) {
				return;
			}

			var size = fontImage.size();
			iw = size.w;
			ih = size.h;

			i = j = 0;
			while (i < fontImageIdx) {
				if (fontImages[i] != null) {
					var nw:Int, nh:Int;
					nw = fontImages[i].size().w;
					nh = fontImages[i].size().h;

					if (nw < iw || nh < ih)
						fontImages[i].delete();
					else
						fontImages[j++] = fontImages[i];
				}

				i++;
			}
			// make current font image to first
			this.fontImages[j++] = this.fontImages[0];
			this.fontImages[0] = fontImage;
			this.fontImageIdx = 0;

			// clear all images after j
			i = j;
			while (i < NVG_MAX_FONTIMAGES) {
				fontImages[i] = null;

				i++;
			}
		}
	}

	//
	// Composite operation
	//
	// The composite operations in NanoVG are modeled after HTML Canvas API, and
	// the blend func is based on OpenGL (see corresponding manuals for more info).
	// The colors in the blending state have premultiplied alpha.

	/**
	 * Sets the composite operation. The op parameter should be one of CompositeOperation enum.
	 * @param op
	 */
	public function globalCompositeOperation(op:CompositeOperation) {
		var state = getState();
		state.compositeOperation = compositeOperationState(op);
	}

	/**
	 * Sets the composite operation with custom pixel arithmetic. The parameters should be one of BlendFactor.
	 * @param sfactor
	 * @param dfactor
	 */
	public function globalCompositeBlendFunc(sfactor:BlendFactor, dfactor:BlendFactor) {
		globalCompositeBlendFuncSeparate(sfactor, dfactor, sfactor, dfactor);
	}

	/**
	 * Sets the composite operation with custom pixel arithmetic for RGB and alpha components separately. The parameters should be one of NVGblendFactor.
	 * @param srcRGB
	 * @param dstRGB
	 * @param srcAlpha
	 * @param dstAlpha
	 */
	public function globalCompositeBlendFuncSeparate(srcRGB:BlendFactor, dstRGB:BlendFactor, srcAlpha:BlendFactor, dstAlpha:BlendFactor) {
		var op:CompositeOperationState = {};
		op.srcRGB = srcRGB;
		op.dstRGB = dstRGB;
		op.srcAlpha = srcAlpha;
		op.dstAlpha = dstAlpha;

		var state = getState();
		state.compositeOperation = op;
	}

	//
	// State Handling
	//
	// NanoVG contains state which represents how paths will be rendered.
	// The state contains transform, fill and stroke styles, text and font styles,
	// and scissor clipping.

	/**
	 * Pushes and saves the current render state into a state stack.
	 * A matching restore() must be used to restore the state.
	 */
	public function save() {
		if (nstates >= NVG_MAX_STATES)
			return;

		if (nstates > 0)
			states[nstates] = states[nstates - 1];

		nstates++;
	}

	/**
	 * Pops and restores current render state.
	 */
	public function restore() {
		if (nstates <= 1)
			return;
		nstates--;
	}

	/**
	 * Resets current render state to default values. Does not affect the render state stack.
	 */
	public function reset() {
		var state = getState();
		state.fill.setPaintColor(Color.RGBA(255, 255, 255, 255));
		state.stroke.setPaintColor(Color.RGBA(0, 0, 0, 255));

		state.compositeOperation = compositeOperationState(SOURCE_OVER);
		state.shapeAntiAlias = 1;
		state.strokeWidth = 1.0;
		state.miterLimit = 10.0;
		state.lineCap = BUTT;
		state.lineJoin = MITER;
		state.alpha = 1.0;

		state.xform.transformIdentity();

		state.scissor.extent[0] = -1.0;
		state.scissor.extent[1] = -1.0;

		state.fontSize = 16.0;
		state.letterSpacing = 0.0;
		state.lineHeight = 1.0;
		state.fontBlur = 0.0;
		state.textAlign = LEFT | BASELINE;
		state.font = null;
	}

	//
	// Render styles
	//
	// Fill and stroke render style can be either a solid color or a paint which is a gradient or a pattern.
	// Solid color is simply defined as a color value, different kinds of paints can be created
	// using linearGradient(), boxGradient(), radialGradient() and imagePattern().
	//
	// Current render style can be saved and restored using save() and restore().

	/**
	 * Sets whether to draw antialias for stroke() and fill(). It's enabled by default.
	 */
	public function shapeAntialias(enabled:Int) {
		var state = getState();
		state.shapeAntiAlias = enabled;
	}

	/**
	 * Sets current stroke style to a solid color.
	 * @param color
	 */
	public function strokeColor(color:Color) {
		var state = getState();
		state.stroke.setPaintColor(color);
	}

	/**
	 * Sets current stroke style to a paint, which can be a one of the gradients or a pattern.
	 * @param paint
	 */
	public function strokePaint(paint:Paint) {
		var state = getState();
		state.stroke = paint;
		state.stroke.xform.transformMultiply(state.xform);
	}

	/**
	 * Sets current fill style to a solid color.
	 * @param color
	 */
	public function fillColor(color:Color) {
		var state = getState();
		state.fill.setPaintColor(color);
	}

	/**
	 * Sets current fill style to a paint, which can be a one of the gradients or a pattern.
	 * @param paint
	 */
	public function fillPaint(paint:Paint) {
		var state = getState();
		state.fill = paint;
		state.fill.xform.transformMultiply(state.xform);
	}

	/**
	 * Sets the miter limit of the stroke style.
	 * Miter limit controls when a sharp corner is beveled.
	 * @param limit
	 */
	public function miterLimit(limit:Float) {
		var state = getState();
		state.miterLimit = limit;
	}

	/**
	 * Sets the stroke width of the stroke style.
	 * @param size
	 */
	public function strokeWidth(size:Float) {
		var state = getState();
		state.strokeWidth = size;
	}

	/**
	 * Sets how the end of the line (cap) is drawn,
	 * Can be one of: BUTT (default), ROUND, SQUARE.
	 * @param linecap
	 */
	public function lineCap(cap:LineCap = BUTT) {
		var state = getState();
		state.lineCap = cap;
	}

	/**
	 * Sets how sharp path corners are drawn.
	 * Can be one of MITER (default), ROUND, BEVEL.
	 * @param join
	 */
	public function lineJoin(join:LineCap = MITER) {
		var state = getState();
		state.lineJoin = join;
	}

	/**
	 * Sets the transparency applied to all rendered shapes.
	 * Already transparent paths will get proportionally more transparent as well.
	 * @param alpha
	 */
	public function globalAlpha(alpha:Float) {
		var state = getState();
		state.alpha = alpha;
	}

	//
	// Transforms
	//
	// The paths, gradients, patterns and scissor region are transformed by an transformation
	// matrix at the time when they are passed to the API.
	// The current transformation matrix is a affine matrix:
	//   [sx kx tx]
	//   [ky sy ty]
	//   [ 0  0  1]
	// Where: sx,sy define scaling, kx,ky skewing, and tx,ty translation.
	// The last row is assumed to be 0,0,1 and is not stored.
	//
	// Apart from resetTransform(), each transformation function first creates
	// specific transformation matrix and pre-multiplies the current transformation by it.
	//
	// Current coordinate system (transformation) can be saved and restored using save() and restore().

	/**
	 * Resets current transform to a identity matrix.
	 */
	public function resetTransform() {
		var state = getState();
		state.xform.transformIdentity();
	}

	/**
	 * Premultiplies current coordinate system by specified matrix.
	 * The parameters are interpreted as matrix as follows:
	 * ```
	 * [a c e]
	 * [b d f]
	 * [0 0 1]
	 * ```
	 * @param a
	 * @param b
	 * @param c
	 * @param d
	 * @param e
	 * @param f
	 */
	public function transform(a:Float, b:Float, c:Float, d:Float, e:Float, f:Float) {
		var state = getState();
		var t = new Matrix([a, b, c, d, e, f]);
		state.xform.transformPremultiply(t);
	}

	/**
	 * Transform a point by given transform.
	 * @param dstx
	 * @param dsty
	 * @param xform
	 * @param srcx
	 * @param srcy
	 */
	public function transformPoint(dstx:Float, dsty:Float, xform:Matrix, sx:Float, sy:Float) {
		dstx = sx * xform[0] + sy * xform[2] + xform[4];
		dsty = sx * xform[1] + sy * xform[3] + xform[5];
	}

	/**
	 * Translates current coordinate system.
	 * @param x
	 * @param y
	 */
	public function translate(x:Float, y:Float) {
		var state = getState();
		var t = new Matrix([]);
		t.transformTranslate(x, y);
		state.xform.transformPremultiply(t);
	}

	/**
	 * Rotates current coordinate system. Angle is specified in radians.
	 */
	public function rotate(angle:Float) {
		var state = getState();
		var t = new Matrix([]);
		t.transformRotate(angle);
		state.xform.transformPremultiply(t);
	}

	/**
	 * Skews the current coordinate system along X axis. Angle is specified in radians.
	 * @param angle
	 */
	public function skewX(angle:Float) {
		var state = getState();
		var t = new Matrix([]);
		t.transformSkewX(angle);
		state.xform.transformPremultiply(t);
	}

	/**
	 * Skews the current coordinate system along Y axis. Angle is specified in radians.
	 * @param angle
	 */
	public function skewY(angle:Float) {
		var state = getState();
		var t = new Matrix([]);
		t.transformSkewY(angle);
		state.xform.transformPremultiply(t);
	}

	/**
	 * Scales the current coordinate system.
	 * @param x
	 * @param y
	 */
	public function scale(x:Float, y:Float) {
		var state = getState();
		var t = new Matrix([]);
		t.transformScale(x, y);
		state.xform.transformPremultiply(t);
	}

	/**
	 * Stores the top part (a-f) of the current transformation matrix in to the specified buffer.
	 * ```
	 * [a c e]
	 * [b d f]
	 * [0 0 1]
	 * ```
	 * There should be space for 6 floats in the return buffer for the values a-f.
	 * @param xform
	 */
	public function currentTransform(xform:Matrix) {
		var state = getState();
		if (xform == null)
			return;

		xform = state.xform.copy();
	}

	//
	// Paints
	//
	// NanoVG supports four types of paints: linear gradient, box gradient, radial gradient and image pattern.
	// These can be used as paints for strokes and fills.

	/**
	 * Creates and returns a linear gradient. Parameters (sx,sy)-(ex,ey) specify the start and end coordinates
	 * of the linear gradient, icol specifies the start color and ocol the end color.
	 *
	 * The gradient is transformed by the current transform when it is passed to `fillPaint()` or `strokePaint()`.
	 * @param sx
	 * @param sy
	 * @param ex
	 * @param ey
	 * @param icol
	 * @param ocol
	 */
	public function linearGradient(sx:Float, sy:Float, ex:Float, ey:Float, icol:Color, ocol:Color):Paint {
		var p = new Paint({});
		var dx:Float, dy:Float, d:Float;
		final large = 1e5;

		// Calculate transform aligned to the line
		dx = ex - sx;
		dy = ey - sy;
		d = Math.sqrt(dx * dx + dy * dy);
		if (d > 0.0001) {
			dx /= d;
			dy /= d;
		} else {
			dx = 0;
			dy = 1;
		}

		p.xform[0] = dy;
		p.xform[1] = -dx;
		p.xform[2] = dx;
		p.xform[3] = dy;
		p.xform[4] = sx - dx * large;
		p.xform[5] = sy - dy * large;

		p.extent[0] = large;
		p.extent[1] = large + d * 0.5;

		p.radius = 0.0;

		p.feather = Math.max(1.0, d);

		p.innerColor = icol;
		p.outerColor = ocol;
		return p;
	}

	/**
	 * Creates and returns a box gradient. Box gradient is a feathered rounded rectangle, it is useful for rendering
	 * drop shadows or highlights for boxes. Parameters (x,y) define the top-left corner of the rectangle,
	 * (w,h) define the size of the rectangle, r defines the corner radius, and f feather. Feather defines how blurry
	 * the border of the rectangle is. Parameter icol specifies the inner color and ocol the outer color of the gradient.
	 *
	 * The gradient is transformed by the current transform when it is passed to `fillPaint()` or `strokePaint()`.
	 * @param x
	 * @param y
	 * @param w
	 * @param h
	 * @param r
	 * @param f
	 * @param icol
	 * @param ocol
	 * @return Paint
	 */
	public function boxGradient(x:Float, y:Float, w:Float, h:Float, r:Float, f:Float, icol:Color, ocol:Color):Paint {
		var p = new Paint({});
		p.xform.transformIdentity();
		p.xform[4] = x + w * 0.5;
		p.xform[5] = y + h * 0.5;

		p.extent[0] = w * 0.5;
		p.extent[1] = h * 0.5;

		p.radius = r;

		p.feather = Math.max(1.0, f);

		p.innerColor = icol;
		p.outerColor = ocol;

		return p;
	}

	/**
	 * Creates and returns a radial gradient. Parameters (cx,cy) specify the center, inr and outr specify
	 * the inner and outer radius of the gradient, icol specifies the start color and ocol the end color.
	 *
	 * The gradient is transformed by the current transform when it is passed to `fillPaint()` or `strokePaint()`.
	 * @param cx
	 * @param cy
	 * @param inr
	 * @param outr
	 * @param icol
	 * @param ocol
	 * @return Paint
	 */
	public function radialGradient(cx:Float, cy:Float, inr:Float, outr:Float, icol:Color, ocol:Color):Paint {
		var p = new Paint({});
		var r = (inr + outr) * 0.5;
		var f = (outr - inr);

		p.xform.transformIdentity();

		p.xform[4] = cx;
		p.xform[5] = cy;

		p.extent[0] = r;
		p.extent[1] = r;

		p.radius = r;

		p.feather = Math.max(1.0, f);

		p.innerColor = icol;
		p.outerColor = ocol;

		return p;
		return null;
	}

	/**
	 * Creates and returns an image pattern. Parameters (ox,oy) specify the left-top location of the image pattern,
	 * (ex,ey) the size of one image, angle rotation around the top-left corner, image is handle to the image to render.
	 *
	 * The gradient is transformed by the current transform when it is passed to `fillPaint()` or `strokePaint()`.
	 * @param ox
	 * @param oy
	 * @param ex
	 * @param ey
	 * @param angle
	 * @param image
	 * @param alpha
	 * @return Paint
	 */
	public function imagePattern(cx:Float, cy:Float, w:Float, h:Float, angle:Float, image:Image, alpha:Float):Paint {
		var p = new Paint({});
		p.xform.transformRotate(angle);
		p.xform[4] = cx;
		p.xform[5] = cy;

		p.extent[0] = w;
		p.extent[1] = h;

		p.image = image;

		p.innerColor = p.outerColor = Color.RGBAf(1, 1, 1, alpha);

		return p;
	}

	//
	// Scissoring
	//
	// Scissoring allows you to clip the rendering into a rectangle. This is useful for various
	// user interface cases like rendering a text edit or a timeline.

	/**
	 * Sets the current scissor rectangle.
	 * The scissor rectangle is transformed by the current transform.
	 * @param x
	 * @param y
	 * @param w
	 * @param h
	 */
	public function scissor(x:Float, y:Float, w:Float, h:Float) {
		var state = getState();
		w = Math.max(0.0, w);
		h = Math.max(0.0, h);

		state.scissor.xform.transformIdentity();
		state.scissor.xform[4] = x + w * 0.5;
		state.scissor.xform[5] = y + h * 0.5;
		state.scissor.xform.transformMultiply(state.xform);

		state.scissor.extent[0] = w * 0.5;
		state.scissor.extent[1] = h * 0.5;
	}

	/**
	 * Intersects current scissor rectangle with the specified rectangle.
	 * The scissor rectangle is transformed by the current transform.
	 * Note: in case the rotation of previous scissor rect differs from
	 * the current one, the intersection will be done between the specified
	 * rectangle and the previous scissor rectangle transformed in the current
	 * transform space. The resulting shape is always rectangle.
	 * @param x
	 * @param y
	 * @param w
	 * @param h
	 */
	public function intersectScissor(x:Float, y:Float, w:Float, h:Float) {
		var state = getState();
		var pxForm:Matrix = new Matrix([]);
		var invxForm:Matrix = new Matrix([]);
		var rect:Array<Float> = [];
		var ex:Float, ey:Float, tex:Float, tey:Float;

		// If no previous scissor has been set, set the scissor as current scissor.
		if (state.scissor.extent[0] < 0) {
			scissor(x, y, w, h);
			return;
		}

		// Transform the current scissor rect into current transform space.
		// If there is difference in rotation, this will be approximation.
		pxForm = state.scissor.xform.copy();

		ex = state.scissor.extent[0];
		ey = state.scissor.extent[1];

		invxForm.transformInverse(state.xform);
		pxForm.transformMultiply(invxForm);
		tex = ex * Math.abs(pxForm[0]) + ey * Math.abs(pxForm[2]);
		tey = ex * Math.abs(pxForm[1]) + ey * Math.abs(pxForm[3]);

		// Intersect rects.
		isectRects(rect, pxForm[4] - tex, pxForm[5] - tey, tex * 2, tey * 2, x, y, w, h);

		scissor(rect[0], rect[1], rect[2], rect[3]);
	}

	static inline function isectRects(dst:Array<Float>, ax:Float, ay:Float, aw:Float, ah:Float, bx:Float, by:Float, bw:Float, bh:Float) {
		var minx = Math.max(ax, bx);
		var miny = Math.max(ay, by);
		var maxx = Math.min(ax + aw, bx + bw);
		var maxy = Math.min(ay + ah, by + bh);
		dst[0] = minx;
		dst[1] = miny;
		dst[2] = Math.max(0.0, maxx - minx);
		dst[3] = Math.max(0.0, maxy - miny);
	}

	/**
	 * Reset and disables scissoring.
	 */
	public function resetScissor() {
		var state = getState();
		state.scissor.xform = [];

		state.scissor.extent[0] = -1.0;
		state.scissor.extent[1] = -1.0;
	}

	//
	// Paths
	//
	// Drawing a new shape starts with beginPath(), it clears all the currently defined paths.
	// Then you define one or more paths and sub-paths which describe the shape. The are functions
	// to draw common shapes like rectangles and circles, and lower level step-by-step functions,
	// which allow to define a path curve by curve.
	//
	// NanoVG uses even-odd fill rule to draw the shapes. Solid shapes should have counter clockwise
	// winding and holes should have counter clockwise order. To specify winding of a path you can
	// call pathWinding(). This is useful especially for the common shapes, which are drawn CCW.
	//
	// Finally you can fill the path using current fill style by calling fill(), and stroke it
	// with current stroke style by calling stroke().
	//
	// The curve segments and sub-paths are transformed by the current transform.

	/**
	 * Clears the current path and sub-paths.
	 */
	public function beginPath() {
		ncommands = 0;
		clearPathCache();
	}

	/**
	 * Starts new sub-path with specified point as first point.
	 * @param x
	 * @param y
	 */
	public function moveTo(x:Float, y:Float) {
		var vals = new Array<Float>();
		vals[0] = MOVETO;
		vals[1] = x;
		vals[2] = y;
		appendCommands(vals, vals.length);
	}

	/**
	 * Adds line segment from the last point in the path to the specified point.
	 * @param x
	 * @param y
	 */
	public function lineTo(x:Float, y:Float) {
		var vals = new Array<Float>();
		vals[0] = LINETO;
		vals[1] = x;
		vals[2] = y;
		appendCommands(vals, vals.length);
	}

	/**
	 * Adds cubic bezier segment from last point in the path via two control points to the specified point.
	 * @param c1x
	 * @param c1y
	 * @param c2x
	 * @param c2y
	 * @param x
	 * @param y
	 */
	public function bezierTo(c1x:Float, c1y:Float, c2x:Float, c2y:Float, x:Float, y:Float) {
		var vals = new Array<Float>();
		vals[0] = BEZIERTO;
		vals[1] = c1x;
		vals[2] = c1y;
		vals[3] = c2x;
		vals[4] = c2y;
		vals[5] = x;
		vals[6] = y;
		appendCommands(vals, vals.length);
	}

	/**
	 * Adds quadratic bezier segment from last point in the path via a control point to the specified point.
	 * @param cx
	 * @param cy
	 * @param x
	 * @param y
	 */
	public function quadTo(cx:Float, cy:Float, x:Float, y:Float) {
		var x0:Float = commandx;
		var y0:Float = commandy;
		var vals = new Array<Float>();
		vals[0] = BEZIERTO;
		vals[1] = x0 + 2.0 / 3.0 * (cx - x0);
		vals[2] = y0 + 2.0 / 3.0 * (cy - y0);
		vals[3] = x + 2.0 / 3.0 * (cx - x);
		vals[4] = y + 2.0 / 3.0 * (cy - y);
		vals[5] = x;
		vals[6] = y;
		appendCommands(vals, vals.length);
	}

	/**
	 * Adds an arc segment at the corner defined by the last path point, and two specified points.
	 * @param x1
	 * @param y1
	 * @param x2
	 * @param y2
	 * @param radius
	 */
	public function arcTo(x1:Float, y1:Float, x2:Float, y2:Float, radius:Float) {}

	/**
	 * Closes current sub-path with a line segment.
	 */
	public function closePath() {
		var vals = new Array<Float>();
		vals[0] = CLOSE;
		appendCommands(vals, vals.length);		
	}

	/**
	 *  Sets the current sub-path winding, see Winding and Solidity.
	 * @param dir
	 */
	public function pathWinding(dir:Winding) {
		var vals = new Array<Float>();
		vals[0] = WINDING; vals[1] = dir;
		appendCommands(vals, vals.length);
	}

	/**
	 * Creates new circle arc shaped sub-path. The arc center is at cx,cy, the arc radius is r,
	 * and the arc is drawn from angle a0 to a1, and swept in direction dir (CCW, or CW)
	 *
	 * Angles are specified in radians.
	 * @param cx
	 * @param cy
	 * @param r
	 * @param a0
	 * @param a1
	 * @param dir
	 */
	public function arc(cx:Float, cy:Float, r:Float, a0:Float, a1:Float, dir:Winding) {

	}

	/**
	 * Creates new rectangle shaped sub-path.
	 * @param x
	 * @param y
	 * @param w
	 * @param h
	 */
	public function rect(x:Float, y:Float, w:Float, h:Float) {
		var vals = new Array<Float>();
		vals[0] = MOVETO; vals[1] = x; vals[2] = y;
		vals[3] = LINETO; vals[4] = x; vals[5] = y+h;
		vals[6] = LINETO; vals[7] = x+w; vals[8] = y+h;
		vals[9] = LINETO; vals[10] = x+w; vals[11] = y;
		vals[12] = CLOSE;
		appendCommands(vals, vals.length);
	}

	/**
	 * Creates new rounded rectangle shaped sub-path.
	 * @param x
	 * @param y
	 * @param w
	 * @param h
	 * @param r
	 */
	public function roundedRect(x:Float, y:Float, w:Float, h:Float, r:Float) {
		roundedRectVarying(x, y, w, h, r, r, r, r);
	}

	/**
	 * Creates new rounded rectangle shaped sub-path with varying radii for each corner.
	 * @param x
	 * @param y
	 * @param w
	 * @param h
	 * @param radTopLeft
	 * @param radTopRight
	 * @param radBottomRight
	 * @param radBottomLeft
	 */
	public function roundedRectVarying(x:Float, y:Float, w:Float, h:Float, radTopLeft:Float, radTopRight:Float, radBottomRight:Float, radBottomLeft:Float) {
		if(radTopLeft < 0.1 && radTopRight < 0.1 && radBottomRight < 0.1 && radBottomLeft < 0.1) {
			rect(x, y, w, h);
			return;
		} else {
			var halfw: Float = Math.abs(w)*0.5;
			var halfh: Float = Math.abs(h)*0.5;
			var rxBL: Float = Math.min(radBottomLeft, halfw) * MathExt.sign(w), ryBL = Math.min(radBottomLeft, halfh) * MathExt.sign(h);
			var rxBR: Float = Math.min(radBottomRight, halfw) * MathExt.sign(w), ryBR = Math.min(radBottomRight, halfh) * MathExt.sign(h);
			var rxTR: Float = Math.min(radTopRight, halfw) * MathExt.sign(w), ryTR = Math.min(radTopRight, halfh) * MathExt.sign(h);
			var rxTL: Float = Math.min(radTopLeft, halfw) * MathExt.sign(w), ryTL = Math.min(radTopLeft, halfh) * MathExt.sign(h);
			var vals = new Array<Float>();
			vals[0] = MOVETO; vals[1] = x; vals[2] = y + ryTL;
			vals[3] = LINETO; vals[4] = x; vals[5] = y + h - ryBL;
			vals[6] = BEZIERTO; vals[7] = x; vals[8] = y + h - ryBL*(1 - NVG_KAPPA90); vals[9] = x + rxBL*(1 - NVG_KAPPA90); vals[10] = y + h; vals[11] = x + rxBL; vals[12] = y + h;
			vals[13] = LINETO; vals[14] = x + w - rxBR; vals[15] = y + h;
			vals[16] = BEZIERTO; vals[17] = x + w - rxBR*(1 - NVG_KAPPA90); vals[18] = y + h; vals[19] = x + w; vals[20] = y + h - ryBR*(1 - NVG_KAPPA90); vals[21] = x + w; vals[22] = y + h - ryBR;
			vals[23] = LINETO; vals[24] = x + w;vals[25] = y + ryTR;
			vals[26] = BEZIERTO; vals[27] = x + w; vals[28] = y + ryTR*(1 - NVG_KAPPA90); vals[29] = x + w - rxTR*(1 - NVG_KAPPA90); vals[30] = y; vals[31] = x + w - rxTR; vals[32] = y;
			vals[33] = LINETO; vals[34] = x + rxTL; vals[35] = y;
			vals[36] = BEZIERTO; vals[37] = x + rxTL*(1 - NVG_KAPPA90); vals[38] = y; vals[39] = x; vals[40] = y + ryTL*(1 - NVG_KAPPA90); vals[41] = x; vals[42] = y + ryTL;
			vals[43] = CLOSE;
			appendCommands(vals, vals.length);
		}
	}

	/**
	 * Creates new ellipse shaped sub-path.
	 * @param cx
	 * @param cy
	 * @param rx
	 * @param ry
	 */
	public function ellipse(cx:Float, cy:Float, rx:Float, ry:Float) {
		var vals = new Array<Float>();
		vals[0] = MOVETO; vals[1] = cx-rx; vals[2] = cy;
		vals[3] = BEZIERTO; vals[4] = cx-rx; vals[5] = cy+ry*NVG_KAPPA90; vals[6] = cx-rx*NVG_KAPPA90; vals[7] = cy+ry; vals[8] = cx; vals[9] = cy+ry;
		vals[10] = BEZIERTO; vals[11] = cx+rx*NVG_KAPPA90; vals[12] = cy+ry; vals[13] = cx+rx; vals[14] = cy+ry*NVG_KAPPA90; vals[15] = cx+rx; vals[16] = cy;
		vals[17] = BEZIERTO; vals[18] = cx+rx; vals[19] = cy-ry*NVG_KAPPA90; vals[20] = cx+rx*NVG_KAPPA90; vals[21] = cy-ry; vals[22] = cx; vals[23] = cy-ry;
		vals[24] = BEZIERTO; vals[25] = cx-rx*NVG_KAPPA90; vals[26] = cy-ry; vals[27] = cx-rx; vals[28] = cy-ry*NVG_KAPPA90; vals[29] = cx-rx; vals[30] = cy;
		vals[31] = CLOSE;
		appendCommands(vals, vals.length);
	}

	/**
	 * Creates new circle shaped sub-path.
	 * @param cx
	 * @param cy
	 * @param rx
	 * @param ry
	 */
	public function circle(cx:Float, cy:Float, r:Float) {
		ellipse(cx,cy, r,r);
	}

	/**
	 * Fills the current path with current fill style.
	 */
	public function fill() {
		var state: State = getState();
		var path: Path;
		var fillPaint: Paint = state.fill;
		// int i;
	
		flattenPaths();
		if (cast(this.renderer, Renderer).edgeAntiAlias != 0 && state.shapeAntiAlias != 0)
			expandFill( this.fringeWidth, MITER, 2.4);
		else
			expandFill( 0.0, MITER, 2.4);
	
		// Apply global alpha
		fillPaint.innerColor.a *= state.alpha;
		fillPaint.outerColor.a *= state.alpha;
	
		this.renderer.fill(fillPaint, state.compositeOperation, state.scissor, this.fringeWidth,
							   this.cache.bounds, this.cache.paths);
	
		// Count triangles
		for (i in 0...this.cache.npaths) {
			path = this.cache.paths[i];
			this.fillTriCount += path.nfill-2;
			this.fillTriCount += path.nstroke-2;
			this.drawCallCount += 2;
		}		
	}

	/**
	 * Fills the current path with current stroke style.
	 */
	public function stroke() {}

	/**
	 * Sets the font size of current text style.
	 * @param size
	 */
	public function fontSize(size:Float) {
		var state = getState();
		state.fontSize = size;
	}

	/**
	 * Sets the blur of current text style.
	 * @param blur
	 */
	public function fontBlur(blur:Float) {
		var state = getState();
		state.fontBlur = blur;
	}

	/**
	 * Sets the letter spacing of current text style.
	 * @param spacing
	 */
	public function textLetterSpacing(spacing:Float) {
		var state = getState();
		state.letterSpacing = spacing;
	}

	/**
	 * Sets the proportional line height of current text style. The line height is specified as multiple of font size.
	 * @param lineHeight
	 */
	public function textLineHeight(lineHeight:Float) {
		var state = getState();
		state.lineHeight = lineHeight;
	}

	/**
	 * Sets the text align of current text style, see `nanovg.Align` for options.
	 * @param align
	 */
	public function textAlign(align:Align) {
		var state = getState();
		state.textAlign = align;
	}

	/**
	 * Sets the font face based on the current text style
	 * @param font
	 */
	public function fontFace(font:FontFace) {
		var state = getState();
		state.font = font;
	}

	/**
	 * Draws text string at specified location. If end is specified only the sub-string up to the end is drawn.
	 * @param x
	 * @param y
	 * @param string
	 * @param end
	 */
	public function text(x:Float, y:Float, string:String, ?end:String) {}

	/**
	 * Draws multi-line text string at specified location wrapped at the specified width. If end is specified only the sub-string up to the end is drawn.
	 * White space is stripped at the beginning of the rows, the text is split at word boundaries or when new-line characters are encountered.
	 * Words longer than the max width are slit at nearest character (i.e. no hyphenation).
	 * @param x
	 * @param y
	 * @param breakRowWidth
	 * @param string
	 * @param end
	 */
	public function textBox(x:Float, y:Float, breakRowWidth:Float, string:String, ?end:String) {}

	/**
	 * Measures the specified text string. Parameter bounds should be a pointer to float[4],
	 * if the bounding box of the text should be returned. The bounds value are [xmin,ymin, xmax,ymax]
	 * Returns the horizontal advance of the measured text (i.e. where the next character should drawn).
	 * Measured values are returned in local coordinate space.
	 * @param x
	 * @param y
	 * @param string
	 * @param end
	 * @param bounds
	 */
	public function textBounds(x:Float, y:Float, string:String, end:Null<String>, bounds:Array<Float>) {}

	/**
	 * Measures the specified multi-text string. Parameter bounds should be float[4],
	 * if the bounding box of the text should be returned. The bounds value are [xmin,ymin, xmax,ymax]
	 * Measured values are returned in local coordinate space.
	 *
	 * @param x
	 * @param y
	 * @param breakRowWidth
	 * @param string
	 * @param end
	 * @param bounds
	 */
	public function textBoxBounds(x:Float, y:Float, breakRowWidth:Float, string:String, end:Null<String>, bounds:Array<Float>) {}

	/**
	 * Calculates the glyph x positions of the specified text. If end is specified only the sub-string will be used.
	 * Measured values are returned in local coordinate space.
	 * @param x
	 * @param y
	 * @param string
	 * @param end
	 * @param positions
	 * @param maxPositions
	 */
	public function textGlyphPositions(x:Float, y:Float, string:String, end:Null<String>, positions:Array<GlyphPosition>, maxPositions:Int) {}

	/**
	 * Returns the vertical metrics based on the current text style.
	 * Measured values are returned in local coordinate space.
	 */
	public function textMetrics():{ascender:Float, descender:Float, lineh:Float} {
		return null;
	}

	/**
	 * Breaks the specified text into lines. If end is specified only the sub-string will be used.
	 * White space is stripped at the beginning of the rows, the text is split at word boundaries or when new-line characters are encountered.
	 * Words longer than the max width are slit at nearest character (i.e. no hyphenation).
	 * @return Int
	 */
	public function textBreakLines():Int {
		return 0;
	}

	inline static function free(x:Dynamic)
		x = null;

	inline static function deletePathCache(c:PathCache) {
		if (c == null)
			return;
		if (c.points != null)
			free(c.points);
		if (c.paths != null)
			free(c.paths);
		if (c.verts != null)
			free(c.verts);
		free(c);
	}

	static function allocPathCache():PathCache {
		var c:PathCache = {
			points: [],
			npoints: 0,
			cpoints: NVG_INIT_POINTS_SIZE,
			paths: [],
			npaths: 0,
			cpaths: NVG_INIT_PATHS_SIZE,
			verts: [],
			nverts: 0,
			cverts: NVG_INIT_VERTS_SIZE
		};

		return c;
	}

	function setDevicePixelRatio(ratio:Float) {
		this.tessTol = 0.25 / ratio;
		this.distTol = 0.01 / ratio;
		this.fringeWidth = 1.0 / ratio;
		this.devicePxRatio = ratio;
	}

	static function compositeOperationState(op:CompositeOperation) {
		var sfactor:BlendFactor, dfactor:BlendFactor;

		if (op == SOURCE_OVER) {
			sfactor = ONE;
			dfactor = ONE_MINUS_SRC_ALPHA;
		} else if (op == SOURCE_IN) {
			sfactor = DST_ALPHA;
			dfactor = ZERO;
		} else if (op == SOURCE_OUT) {
			sfactor = ONE_MINUS_DST_ALPHA;
			dfactor = ZERO;
		} else if (op == ATOP) {
			sfactor = DST_ALPHA;
			dfactor = ONE_MINUS_SRC_ALPHA;
		} else if (op == DESTINATION_OVER) {
			sfactor = ONE_MINUS_DST_ALPHA;
			dfactor = ONE;
		} else if (op == DESTINATION_IN) {
			sfactor = ZERO;
			dfactor = SRC_ALPHA;
		} else if (op == DESTINATION_OUT) {
			sfactor = ZERO;
			dfactor = ONE_MINUS_SRC_ALPHA;
		} else if (op == DESTINATION_ATOP) {
			sfactor = ONE_MINUS_DST_ALPHA;
			dfactor = SRC_ALPHA;
		} else if (op == LIGHTER) {
			sfactor = ONE;
			dfactor = ONE;
		} else if (op == COPY) {
			sfactor = ONE;
			dfactor = ZERO;
		} else if (op == XOR) {
			sfactor = ONE_MINUS_DST_ALPHA;
			dfactor = ONE_MINUS_SRC_ALPHA;
		} else {
			sfactor = ONE;
			dfactor = ZERO;
		}

		var state:CompositeOperationState = {};
		state.srcRGB = sfactor;
		state.dstRGB = dfactor;
		state.srcAlpha = sfactor;
		state.dstAlpha = dfactor;
		return state;
	}

	inline function getState() {
		return this.states[this.nstates - 1];
	}

	static function ptEquals(x1:Float, y1:Float, x2:Float, y2:Float, tol:Float):Bool {
		var dx:Float = x2 - x1;
		var dy:Float = y2 - y1;
		return dx * dx + dy * dy < tol * tol;
	}

	static function distPtSeg(x:Float, y:Float, px:Float, py:Float, qx:Float, qy:Float):Float {
		var pqx:Float;
		var pqy:Float;
		var dx:Float;
		var dy:Float;
		var d:Float;
		var t:Float;
		pqx = qx - px;
		pqy = qy - py;
		dx = x - px;
		dy = y - py;
		d = pqx * pqx + pqy * pqy;
		t = pqx * dx + pqy * dy;
		if (d > 0)
			t /= d;
		if (t < 0)
			t = 0;
		else if (t > 1)
			t = 1;
		dx = px + t * pqx - x;
		dy = py + t * pqy - y;
		return dx * dx + dy * dy;
	}

	function appendCommands(vals:Array<Float>, nvals:Int):Void {
		var state = getState();
		var i:Int;

		if (ncommands + nvals > ccommands) {
			var commands:Array<Float>;
			var ccommands:Int = ncommands + nvals + Std.int(this.ccommands / 2);
			commands = new Array<Float>();
			if (commands == null)
				return;
			this.commands = commands;
			this.ccommands = ccommands;
		}

		if (Std.int(vals[0]) != CLOSE && Std.int(vals[0]) != WINDING) {
			this.commandx = vals[nvals - 2];
			this.commandy = vals[nvals - 1];
		}

		// transform commands
		i = 0;

		while (i < nvals) {
			var cmd:DrawCommands = Std.int(vals[i]);
			switch (cmd) {
				case MOVETO:
					transformPoint(vals[i + 1], vals[i + 2], state.xform, vals[i + 1], vals[i + 2]);
					i += 3;
					break;
				case LINETO:
					transformPoint(vals[i + 1], vals[i + 2], state.xform, vals[i + 1], vals[i + 2]);
					i += 3;
					break;
				case BEZIERTO:
					transformPoint(vals[i + 1], vals[i + 2], state.xform, vals[i + 1], vals[i + 2]);
					transformPoint(vals[i + 3], vals[i + 4], state.xform, vals[i + 3], vals[i + 4]);
					transformPoint(vals[i + 5], vals[i + 6], state.xform, vals[i + 5], vals[i + 6]);
					i += 7;
					break;
				case CLOSE:
					i++;
					break;
				case WINDING:
					i += 2;
					break;
				default:
					i++;
			}
		}

		for (i in 0...nvals) {
			this.commands[this.ncommands + i] = vals[i];
		}

		this.ncommands += nvals;
	}

	function clearPathCache():Void {
		this.cache.npoints = 0;
		this.cache.npaths = 0;
	}

	function lastPath():Path {
		if (this.cache.npaths > 0)
			return this.cache.paths[this.cache.npaths - 1];
		return null;
	}

	function addPath():Void {
		var path:Path;
		if (this.cache.npaths + 1 > this.cache.cpaths) {
			var paths:Array<Path>;
			var cpaths:Int = this.cache.npaths + 1 + Std.int(this.cache.cpaths / 2);
			paths = new Array<Path>();
			if (paths == null)
				return;
			for (i in 0...paths.length) {
				paths[i] = {};
			}
			this.cache.paths = paths;
			this.cache.cpaths = cpaths;
		}
		path = this.cache.paths[this.cache.npaths];
		path = {};
		path.first = this.cache.npoints;
		path.winding = CCW;

		this.cache.npaths++;
	}

	function lastPoint():Point {
		if (this.cache.npoints > 0)
			return this.cache.points[this.cache.npoints - 1];
		return null;
	}

	function addPoint(x:Float, y:Float, flags:Int):Void {
		var path:Path = lastPath();
		var pt:Point;
		if (path == null)
			return;

		if (path.count > 0 && this.cache.npoints > 0) {
			pt = lastPoint();
			if (ptEquals(pt.x, pt.y, x, y, this.distTol)) {
				pt.flags |= flags;
				return;
			}
		}

		if (this.cache.npoints + 1 > this.cache.cpoints) {
			var points:Array<Point>;
			var cpoints:Int = this.cache.npoints + 1 + Std.int(this.cache.cpoints / 2);
			points = new Array<Point>();
			if (points == null)
				return;
			for (i in 0...points.length) {
				points[i] = {};
			}
			this.cache.points = [];
			this.cache.cpoints = cpoints;
		}

		pt = this.cache.points[this.cache.npoints];
		pt = {};
		pt.x = x;
		pt.y = y;
		pt.flags = flags;

		this.cache.npoints++;
		path.count++;
	}

	function __closePath():Void {
		var path:Path = lastPath();
		if (path == null)
			return;
		path.closed = 1;
	}

	function __pathWinding(winding:Winding) {
		var path:Path = lastPath();
		if (path == null)
			return;
		path.winding = winding;
	}

	function getAverageScale(t:Array<Float>) {
		var sx:Float = Math.sqrt(t[0] * t[0] + t[2] * t[2]);
		var sy:Float = Math.sqrt(t[1] * t[1] + t[3] * t[3]);
		return (sx + sy) * 0.5;
	}

	function allocTempVerts(nverts:Int) {
		if (nverts > this.cache.cverts) {
			var verts:Array<Vertex>;
			var cverts:Int = (nverts + 0xff) & ~0xff; // Round up to prevent allocations when things change just slightly.
			verts = new Array<Vertex>();
			if (verts == null)
				return null;
			for (i in 0...verts.length) {
				verts[i] = {};
			}
			this.cache.verts = [];
			this.cache.cverts = cverts;
		}

		return this.cache.verts;
	}

	static function triarea2(ax:Float, ay:Float, bx:Float, by:Float, cx:Float, cy:Float):Float {
		var abx:Float = bx - ax;
		var aby:Float = by - ay;
		var acx:Float = cx - ax;
		var acy:Float = cy - ay;
		return acx * aby - abx * acy;
	}

	static function polyArea(pts:Array<Point>, npts:Int):Float {
		// int i;
		var area:Float = 0;
		for (i in 2...npts) {
			var a:Point = pts[0];
			var b:Point = pts[i - 1];
			var c:Point = pts[i];
			area += triarea2(a.x, a.y, b.x, b.y, c.x, c.y);
		}
		return area * 0.5;
	}

	static function polyReverse(pts:Array<Point>, npts:Int):Void {
		var tmp:Point;
		var i:Int = 0;
		var j:Int = npts - 1;
		while (i < j) {
			tmp = pts[i];
			pts[i] = pts[j];
			pts[j] = tmp;
			i++;
			j--;
		}
	}

	static function vset(vtx:Vertex, x:Float, y:Float, u:Float, v:Float):Void {
		vtx.x = x;
		vtx.y = y;
		vtx.u = u;
		vtx.v = v;
	}

	function tesselateBezier(x1:Float, y1:Float, x2:Float, y2:Float, x3:Float, y3:Float, x4:Float, y4:Float, level:Int, type:Int) {
		var x12:Float;
		var y12:Float;
		var x23:Float;
		var y23:Float;
		var x34:Float;
		var y34:Float;
		var x123:Float;
		var y123:Float;
		var x234:Float;
		var y234:Float;
		var x1234:Float;
		var y1234:Float;
		var dx:Float;
		var dy:Float;
		var d2:Float;
		var d3:Float;

		if (level > 10)
			return;

		x12 = (x1 + x2) * 0.5;
		y12 = (y1 + y2) * 0.5;
		x23 = (x2 + x3) * 0.5;
		y23 = (y2 + y3) * 0.5;
		x34 = (x3 + x4) * 0.5;
		y34 = (y3 + y4) * 0.5;
		x123 = (x12 + x23) * 0.5;
		y123 = (y12 + y23) * 0.5;

		dx = x4 - x1;
		dy = y4 - y1;
		d2 = Math.abs(((x2 - x4) * dy - (y2 - y4) * dx));
		d3 = Math.abs(((x3 - x4) * dy - (y3 - y4) * dx));

		if ((d2 + d3) * (d2 + d3) < this.tessTol * (dx * dx + dy * dy)) {
			addPoint(x4, y4, type);
			return;
		}

		/*	if (absf(x1+x3-x2-x2) + absf(y1+y3-y2-y2) + absf(x2+x4-x3-x3) + absf(y2+y4-y3-y3) < this->tessTol) {
			addPoint(this, x4, y4, type);
			return;
		}*/

		x234 = (x23 + x34) * 0.5;
		y234 = (y23 + y34) * 0.5;
		x1234 = (x123 + x234) * 0.5;
		y1234 = (y123 + y234) * 0.5;

		tesselateBezier(x1, y1, x12, y12, x123, y123, x1234, y1234, level + 1, 0);
		tesselateBezier(x1234, y1234, x234, y234, x34, y34, x4, y4, level + 1, type);
	}

	function flattenPaths():Void {
		var cache:PathCache = this.cache;
		//	NVGstate* state = getState(this);
		var last:Point;
		var p0:Pointer<Point>;
		var p1:Pointer<Point>;
		var pts:Pointer<Point>;
		var path:Path;
		var i:Int;
		var j:Int;
		var cp1:Array<Float>;
		var cp2:Array<Float>;
		var p:Array<Float>;
		var area:Float;

		if (cache.npaths > 0)
			return;

		// Flatten
		i = 0;
		while (i < this.ncommands) {
			var cmd:Int = Std.int(this.commands[i]);
			switch (cmd) {
				case MOVETO:
					addPath();
					p = this.commands.slice(i + 1);
					addPoint(p[0], p[1], PT_CORNER);
					i += 3;
					break;
				case LINETO:
					p = this.commands.slice(i + 1);
					addPoint(p[0], p[1], PT_CORNER);
					i += 3;
					break;
				case BEZIERTO:
					last = lastPoint();
					if (last != null) {
						cp1 = this.commands.slice(i + 1);
						cp2 = this.commands.slice(i + 3);
						p = this.commands.slice(i + 5);
						tesselateBezier(last.x, last.y, cp1[0], cp1[1], cp2[0], cp2[1], p[0], p[1], 0, PT_CORNER);
					}
					i += 7;
					break;
				case CLOSE:
					__closePath();
					i++;
					break;
				case WINDING:
					__pathWinding(Std.int(this.commands[i + 1]));
					i += 2;
					break;
				default:
					i++;
			}
		}

		cache.bounds[0] = cache.bounds[1] = 1e6;
		cache.bounds[2] = cache.bounds[3] = -1e6;

		// Calculate the direction and length of line segments.
		for (j in 0...cache.npaths) {
			path = cache.paths[j];
			pts = new Pointer<Point>(Vector.fromArrayCopy(cache.points.slice(path.first)));

			// If the first and last points are the same, remove the last, mark as closed path.
			p0 = pts.pointer(path.count - 1);
			p1 = pts.pointer(0);
			if (ptEquals(p0.value().x, p0.value().y, p1.value().x, p1.value().y, this.distTol)) {
				path.count--;
				p0 = pts.pointer(path.count - 1);
				path.closed = 1;
			}

			// Enforce winding.
			if (path.count > 2) {
				area = polyArea(pts.arr.toArray(), path.count);
				if (path.winding == CCW && area < 0.0)
					polyReverse(pts.arr.toArray(), path.count);
				if (path.winding == CW && area > 0.0)
					polyReverse(pts.arr.toArray(), path.count);
			}

			for (i in 0...path.count) {
				// Calculate segment direction and length
				p0.value().dx = p1.value().x - p0.value().x;
				p0.value().dy = p1.value().y - p0.value().y;
				p0.value().len = MathExt.normalize(p0.value().dx, p0.value().dy);
				// Update bounds
				cache.bounds[0] = Math.min(cache.bounds[0], p0.value().x);
				cache.bounds[1] = Math.min(cache.bounds[1], p0.value().y);
				cache.bounds[2] = Math.max(cache.bounds[2], p0.value().x);
				cache.bounds[3] = Math.max(cache.bounds[3], p0.value().y);
				// Advance
				p0 = p1.pointer(0);
				p1.inc();
			}
		}
	}

	static function curveDivs(r:Float, arc:Float, tol:Float):Int {
		var da:Float = Math.cos(r / (r + tol)) * 2.0;
		return Std.int(Math.max(2, Std.int(Math.ceil(arc / da))));
	}

	static function chooseBevel(bevel:PointFlags, p0:Point, p1:Point, w:Float, x0:Float, y0:Float, x1:Float, y1:Float) {
		if (bevel != 0) {
			x0 = p1.x + p0.dy * w;
			y0 = p1.y - p0.dx * w;
			x1 = p1.x + p1.dy * w;
			y1 = p1.y - p1.dx * w;
		} else {
			x0 = p1.x + p1.dmx * w;
			y0 = p1.y + p1.dmy * w;
			x1 = p1.x + p1.dmx * w;
			y1 = p1.y + p1.dmy * w;
		}
	}

	static function roundJoin(dst_:Pointer<Vertex>, p0:Point, p1:Point, lw:Float, rw:Float, lu:Float, ru:Float, ncap:Int, fringe:Float):Pointer<Vertex> {
		var dst = dst_.pointer(0);
		var i:Int;
		var n:Int;
		var dlx0:Float = p0.dy;
		var dly0:Float = -p0.dx;
		var dlx1:Float = p1.dy;
		var dly1:Float = -p1.dx;

		if ((p1.flags & PT_LEFT) != 0) {
			var lx0:Float = 0;
			var ly0:Float = 0;
			var lx1:Float = 0;
			var ly1:Float = 0;
			var a0:Float;
			var a1:Float;
			chooseBevel(p1.flags & PR_INNERBEVEL, p0, p1, lw, (lx0), (ly0), (lx1), (ly1));
			a0 = Math.atan2(-dly0, -dlx0);
			a1 = Math.atan2(-dly1, -dlx1);
			if (a1 > a0)
				a1 -= Math.PI * 2;

			vset(dst.value(), lx0, ly0, lu, 1);
			dst.inc();
			vset(dst.value(), p1.x - dlx0 * rw, p1.y - dly0 * rw, ru, 1);
			dst.inc();

			n = Std.int(MathExt.clamp(Std.int(Math.ceil(((a0 - a1) / Math.PI) * ncap)), 2, ncap));
			for (i in 0...n) {
				var u:Float = i / (n - 1);
				var a:Float = a0 + u * (a1 - a0);
				var rx:Float = p1.x + Math.cos(a) * rw;
				var ry:Float = p1.y + Math.sin(a) * rw;
				vset(dst.value(), p1.x, p1.y, 0.5, 1);
				dst.inc();
				vset(dst.value(), rx, ry, ru, 1);
				dst.inc();
			}

			vset(dst.value(), lx1, ly1, lu, 1);
			dst.inc();
			vset(dst.value(), p1.x - dlx1 * rw, p1.y - dly1 * rw, ru, 1);
			dst.inc();
		} else {
			var rx0:Float = 0;
			var ry0:Float = 0;
			var rx1:Float = 0;
			var ry1:Float = 0;
			var a0:Float;
			var a1:Float;
			chooseBevel(p1.flags & PR_INNERBEVEL, p0, p1, -rw, (rx0), (ry0), (rx1), (ry1));
			a0 = Math.atan2(dly0, dlx0);
			a1 = Math.atan2(dly1, dlx1);
			if (a1 < a0)
				a1 += Math.PI * 2;

			vset(dst.value(), p1.x + dlx0 * rw, p1.y + dly0 * rw, lu, 1);
			dst.inc();
			vset(dst.value(), rx0, ry0, ru, 1);
			dst.inc();

			n = Std.int(MathExt.clamp(Std.int(Math.ceil(((a1 - a0) / Math.PI) * ncap)), 2, ncap));
			for (i in 0...n) {
				var u:Float = i / (n - 1);
				var a:Float = a0 + u * (a1 - a0);
				var lx:Float = p1.x + Math.cos(a) * lw;
				var ly:Float = p1.y + Math.sin(a) * lw;
				vset(dst.value(), lx, ly, lu, 1);
				dst.inc();
				vset(dst.value(), p1.x, p1.y, 0.5, 1);
				dst.inc();
			}

			vset(dst.value(), p1.x + dlx1 * rw, p1.y + dly1 * rw, lu, 1);
			dst.inc();
			vset(dst.value(), rx1, ry1, ru, 1);
			dst.inc();
		}
		return dst;
	}

	static function bevelJoin(dst:Pointer<Vertex>, p0:Point, p1:Point, lw:Float, rw:Float, lu:Float, ru:Float, fringe:Float):Pointer<Vertex> {
		var rx0:Float = 0;
		var ry0:Float = 0;
		var rx1:Float = 0;
		var ry1:Float = 0;
		var lx0:Float = 0;
		var ly0:Float = 0;
		var lx1:Float = 0;
		var ly1:Float = 0;
		var dlx0:Float = p0.dy;
		var dly0:Float = -p0.dx;
		var dlx1:Float = p1.dy;
		var dly1:Float = -p1.dx;

		if ((p1.flags & PT_LEFT) != 0) {
			chooseBevel(p1.flags & PR_INNERBEVEL, p0, p1, lw, (lx0), (ly0), (lx1), (ly1));

			vset(dst.value(), lx0, ly0, lu, 1);
			dst.inc();
			vset(dst.value(), p1.x - dlx0 * rw, p1.y - dly0 * rw, ru, 1);
			dst.inc();

			if ((p1.flags & PT_BEVEL) != 0) {
				vset(dst.value(), lx0, ly0, lu, 1);
				dst.inc();
				vset(dst.value(), p1.x - dlx0 * rw, p1.y - dly0 * rw, ru, 1);
				dst.inc();

				vset(dst.value(), lx1, ly1, lu, 1);
				dst.inc();
				vset(dst.value(), p1.x - dlx1 * rw, p1.y - dly1 * rw, ru, 1);
				dst.inc();
			} else {
				rx0 = p1.x - p1.dmx * rw;
				ry0 = p1.y - p1.dmy * rw;

				vset(dst.value(), p1.x, p1.y, 0.5, 1);
				dst.inc();
				vset(dst.value(), p1.x - dlx0 * rw, p1.y - dly0 * rw, ru, 1);
				dst.inc();

				vset(dst.value(), rx0, ry0, ru, 1);
				dst.inc();
				vset(dst.value(), rx0, ry0, ru, 1);
				dst.inc();

				vset(dst.value(), p1.x, p1.y, 0.5, 1);
				dst.inc();
				vset(dst.value(), p1.x - dlx1 * rw, p1.y - dly1 * rw, ru, 1);
				dst.inc();
			}

			vset(dst.value(), lx1, ly1, lu, 1);
			dst.inc();
			vset(dst.value(), p1.x - dlx1 * rw, p1.y - dly1 * rw, ru, 1);
			dst.inc();
		} else {
			chooseBevel(p1.flags & PR_INNERBEVEL, p0, p1, -rw, (rx0), (ry0), (rx1), (ry1));

			vset(dst.value(), p1.x + dlx0 * lw, p1.y + dly0 * lw, lu, 1);
			dst.inc();
			vset(dst.value(), rx0, ry0, ru, 1);
			dst.inc();

			if ((p1.flags & PT_BEVEL) != 0) {
				vset(dst.value(), p1.x + dlx0 * lw, p1.y + dly0 * lw, lu, 1);
				dst.inc();
				vset(dst.value(), rx0, ry0, ru, 1);
				dst.inc();

				vset(dst.value(), p1.x + dlx1 * lw, p1.y + dly1 * lw, lu, 1);
				dst.inc();
				vset(dst.value(), rx1, ry1, ru, 1);
				dst.inc();
			} else {
				lx0 = p1.x + p1.dmx * lw;
				ly0 = p1.y + p1.dmy * lw;

				vset(dst.value(), p1.x + dlx0 * lw, p1.y + dly0 * lw, lu, 1);
				dst.inc();
				vset(dst.value(), p1.x, p1.y, 0.5, 1);
				dst.inc();

				vset(dst.value(), lx0, ly0, lu, 1);
				dst.inc();
				vset(dst.value(), lx0, ly0, lu, 1);
				dst.inc();

				vset(dst.value(), p1.x + dlx1 * lw, p1.y + dly1 * lw, lu, 1);
				dst.inc();
				vset(dst.value(), p1.x, p1.y, 0.5, 1);
				dst.inc();
			}

			vset(dst.value(), p1.x + dlx1 * lw, p1.y + dly1 * lw, lu, 1);
			dst.inc();
			vset(dst.value(), rx1, ry1, ru, 1);
			dst.inc();
		}

		return dst;
	}

	static function buttCapStart(dst_:Pointer<Vertex>, p:Point, dx:Float, dy:Float, w:Float, d:Float, aa:Float, u0:Float, u1:Float):Pointer<Vertex> {
		var dst = dst_.pointer(0);
		var px:Float = p.x - dx * d;
		var py:Float = p.y - dy * d;
		var dlx:Float = dy;
		var dly:Float = -dx;
		vset(dst.value(), px + dlx * w - dx * aa, py + dly * w - dy * aa, u0, 0);
		dst.inc();
		vset(dst.value(), px - dlx * w - dx * aa, py - dly * w - dy * aa, u1, 0);
		dst.inc();
		vset(dst.value(), px + dlx * w, py + dly * w, u0, 1);
		dst.inc();
		vset(dst.value(), px - dlx * w, py - dly * w, u1, 1);
		dst.inc();
		return dst;
	}

	static function buttCapEnd(dst_:Pointer<Vertex>, p:Point, dx:Float, dy:Float, w:Float, d:Float, aa:Float, u0:Float, u1:Float):Pointer<Vertex> {
		var dst = dst_.pointer(0);
		var px:Float = p.x + dx * d;
		var py:Float = p.y + dy * d;
		var dlx:Float = dy;
		var dly:Float = -dx;
		vset(dst.value(), px + dlx * w, py + dly * w, u0, 1);
		dst.inc();
		vset(dst.value(), px - dlx * w, py - dly * w, u1, 1);
		dst.inc();
		vset(dst.value(), px + dlx * w + dx * aa, py + dly * w + dy * aa, u0, 0);
		dst.inc();
		vset(dst.value(), px - dlx * w + dx * aa, py - dly * w + dy * aa, u1, 0);
		dst.inc();
		return dst;
	}

	static function roundCapStart(dst_:Pointer<Vertex>, p:Point, dx:Float, dy:Float, w:Float, ncap:Int, aa:Float, u0:Float, u1:Float):Pointer<Vertex> {
		var dst = dst_.pointer(0);

		var px:Float = p.x;
		var py:Float = p.y;
		var dlx:Float = dy;
		var dly:Float = -dx;

		for (i in 0...ncap) {
			var a:Float = i / (ncap - 1) * Math.PI;
			var ax:Float = Math.cos(a) * w, ay = Math.sin(a) * w;
			vset(dst.value(), px - dlx * ax - dx * ay, py - dly * ax - dy * ay, u0, 1);
			dst.inc();
			vset(dst.value(), px, py, 0.5, 1);
			dst.inc();
		}
		vset(dst.value(), px + dlx * w, py + dly * w, u0, 1);
		dst.inc();
		vset(dst.value(), px - dlx * w, py - dly * w, u1, 1);
		dst.inc();
		return dst;
	}

	static function roundCapEnd(dst_:Pointer<Vertex>, p:Point, dx:Float, dy:Float, w:Float, ncap:Int, aa:Float, u0:Float, u1:Float):Pointer<Vertex> {
		var dst = dst_.pointer(0);
		// int i;
		var px:Float = p.x;
		var py:Float = p.y;
		var dlx:Float = dy;
		var dly:Float = -dx;

		vset(dst.value(), px + dlx * w, py + dly * w, u0, 1);
		dst.inc();
		vset(dst.value(), px - dlx * w, py - dly * w, u1, 1);
		dst.inc();
		for (i in 0...ncap) {
			var a:Float = i / (ncap - 1) * Math.PI;
			var ax:Float = Math.cos(a) * w, ay = Math.sin(a) * w;
			vset(dst.value(), px, py, 0.5, 1);
			dst.inc();
			vset(dst.value(), px - dlx * ax + dx * ay, py - dly * ax + dy * ay, u0, 1);
			dst.inc();
		}
		return dst;
	}

	function calculateJoins(w:Float, lineJoin:LineCap, miterLimit:Float) {
		var iw:Float = 0.0;

		if (w > 0.0)
			iw = 1.0 / w;

		// Calculate which joins needs extra vertices to append, and gather vertex count.
		for (i in 0...cache.npaths) {
			var path:Path = cache.paths[i];
			var pts:Pointer<Point> = new Pointer<Point>(Vector.fromArrayCopy(cache.points.slice(path.first)));
			var p0:Pointer<Point> = pts.pointer(path.count - 1);
			var p1:Pointer<Point> = pts.pointer(0);
			var nleft:Int = 0;

			path.nbevel = 0;

			for (j in 0...path.count) {
				var dlx0:Float;
				var dly0:Float;
				var dlx1:Float;
				var dly1:Float;
				var dmr2:Float;
				var cross:Float;
				var limit:Float;
				dlx0 = p0.value().dy;
				dly0 = -p0.value().dx;
				dlx1 = p1.value().dy;
				dly1 = -p1.value().dx;
				// Calculate extrusions
				p1.value().dmx = (dlx0 + dlx1) * 0.5;
				p1.value().dmy = (dly0 + dly1) * 0.5;
				dmr2 = p1.value().dmx * p1.value().dmx + p1.value().dmy * p1.value().dmy;
				if (dmr2 > 0.000001) {
					var scale:Float = 1.0 / dmr2;
					if (scale > 600.0) {
						scale = 600.0;
					}
					p1.value().dmx *= scale;
					p1.value().dmy *= scale;
				}

				// Clear flags, but keep the corner.
				p1.value().flags = ((p1.value().flags & PT_CORNER) != 0) ? PT_CORNER : 0;

				// Keep track of left turns.
				cross = p1.value().dx * p0.value().dy - p0.value().dx * p1.value().dy;
				if (cross > 0.0) {
					nleft++;
					p1.value().flags |= PT_LEFT;
				}

				// Calculate if we should use bevel or miter for inner join.
				limit = Math.max(1.01, Math.min(p0.value().len, p1.value().len) * iw);
				if ((dmr2 * limit * limit) < 1.0)
					p1.value().flags |= PR_INNERBEVEL;

				// Check to see if the corner needs to be beveled.
				if ((p1.value().flags & PT_CORNER) != 0) {
					if ((dmr2 * miterLimit * miterLimit) < 1.0 || lineJoin == BEVEL || lineJoin == ROUND) {
						p1.value().flags |= PT_BEVEL;
					}
				}

				if ((p1.value().flags & (PT_BEVEL | PR_INNERBEVEL)) != 0)
					path.nbevel++;

				p0 = p1.pointer(0);
				p1.inc();
			}
			path.convex = nleft == path.count;
		}
	}

	function expandStroke(w:Float, fringe:Float, lineCap:LineCap, lineJoin:LineCap, miterLimit:Float) {
		var verts:Pointer<Vertex>;
		var dst:Pointer<Vertex>;
		var cverts:Int;
		var aa:Float = fringe; // ctx->fringeWidth;
		var u0:Float = 0.0;
		var u1:Float = 1.0;
		var ncap:Int = curveDivs(w, NVG_PI, this.tessTol); // Calculate divisions per half circle.

		w += aa * 0.5;

		// Disable the gradient used for antialiasing when antialiasing is not used.
		if (aa == 0.0) {
			u0 = 0.5;
			u1 = 0.5;
		}

		calculateJoins(w, lineJoin, miterLimit);

		// Calculate max vertex usage.
		cverts = 0;
		for (i in 0...cache.npaths) {
			var path:Path = cache.paths[i];
			var loop:Int = (path.closed == 0) ? 0 : 1;
			if (lineJoin == ROUND)
				cverts += (path.count + path.nbevel * (ncap + 2) + 1) * 2; // plus one for loop
			else
				cverts += (path.count + path.nbevel * 5 + 1) * 2; // plus one for loop
			if (loop == 0) {
				// space for caps
				if (lineCap == ROUND) {
					cverts += (ncap * 2 + 2) * 2;
				} else {
					cverts += (3 + 3) * 2;
				}
			}
		}

		verts = new Pointer<Vertex>(Vector.fromArrayCopy(allocTempVerts(cverts)));
		if (verts == null)
			return 0;

		for (i in 0...cache.npaths) {
			var path:Path = cache.paths[i];
			var pts:Pointer<Point> = new Pointer<Point>(Vector.fromArrayCopy(cache.points.slice(path.first)));
			var p0:Pointer<Point>;
			var p1:Pointer<Point>;
			var s:Int;
			var e:Int;
			var loop:Bool;
			var dx:Float;
			var dy:Float;

			path.fill = null;
			path.nfill = 0;

			// Calculate fringe or stroke
			loop = path.closed != 0;
			dst = verts.pointer(0);
			path.stroke = dst.pointer(0).value();

			if (loop) {
				// Looping
				p0 = pts.pointer(path.count - 1);
				p1 = pts.pointer(0);
				s = 0;
				e = path.count;
			} else {
				// Add cap
				p0 = pts.pointer(0);
				p1 = pts.pointer(1);
				s = 1;
				e = path.count - 1;
			}

			if (!loop) {
				// Add cap
				dx = p1.value().x - p0.value().x;
				dy = p1.value().y - p0.value().y;
				MathExt.normalize((dx), (dy));
				if (lineCap == BUTT)
					dst = buttCapStart(dst, p0.value(), dx, dy, w, -aa * 0.5, aa, u0, u1);
				else if (lineCap == BUTT || lineCap == SQUARE)
					dst = buttCapStart(dst, p0.value(), dx, dy, w, w - aa, aa, u0, u1);
				else if (lineCap == ROUND)
					dst = roundCapStart(dst, p0.value(), dx, dy, w, ncap, aa, u0, u1);
			}

			for (j in s...e) {
				if ((p1.value().flags & (PT_BEVEL | PR_INNERBEVEL)) != 0) {
					if (lineJoin == ROUND) {
						dst = roundJoin(dst, p0.value(), p1.value(), w, w, u0, u1, ncap, aa);
					} else {
						dst = bevelJoin(dst, p0.value(), p1.value(), w, w, u0, u1, aa);
					}
				} else {
					vset(dst.value(), p1.value().x + (p1.value().dmx * w), p1.value().y + (p1.value().dmy * w), u0, 1);
					dst.inc();
					vset(dst.value(), p1.value().x - (p1.value().dmx * w), p1.value().y - (p1.value().dmy * w), u1, 1);
					dst.inc();
				}
				p0 = p1.pointer(0);
				p1.inc();
			}

			if (loop) {
				// Loop it
				vset(dst.value(), verts.value(0).x, verts.value(0).y, u0, 1);
				dst.inc();
				vset(dst.value(), verts.value(1).x, verts.value(1).y, u1, 1);
				dst.inc();
			} else {
				// Add cap
				dx = p1.value().x - p0.value().x;
				dy = p1.value().y - p0.value().y;
				MathExt.normalize((dx), (dy));
				if (lineCap == BUTT)
					dst = buttCapEnd(dst, p1.value(), dx, dy, w, -aa * 0.5, aa, u0, u1);
				else if (lineCap == BUTT || lineCap == SQUARE)
					dst = buttCapEnd(dst, p1.value(), dx, dy, w, w - aa, aa, u0, u1);
				else if (lineCap == ROUND)
					dst = roundCapEnd(dst, p1.value(), dx, dy, w, ncap, aa, u0, u1);
			}

			path.nstroke = dst.sub(verts);

			verts = dst;
		}

		return 1;
	}

	function expandFill(w:Float, lineJoin:LineCap, miterLimit:Float) {
		var verts:Pointer<Vertex>;
		var dst:Pointer<Vertex>;
		var cverts:Int;
		var convex:Bool;
		var aa:Float = fringeWidth;
		var fringe:Bool = w > 0.0;

		calculateJoins(w, lineJoin, miterLimit);

		// Calculate max vertex usage.
		cverts = 0;
		for (i in 0...cache.npaths) {
			var path:Path = cache.paths[i];
			cverts += path.count + path.nbevel + 1;
			if (fringe)
				cverts += (path.count + path.nbevel * 5 + 1) * 2; // plus one for loop
		}

		verts = new Pointer<Vertex>(Vector.fromArrayCopy(allocTempVerts(cverts)));
		if (verts == null)
			return 0;

		convex = cache.npaths == 1 && cache.paths[0].convex;

		for (i in 0...cache.npaths) {
			var path:Path = cache.paths[i];
			var pts:Pointer<Point> = new Pointer<Point>(Vector.fromArrayCopy(cache.points.slice(path.first)));
			var p0:Pointer<Point>;
			var p1:Pointer<Point>;
			var rw:Float;
			var lw:Float;
			var woff:Float;
			var ru:Float;
			var lu:Float;

			// Calculate shape vertices.
			woff = 0.5 * aa;
			dst = verts.pointer(0);
			path.fill = dst.pointer(0).value();

			if (fringe) {
				// Looping
				p0 = pts.pointer(path.count - 1);
				p1 = pts.pointer(0);
				for (j in 0...path.count) {
					if ((p1.value().flags & PT_BEVEL) != 0) {
						var dlx0:Float = p0.value().dy;
						var dly0:Float = -p0.value().dx;
						var dlx1:Float = p1.value().dy;
						var dly1:Float = -p1.value().dx;
						if ((p1.value().flags & PT_LEFT) != 0) {
							var lx:Float = p1.value().x + p1.value().dmx * woff;
							var ly:Float = p1.value().y + p1.value().dmy * woff;
							vset(dst.value(), lx, ly, 0.5, 1);
							dst.inc();
						} else {
							var lx0:Float = p1.value().x + dlx0 * woff;
							var ly0:Float = p1.value().y + dly0 * woff;
							var lx1:Float = p1.value().x + dlx1 * woff;
							var ly1:Float = p1.value().y + dly1 * woff;
							vset(dst.value(), lx0, ly0, 0.5, 1);
							dst.inc();
							vset(dst.value(), lx1, ly1, 0.5, 1);
							dst.inc();
						}
					} else {
						vset(dst.value(), p1.value().x + (p1.value().dmx * woff), p1.value().y + (p1.value().dmy * woff), 0.5, 1);
						dst.inc();
					}
					p0 = p1.pointer(0);
					p1.inc();
				}
			} else {
				for (j in 0...path.count) {
					vset(dst.value(), pts.value(j).x, pts.value(j).y, 0.5, 1);
					dst.inc();
				}
			}

			path.nfill = dst.sub(verts);
			verts = dst;

			// Calculate fringe
			if (fringe) {
				lw = w + woff;
				rw = w - woff;
				lu = 0;
				ru = 1;
				dst = verts.pointer(0);
				path.stroke = dst.pointer(0).value();

				// Create only half a fringe for convex shapes so that
				// the shape can be rendered without stenciling.
				if (convex) {
					lw = woff; // This should generate the same vertex as fill inset above.
					lu = 0.5; // Set outline fade at middle.
				}

				// Looping
				p0 = pts.pointer(path.count - 1);
				p1 = pts.pointer(0);

				for (j in 0...path.count) {
					if ((p1.value().flags & (PT_BEVEL | PR_INNERBEVEL)) != 0) {
						dst = bevelJoin(dst, p0.value(), p1.value(), lw, rw, lu, ru, fringeWidth);
					} else {
						vset(dst.value(), p1.value().x + (p1.value().dmx * lw), p1.value().y + (p1.value().dmy * lw), lu, 1);
						dst.inc();
						vset(dst.value(), p1.value().x - (p1.value().dmx * rw), p1.value().y - (p1.value().dmy * rw), ru, 1);
						dst.inc();
					}
					p0 = p1.pointer(0);
					p1.inc();
				}

				// Loop it
				vset(dst.value(), verts.value(0).x, verts.value(0).y, lu, 1);
				dst.inc();
				vset(dst.value(), verts.value(1).x, verts.value(1).y, ru, 1);
				dst.inc();

				path.nstroke = dst.sub(verts);
				verts = dst;
			} else {
				path.stroke = null;
				path.nstroke = 0;
			}
		}

		return 1;
	}
}
