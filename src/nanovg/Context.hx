package nanovg;

import nanovg.Font.FontFace;
import nanovg.CompositeOperationState.CompositeOperation;

/**
 * Nanovg Context
 */
class Context {
	public function new() {}

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
	public function beginFrame(windowWidth:Float, windowHeight:Float, devicePixelRatio:Float) {}

	/**
	 * Cancels drawing the current frame.
	 */
	public function cancelFrame() {}

	/**
	 * Ends drawing flushing remaining render state.
	 */
	public function endFrame() {}

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
	public function globalCompositeOperation(op:CompositeOperation) {}

	/**
	 * Sets the composite operation with custom pixel arithmetic. The parameters should be one of BlendFactor.
	 * @param sfactor
	 * @param dfactor
	 */
	public function globalCompositeBlendFunc(sfactor:BlendFactor, dfactor:BlendFactor) {}

	/**
	 * Sets the composite operation with custom pixel arithmetic for RGB and alpha components separately. The parameters should be one of NVGblendFactor.
	 * @param srcRGB
	 * @param dstRGB
	 * @param srcAlpha
	 * @param dstAlpha
	 */
	public function globalCompositeBlendFuncSeparate(srcRGB:BlendFactor, dstRGB:BlendFactor, srcAlpha:BlendFactor, dstAlpha:BlendFactor) {}

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
	public function save() {}

	/**
	 * Pops and restores current render state.
	 */
	public function restore() {}

	/**
	 * Resets current render state to default values. Does not affect the render state stack.
	 */
	public function reset() {}

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
	public function shapeAntialias(enabled:Int) {}

	/**
	 * Sets current stroke style to a solid color.
	 * @param color
	 */
	public function strokeColor(color:Color) {}

	/**
	 * Sets current stroke style to a paint, which can be a one of the gradients or a pattern.
	 * @param paint
	 */
	public function strokePaint(paint:Paint) {}

	/**
	 * Sets current fill style to a solid color.
	 * @param color
	 */
	public function fillColor(color:Color) {}

	/**
	 * Sets current fill style to a paint, which can be a one of the gradients or a pattern.
	 * @param paint
	 */
	public function fillPaint(paint:Paint) {}

	/**
	 * Sets the miter limit of the stroke style.
	 * Miter limit controls when a sharp corner is beveled.
	 * @param limit
	 */
	public function miterLimit(limit:Float) {}

	/**
	 * Sets the stroke width of the stroke style.
	 * @param size
	 */
	public function strokeWidth(size:Float) {}

	/**
	 * Sets how the end of the line (cap) is drawn,
	 * Can be one of: BUTT (default), ROUND, SQUARE.
	 * @param linecap
	 */
	public function lineCap(cap:LineCap = BUTT) {}

	/**
	 * Sets how sharp path corners are drawn.
	 * Can be one of MITER (default), ROUND, BEVEL.
	 * @param join
	 */
	public function lineJoin(join:LineCap = MITER) {}

	/**
	 * Sets the transparency applied to all rendered shapes.
	 * Already transparent paths will get proportionally more transparent as well.
	 * @param alpha
	 */
	public function globalAlpha(alpha:Float) {}

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
	public function resetTransform() {}

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
	public function transform(a:Float, b:Float, c:Float, d:Float, e:Float, f:Float) {}

	/**
	 * Translates current coordinate system.
	 * @param x
	 * @param y
	 */
	public function translate(x:Float, y:Float) {}

	/**
	 * Rotates current coordinate system. Angle is specified in radians.
	 */
	public function rotate(angle:Float) {}

	/**
	 * Skews the current coordinate system along X axis. Angle is specified in radians.
	 * @param angle
	 */
	public function skewX(angle:Float) {}

	/**
	 * Skews the current coordinate system along Y axis. Angle is specified in radians.
	 * @param angle
	 */
	public function skewY(angle:Float) {}

	/**
	 * Scales the current coordinate system.
	 * @param x
	 * @param y
	 */
	public function scale(x:Float, y:Float) {}

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
	public function currentTransform(xform:Array<Float>) {}

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
		return null;
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
		return null;
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
	public function imagePattern(ox:Float, oy:Float, ex:Float, ey:Float, angle:Float, image:Image, alpha:Float):Paint {
		return null;
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
	public function scissor(x:Float, y:Float, w:Float, h:Float) {}

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
	public function intersectScissor(x:Float, y:Float, w:Float, h:Float) {}

	/**
	 * Reset and disables scissoring.
	 */
	public function resetScissor() {}

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
	public function beginPath() {}

	/**
	 * Starts new sub-path with specified point as first point.
	 * @param x
	 * @param y
	 */
	public function moveTo(x:Float, y:Float) {}

	/**
	 * Adds line segment from the last point in the path to the specified point.
	 * @param x
	 * @param y
	 */
	public function lineTo(x:Float, y:Float) {}

	/**
	 * Adds cubic bezier segment from last point in the path via two control points to the specified point.
	 * @param c1x
	 * @param c1y
	 * @param c2x
	 * @param c2y
	 * @param x
	 * @param y
	 */
	public function bezierTo(c1x:Float, c1y:Float, c2x:Float, c2y:Float, x:Float, y:Float) {}

	/**
	 * Adds quadratic bezier segment from last point in the path via a control point to the specified point.
	 * @param cx
	 * @param cy
	 * @param x
	 * @param y
	 */
	public function quadTo(cx:Float, cy:Float, x:Float, y:Float) {}

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
	public function closePath() {}

	/**
	 *  Sets the current sub-path winding, see Winding and Solidity.
	 * @param dir
	 */
	public function pathWinding(dir:Winding) {}

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
	public function arc(cx:Float, cy:Float, r:Float, a0:Float, a1:Float, dir:Winding) {}

	/**
	 * Creates new rectangle shaped sub-path.
	 * @param x
	 * @param y
	 * @param w
	 * @param h
	 */
	public function rect(x:Float, y:Float, w:Float, h:Float) {}

	/**
	 * Creates new rounded rectangle shaped sub-path.
	 * @param x
	 * @param y
	 * @param w
	 * @param h
	 * @param r
	 */
	public function roundedRect(x:Float, y:Float, w:Float, h:Float, r:Float) {}

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
	public function roundedRectVarying(x:Float, y:Float, w:Float, h:Float, radTopLeft:Float, radTopRight:Float, radBottomRight:Float, radBottomLeft:Float) {}

	/**
	 * Creates new ellipse shaped sub-path.
	 * @param cx
	 * @param cy
	 * @param rx
	 * @param ry
	 */
	public function ellipse(cx:Float, cy:Float, rx:Float, ry:Float) {}

	/**
	 * Creates new circle shaped sub-path.
	 * @param cx
	 * @param cy
	 * @param rx
	 * @param ry
	 */
    public function circle(cx:Float, cy:Float, r:Float) {}
    
    /**
     * Fills the current path with current fill style.
     */
    public function fill() {
        
    }

    /**
     * Fills the current path with current stroke style.
     */
    public function stroke() {
        
    }


    /**
     * Sets the font size of current text style.
     * @param size 
     */
     public function size(size:Float) {
        
    }

    /**
     * Sets the blur of current text style.
     * @param blur 
     */
    public function blur(blur:Float) {
        
    }

    /**
     * Sets the letter spacing of current text style.
     * @param spacing 
     */
    public function textLetterSpacing(spacing:Float) {
        
    }

    /**
     * Sets the proportional line height of current text style. The line height is specified as multiple of font size.
     * @param lineHeight 
     */
    public function textLineHeight(lineHeight:Float) {
        
    }

    /**
     * Sets the text align of current text style, see `nanovg.Align` for options.
     * @param align 
     */
    public function textAlign(align:Align) {
        
    }

    /**
     * Sets the font face based on the current text style
     * @param font 
     */
    public function fontFace(font:FontFace) {
        
    }

    /**
     * Draws text string at specified location. If end is specified only the sub-string up to the end is drawn.
     * @param x 
     * @param y 
     * @param string 
     * @param end 
     */
    public function text(x:Float, y:Float, string:String, ?end:String) {
        
    }

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
    public function textBox(x:Float, y:Float, breakRowWidth:Float, string:String, ?end:String) {
        
    }

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
    public function textBounds(x:Float, y:Float, string:String, end:Null<String>, bounds:Array<Float>) {
        
    }

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
    public function textBoxBounds(x:Float, y:Float, breakRowWidth:Float, string:String, end:Null<String>, bounds:Array<Float>) {
        
    }

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
    public function textGlyphPositions(x:Float, y:Float, string:String, end:Null<String>, positions:Array<GlyphPosition>, maxPositions:Int) {
        
    }

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


}
