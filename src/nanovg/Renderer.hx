package nanovg;

import haxe.io.Bytes;

interface IRenderer {
	public function createTexture(type:TextureType, width:Int, height:Int, imageFlags:ImageFlags, data:Bytes):Dynamic;
	public function deleteTexture(texture:Dynamic):Dynamic;
	public function updateTexture(texture:Dynamic, x:Int, y:Int, w:Int, h:Int, data:Bytes):Dynamic;
	public function getTextureSize(texture:Dynamic):Size;
	public function viewport(width:Float, height:Float, devicePixelRatio:Float):Void;
	public function cancel():Void;
	public function flush():Void;

	public function fill(paint:Paint, compositeOperation:CompositeOperationState, scissor:Scissor, fringe:Float, bounds:Array<Float>, paths:Array<Path>):Void;

	public function stroke(paint:Paint, compositeOperation:CompositeOperationState, scissor:Scissor, fringe:Float, strokeWidth:Float, paths:Array<Path>):Void;

	public function triangles(paint:Paint, compositeOperation:CompositeOperationState, scissor:Scissor, verts:Array<Vertex>, fringe:Float):Void;

	public function delete():Void;
}

class Renderer implements IRenderer {
	public var edgeAntiAlias:Int;

	public function new() {}

	public function createTexture(type:Int, width:Int, height:Int, imageFlags:ImageFlags, data:Bytes):Dynamic
		return null;

	public function deleteTexture(texture:Dynamic):Dynamic
		return null;

	public function updateTexture(texture:Dynamic, x:Int, y:Int, w:Int, h:Int, data:Bytes):Dynamic
		return null;

	public function getTextureSize(texture:Dynamic):Size
		return null;

	public function viewport(width:Float, height:Float, devicePixelRatio:Float):Void
		return;

	public function cancel():Void
		return;

	public function flush():Void
		return;

	public function fill(paint:Paint, compositeOperation:CompositeOperationState, scissor:Scissor, fringe:Float, bounds:Array<Float>, paths:Array<Path>):Void
		return;

	public function stroke(paint:Paint, compositeOperation:CompositeOperationState, scissor:Scissor, fringe:Float, strokeWidth:Float, paths:Array<Path>):Void
		return;

	public function triangles(paint:Paint, compositeOperation:CompositeOperationState, scissor:Scissor, verts:Array<Vertex>, fringe:Float):Void
		return;

	public function delete():Void
		return;
}
