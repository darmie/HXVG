package nanovg;

class MathExt {
    public static function clamp(a:Float, mn:Float, mx:Float) {
        return a < mn ? mn : (a > mx ? mx : a);
    }

    public static function sign(a:Float) {
        return a >= 0.0 ? 1.0 : -1.0;
    }

    public static function cross(dx0:Float, dy0:Float, dx1:Float, dy1:Float) {
        return dx1*dy0 - dx0*dy1;
    }

    public static function normalize(x:Float, y:Float) {
        var d = Math.sqrt((x * x) + (y * y));

        if(d > 1e-6){
            var id = 1.0 / d;
            x *= id;
            y *= id;
        }

        return d;
    }

    public static function quantize(a: Float, d: Float): Float {
        return Std.int((a / d + 0.5)) * d;
    }

    public static function DegToRad(deg:Float):Float {
        return deg / 180.0 * Math.PI;
    }

    public static function RadToDeg(rad:Float):Float {
        return rad / Math.PI * 180.0;
    }
}