package nanovg;

typedef TextRow = {
    /**
     * The input text where the row starts.
     */
    var start:String;
    /**
     * the input text where the row ends (one past the last character).
     */
    var end:String;

    /**
     * The beginning of the next row.
     */
    var next:String;

    /**
     * Logical width of the row.
     */
    var width:Float;

     // Actual bounds of the row. Logical with and bounds can differ because of kerning and some parts over extending.
     var minx:Float;
     var maxx:Float;
}