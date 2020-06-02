package nanovg;

enum abstract DrawCommands (Int) from Int to Int{
    var MOVETO;
	var LINETO;
	var BEZIERTO;
	var CLOSE;
	var WINDING;
}