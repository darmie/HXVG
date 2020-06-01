package nanovg;

import haxe.io.Bytes;


/**
 * Images
 * 
 * NanoVG allows you to load jpg, png, psd, tga, pic and gif files to be used for rendering.
 * In addition you can upload your own image. The image loading is provided by stb_image.
 * The parameter imageFlags is combination of flags defined in ImageFlags.
 */
class Image {

    var context:Context;

    /**
     * Creates image by loading it from the disk from specified file name.
     * @param ctx 
     * @param fileName 
     * @param imageFlags 
     */
    public function new(ctx:Context, fileName:String, imageFlags:ImageFlags) {
        context = ctx;
    }

    /**
     * Creates image by loading it from the specified chunk of memory.
     * @param data 
     * @param imageFlags 
     */
    public static function createImageMem(data:Bytes, imageFlags:ImageFlags):Image {
        return null;
    }

    /**
     * Creates image from specified image data.
     * @param w 
     * @param h 
     * @param imageFlags 
     * @param data 
     */
    public static function createImageRGBA(w:Int, h:Int, imageFlags:ImageFlags, data:Bytes) {
        
    }


    /**
     * Updates image data specified by image handle.
     * @param data 
     */
    public function update(data:Bytes) {
        
    }

    /**
     * Returns the dimensions of a created image.
     * @return Size
     */
    public function size():Size {
        return null;
    }

    /**
     * Deletes created image.
     */
    public function delete() {
        
    }
}