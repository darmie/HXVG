package truetype;

import polygonal.ds.ArrayList;
import haxe.ds.Vector;
import haxe.io.Bytes;

enum abstract PLATFORM_ID(Int) from Int to Int {
	var PLATFORM_ID_UNICODE;
	var PLATFORM_ID_MAC;
	var PLATFORM_ID_ISO;
	var PLATFORM_ID_MICROSOFT;
}

enum abstract MS_EID(Int) from Int to Int {
	var MS_EID_SYMBOL = 0;
	var MS_EID_UNICODE_BMP = 1;
	var MS_EID_SHIFTJIS = 2;
	var MS_EID_UNICODE_FULL = 10;
}

enum abstract V(U8) from U8 to U8 {
	var vmove = 1;
	var vline;
	var vcurve;
}

enum abstract TT(U32) from U32 to U32 {
	var tt_FIXSHIFT = 10;
	var tt_FIX = (1 << tt_FIXSHIFT);
	var tt_FIXMASK = (tt_FIX - 1);
}

typedef Vertex = {
	?x:Int,
	?y:Int,
	?cx:Int,
	?cy:Int,
	?type:U8,
	?padding:I8
}

typedef Point = {
	x:Float,
	y:Float
}

typedef Bitmap = {
	?w:Int,
	?h:Int,
	?stride:Int,
	?pixels:Bytes
}

typedef Edge = {
	?x0:Float,
	?y0:Float,
	?x1:Float,
	?y1:Float,
	?invert:Bool
}

@:forward(pop, push)
abstract Edges(Array<Edge>) {
	inline function new(e:Array<Edge>) {
		this = e;
	}

	@:from
	public static inline function fromVector(v:Vector<Edge>):Edges
		return new Edges(v.toArray());

	@:arrayAccess
	public inline function get(i:Int):Edge
		return this[i];

	@:arrayAccess
	public inline function set(i:Int, e:Edge) {
		this.push(e);
	}

	public inline function length():Int {
		return this.length;
	}

	public inline function swap(i:Int, j:Int) {
		this[i] = this[j];
		this[j] = this[i];
	}

	public inline function less(i:Int, j:Int):Bool {
		return this[i].y0 < this[j].y0;
	}
}

typedef ActiveEdge = {
	?x:Int,
	?dx:Int,
	?ey:Float,
	?valid:Int
}

class TrueType {
	public static function rasterize(result:Bitmap, flatnessInPixels:Float, vertices:ArrayList<Vertex>, scaleX:Float, scaleY:Float, shiftX:Float, shiftY:Float,
			xOff:Int, yOff:Int, invert:Bool) {
		var scale:Float;
		if (scaleX > scaleY) {
			scale = scaleY;
		} else {
			scale = scaleX;
		}

		var winding = flattenCurves(vertices, flatnessInPixels / scale);
		if (winding.windings != null) {
			tt_rasterize(result, winding.windings, winding.lengths, winding.count, scaleX, scaleY, shiftX, shiftY, xOff, yOff, invert);
		}
	}

	static function tt_rasterize(result:Bitmap, pts:Array<Point>, wcount:Array<Int>, windings:Int, scaleX:Float, scaleY:Float, shiftX:Float, shiftY:Float,
			offX:Int, offY:Int, invert:Bool) {
		var yScaleInv:Float;
		if (invert) {
			yScaleInv = -scaleY;
		} else {
			yScaleInv = scaleY;
		}

		var vsubsample:Int;

		if (result.h < 8) {
			vsubsample = 15;
		} else {
			vsubsample = 5;
		}

		// vsubsample should divide 255 evenly; otherwise we won't reach full opacity

		// now we have to blow out the windings into explicit edge lists
		var n = 0;
		for (i in 0...windings) {
			n += wcount[i];
		}

		var e:ArrayList<Edge> = new ArrayList<Edge>(n + 1);
		n = 0;

		var m = 0;
		for (i in 0...windings) {
			var winding = wcount[i];
			var p = pts.slice(m);
			m += winding;
			var j = winding - 1;

			for (k in 0...winding) {
				var a = k;
				var b = j;

				// skip the edge if horizontal
				if (p[j].y == p[k].y) {
					j = k;
					continue;
				}

				// add edge from j to k to the list
				e.get(n).invert = false;
				if (invert) {
					if (p[j].y > p[k].y) {
						e.get(n).invert = true;
						a = j;
						b = k;
					}
				} else {
					if (p[j].y < p[k].y) {
						e.get(n).invert = true;
						a = j;
						b = k;
					}
				}
				e.get(n).x0 = p[a].x * scaleX + shiftX;
				e.get(n).y0 = p[a].y * yScaleInv * vsubsample + shiftY;
				e.get(n).x1 = p[b].x * scaleX + shiftX;
				e.get(n).y1 = p[b].y * yScaleInv * vsubsample + shiftY;
				n++;
				j = k;
			}
		}
		// now sort the edges by their highest point (should snap to integer, and then by x
		e.sort(null, true, 0, n);
		// now, traverse the scanlines and find the intersections on each scanline, use xor winding rule
		rasterizeSortedEdges(result, e, n, vsubsample, offX, offY);
	}

	public static function flattenCurves(vertices:ArrayList<Vertex>, objspaceFlatness:Float):{windings:Array<Point>, lengths:Array<Int>, count:Int} {
		var contourLengths:Vector<Int>;
		var points:Array<Point> = [];

		var objspaceFlatnessSquared = objspaceFlatness * objspaceFlatness;

		var n = 0;
		var start = 0;

		for (vertex in vertices) {
			if (vertex.type == vmove) {
				n++;
			}
		}

		var numContours = n;

		if (n == 0) {
			return {windings: null, lengths: null, count: 0};
		}

		contourLengths = new Vector<Int>(n);

		var x, y:Float;

		n = -1;

		for (vertex in vertices) {
			switch vertex.type {
				case vmove:
					{
						if (n >= 0) {
							contourLengths[n] = (points.length) - start;
						}

						n++;
						start = points.length;

						x = (vertex.x);
						y = (vertex.y);

						points.push({x: x, y: y});
					}
				case vline:
					{
						x = (vertex.x);
						y = (vertex.y);
						points.push({x: x, y: y});
					}
				case vcurve:
					{
						tesselateCurve(points, x, y, vertex.cx, vertex.cy, vertex.x, vertex.y, objspaceFlatnessSquared, 0);
						x = (vertex.x);
						y = (vertex.y);
					}
			}

			contourLengths[n] = points.length - start;
		}

		return {windings: points, lengths: contourLengths.toArray(), count: numContours};
	}

	public static function tesselateCurve(points:Array<Point>, x0:Float, y0:Float, x1:Float, y1:Float, x2:Float, y2:Float, objspaceFlatnessSquared:Float,
			n:Int) {
		// midpoint
		var mx = (x0 + 2 * x1 + x2) / 4;
		var my = (y0 + 2 * y1 + y2) / 4;
		// versus directly drawn line
		var dx = (x0 + x2) / 2 - mx;
		var dy = (y0 + y2) / 2 - my;

		if (n > 16) {
			return 1;
		}

		if (dx * dx + dy * dy > objspaceFlatnessSquared) { // half-pixel error allowed... need to be smaller if AA
			tesselateCurve(points, x0, y0, (x0 + x1) / 2, (y0 + y1) / 2, mx, my, objspaceFlatnessSquared, n + 1);
			tesselateCurve(points, mx, my, (x1 + x2) / 2, (y1 + y2) / 2, x2, y2, objspaceFlatnessSquared, n + 1);
		} else {
			points.push({x: x2, y: y2});
		}
		return 1;
	}

	public static function newActive(e:Edge, offX:Int, startPoint:Float):ActiveEdge {
		var z:ActiveEdge = {};
		var dxdy = (e.x1 - e.x0) / (e.y1 - e.y0);

		if (dxdy < 0) {
			z.dx = -Std.int(Math.floor(tt_FIX * -dxdy));
		} else {
			z.dx = Std.int(Math.floor(tt_FIX * dxdy));
		}
		z.x = Std.int(Math.floor(tt_FIX * (e.x0 + dxdy * (startPoint - e.y0))));
		z.x -= offX * tt_FIX;
		z.ey = e.y1;
		if (e.invert) {
			z.valid = 1;
		} else {
			z.valid = -1;
		}
		return z;
	}

	public static function rasterizeSortedEdges(result:Bitmap, e:ArrayList<Edge>, n:Int, vsubsample:Int, offX:Int, offY:Int) {
		var scanline:Bytes;
		var active:ArrayList<ActiveEdge>;

		// weight per vertical scanline
		var maxWeight = (255 / vsubsample);

		var dataLength = 512;
		if (result.w > 512) {
			dataLength = result.w;
		}

		var y = offY * vsubsample;

		e.get(n).y0 = (offY + result.h) * (vsubsample) + 1;
		var j:Float;
		var i:Int;

		while (j < result.h) {
			scanline = Bytes.alloc(dataLength);
			for (s in 0...vsubsample) {
				// find center of pixel for this scanline
				var scanY = y + 0.5;
				// update all active edges;
				// remove all active edges that terminate before the center of this scanline
				var next:ActiveEdge;
				var step = active.front();
				while (step != null) {
					var z = step;
					if (z.ey <= scanY) {
						next = active.iterator().next();
						active.remove(z);
					} else {
						z.x += z.dx;
						next = active.iterator().next();
					}
					step = next;
				}
				// resort the list if needed
				while (true) {
					var changed = false;
					var step = active.front();
					while (step != null && active.iterator().hasNext()) {
						var next = active.iterator().next();
						if (step.x > next.x) {
							active.insert(active.indexOf(next), step);
							changed = true;
							step = active.get(active.indexOf(next) - 1);
						}
						step = active.iterator().next();
					}

					if (!changed) {
						break;
					}
				}

				// insert all edges that start before the center of this scanline -- omit ones that also end on this scanline
				while (e.get(i).y0 <= scanY) {
					if (e.get(i).y1 > scanY) {
						var z = newActive(e.get(i), offX, scanY);
						if (active.size == 0) {
							active.pushBack(z);
						} else if (z.x < active.front().x) {
							active.pushFront(z);
						} else {
							var p = active.front();
							var next = active.iterator().next();
							if (p != null && next.x < z.x) {
								p = next;
							}
							active.insert(active.indexOf(z) + 1, p);
						}
					}
					i++;
				}
				// now process all active edges in XOR fashion
				if (active.size > 0) {
					scanline = fillActiveEdges(scanline, result.w, active, Std.int(maxWeight));
				}

				y++;
			}

			result.pixels.blit(Std.int(j) * result.stride, scanline, 0, result.w);
			j++;
		}
	}

	static function fillActiveEdges(scanline:Bytes, length:Int, e:ArrayList<ActiveEdge>, maxWeight:Int):Bytes {
		// non-zero winding fill
		var x0 = 0;
		var w = 0;

		var p = e.front();
		var next = e.iterator().next();
		while (p != null) {
			if (w == 0) {
				// if we're currently at zero, we need to record the edge start point
				x0 = p.x;
				w += p.valid;
			} else {
				var x1 = p.x;
				w += p.valid;

				// if we went to zero, we need to draw
				if (w == 0) {
					var i = (x0 >> tt_FIXSHIFT);
					var j = (x1 >> tt_FIXSHIFT);

					if (i < length && j >= 0) {
						if (i == j) {
							// x0, x1 are the same pixel, so compute combined coverage
							var u:U8 = (x1 - x0) * maxWeight >> tt_FIXSHIFT;
							scanline.set(i, scanline.get(i) + u);
						} else {
							if (i >= 0) { // add antialiasing for x0
								scanline.set(i, scanline.get(i) + ((tt_FIX - (x0 & tt_FIXMASK)) * maxWeight) >> tt_FIXSHIFT);
							} else {
								i = -1; // clip
							}
							if (j < length) { // add antialiasing for x1
								scanline.set(j, scanline.get(j) + ((x1 & tt_FIXMASK) * maxWeight) >> tt_FIXSHIFT);
							} else {
								j = -1; // clip
							}

							while (i < j) {
								i++;
								scanline.set(i, scanline.get(i) + maxWeight);
								j++;
							}
						}
					}
				}
			}
			p = next;
		}

		return scanline;
	}

	public static function closeShape(vertices:ArrayList<Vertex>, numVertices:Int, wasOff:Bool, startOff:Bool, sx:Int, sy:Int, scx:Int, scy:Int, cx:Int, cy:Int) {
		if (startOff) {
			if (wasOff) {
				vertices.set(numVertices, {
					type: vcurve,
					x: (cx + scx) >> 1,
					y: (cy + scy) >> 1,
					cx: cx,
					cy: cy
				});
				numVertices++;
			}
			vertices.set(numVertices, {
				type: vcurve,
				x: sx,
				y: sy,
				cx: scx,
				cy: scy
			});
			numVertices++;
		} else {
			if (wasOff) {
				vertices.set(numVertices, {
					type : vcurve,
					x: sx,
					y: sy,
					cx: cx,
					cy: cy
				});
				numVertices++;
			} else {
				vertices.set(numVertices, {
					type: vline,
					x: sx,
					y: sy,
					cx: 0,
					cy: 0
				});
				numVertices++;
			}
		}
		return numVertices;
	}
}
