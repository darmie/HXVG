package nanovg;


// The following functions can be used to make calculations on 2x3 transformation matrices.
// A 2x3 matrix is represented as float[6].
abstract Matrix(Array<Float>) from Array<Float> to Array<Float>{

    public inline function new(a:Array<Float>) {
        this = a;
    }

    /**
     * Sets the transform to identity matrix.
     */
    public function transformIdentity() {
        
    }

    /**
     * Sets the transform to translation matrix.
     * @param tx 
     * @param ty 
     */
    public function transformTranslate(tx:Float, ty:Float) {
        
    }

    /**
     * Sets the transform to scale matrix.
     * @param sx 
     * @param sy 
     */
    public function transformScale(sx:Float, sy:Float) {
        
    }

    /**
     * Sets the transform to rotate matrix. Angle is specified in radians.
     * @param a 
     */
    public function transformRotate(a:Float) {
        
    }

    /**
     * Sets the transform to skew-x matrix. Angle is specified in radians.
     * @param a 
     */
    public function transformSkewX(a:Float) {
        
    }

    /**
     * Sets the transform to skew-y matrix. Angle is specified in radians.
     * @param a 
     */
    public function transformSkewY(a:Float) {
        
    }

    /**
     * Sets the transform to the result of multiplication of two transforms, of A = A*B.
     * @param src 
     */
    public function transformMultiply(src:Matrix) {
        
    }

    /**
     * Sets the transform to the result of multiplication of two transforms, of A = B*A.
     * @param src 
     */
    public function transformPremultiply(src:Matrix) {
        
    }

    /**
     * Sets the destination to inverse of specified transform.
     * Returns 1 if the inverse could be calculated, else 0.
     * @param src 
     */
    public function transformInverse(src:Matrix):Int {
        return 0;
    }

    /**
     * Transform a point by given transform.
     * @param dstx 
     * @param dsty 
     * @param xform 
     * @param srcx 
     * @param srcy 
     */
    public static function transformPoint(dstx:Matrix, dsty:Matrix, xform:Matrix, srcx:Float, srcy:Float) {
        
    }
    
}