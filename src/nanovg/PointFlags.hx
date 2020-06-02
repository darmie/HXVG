package nanovg;

enum abstract PointFlags(Int) from Int to Int {
    inline function new(i:Int) {
        this = i;
    }

    var PT_CORNER = 0x01;
    var PT_LEFT = 0x02;
    var PT_BEVEL = 0x04;
    var PR_INNERBEVEL = 0x08;
}