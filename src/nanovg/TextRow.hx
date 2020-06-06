package nanovg;

typedef TextRow = {
    var string:String;
    /**
     * The input text where the row starts.
     */
    var start:Int;
    /**
     * the input text where the row ends (one past the last character).
     */
    var end:Int;

    /**
     * The beginning of the next row.
     */
    var next:Int;

    /**
     * Logical width of the row.
     */
    var width:Float;

     // Actual bounds of the row. Logical with and bounds can differ because of kerning and some parts over extending.
     var minx:Float;
     var maxx:Float;
}