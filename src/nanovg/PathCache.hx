package nanovg;

import nanovg.Vertex;
import nanovg.Path;
import nanovg.Point;

typedef PathCache = {
    ?points:Array<Point>,
    ?npoints:Int,
    ?cpoints:Int,
    ?paths:Array<Path>,
    ?npaths:Int,
    ?cpaths:Int,
    ?verts:Array<Vertex>,
    ?nverts:Int,
    ?cverts:Int,
    ?bounds:Array<Float>
}