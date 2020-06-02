package nanovg;

import haxe.io.FPHelper;


// The following functions can be used to make calculations on 2x3 transformation matrices.
// A 2x3 matrix is represented as float[6].
@:forward(copy)
abstract Matrix(Array<Float>) from Array<Float> to Array<Float>{

    public inline function new(a:Array<Float>) {
        this = a;
    }

    /**
     * Sets the transform to identity matrix.
     */
    public function transformIdentity() {
        this[0] = 1.0; this[1] = 0.0;
        this[2] = 0.0; this[3] = 1.0;
        this[4] = 0.0; this[5] = 0.0;
    }

    /**
     * Sets the transform to translation matrix.
     * @param tx 
     * @param ty 
     */
    public function transformTranslate(tx:Float, ty:Float) {
        this[0] = 1.0; this[1] = 0.0;
        this[2] = 0.0; this[3] = 1.0;
        this[4] = tx; this[5] = ty;
    }

    /**
     * Sets the transform to scale matrix.
     * @param sx 
     * @param sy 
     */
    public function transformScale(sx:Float, sy:Float) {
        this[0] = sx; this[1] = 0.0;
        this[2] = 0.0; this[3] = sy;
        this[4] = 0.0; this[5] = 0.0;
    }

    /**
     * Sets the transform to rotate matrix. Angle is specified in radians.
     * @param a 
     */
    public function transformRotate(a:Float) {
        var cs = Math.cos(a);
        var sn = Math.sin(a);
        this[0] = cs; this[1] = sn;
        this[2] = -sn; this[3] = cs;
        this[4] = 0.0; this[5] = 0.0;
    }

    /**
     * Sets the transform to skew-x matrix. Angle is specified in radians.
     * @param a 
     */
    public function transformSkewX(a:Float) {
        this[0] = 1.0; this[1] = 0.0;
        this[2] = Math.tan(a); this[3] = 1.0;
        this[4] = 0.0; this[5] = 0.0;
    }

    /**
     * Sets the transform to skew-y matrix. Angle is specified in radians.
     * @param a 
     */
    public function transformSkewY(a:Float) {
        this[0] = 1.0; this[1] = Math.tan(a);
        this[2] = 0.0; this[3] = 1.0;
        this[4] = 0.0; this[5] = 0.0;
    }

    /**
     * Sets the transform to the result of multiplication of two transforms, of A = A*B.
     * @param src 
     */
    public function transformMultiply(s:Matrix) {
        var t0 = this[0] * s[0] + this[1] * s[2];
        var t2 = this[2] * s[0] + this[3] * s[2];
        var t4 = this[4] * s[0] + this[5] * s[2] + s[4];
        this[1] = this[0] * s[1] + this[1] * s[3];
        this[3] = this[2] * s[1] + this[3] * s[3];
        this[5] = this[4] * s[1] + this[5] * s[3] + s[5];
        this[0] = t0;
        this[2] = t2;
        this[4] = t4;
    }

    /**
     * Sets the transform to the result of multiplication of two transforms, of A = B*A.
     * @param src 
     */
    public inline function transformPremultiply(s:Matrix) {
        var s2:Matrix = s.copy();
        s2.transformMultiply(this);
        this = s2.copy();
    }

    /**
     * Sets the destination to inverse of specified transform.
     * Returns 1 if the inverse could be calculated, else 0.
     * @param src 
     */
    public function transformInverse(src:Matrix):Int {
        var invdet:Float;
        var det = this[0] * this[3] - this[2] * this[1];
        if (det > -1e-6 && det < 1e-6) {
            transformIdentity();
            return 0;
        }


        invdet = 1.0 / det;
        this[0] = Std.int(this[3] * invdet);
        this[2] = Std.int(-this[2] * invdet);
        this[4] = Std.int((this[2] * this[5] - this[3] * this[4]) * invdet);
        this[1] = Std.int(-this[1] * invdet);
        this[3] = Std.int(this[0] * invdet);
        this[5] = Std.int((this[1] * this[4] - this[0] * this[5]) * invdet);
        return 0;
    }
    
}