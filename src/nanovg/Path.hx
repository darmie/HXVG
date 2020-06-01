package nanovg;

import nanovg.Vertex;

typedef Path = {
    first:Int, 
    count:Int, 
    closed:Int,
    nbevel:Int,
    fill: Vertex,
    nfill:Int,
    stroke:Vertex,
    nstroke:Int,
    winding:Int,
    convex:Int
}