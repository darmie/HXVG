/// This is based on implementation at https://github.com/shibukawa/nanovgo/blob/master/fontstashmini/truetype/baking.go

package truetype;

import haxe.io.Bytes;



typedef BakedChar = {
    // coordinates of bbox in bitmap
    ?x0:Int, 
    ?y0:Int, 
    ?x1:Int, 
    ?y1:Int,


    ?xoff:Float, 
    ?yoff:Float, 
    ?xadvance:Float
}

typedef AlignedQuad = {
    // top-left
    ?X0:Float, ?Y0:Float, ?S0:Float, ?T0:Float, 

    // bottom-right
    ?X1:Float, ?Y1:Float, ?S1:Float, ?T1:Float
}

class Baking {
    /**
     * Call getBakedQuad with charIndex = 'character - firstChar', and it creates
     * the quad you need to draw and advances the current position.
     * 
     * The coordinate system used assumes y increases downwards.
     * 
     * Characters will extend both above and below the current position.
     * @param charData 
     * @param pw 
     * @param ph 
     * @param charIndex 
     * @param xpos 
     * @param ypos 
     * @param openglFillRule 
     */
    public static function getBakedQuad(charData:Array<BakedChar>, pw:Int, ph:Int, charIndex:Int, xpos:Float, ypos:Float, ?openglFillRule:Bool):{pos:Float, alignedQuad:AlignedQuad} {
        return null;
    }


    /**
     * offset is the font location (use offset=0 for plain .ttf), pixelHeight is the height of font in pixels. pixels is the bitmap to be filled in characters to bake. This uses a very crappy packing.
     * @param data 
     * @param offset 
     * @param pixelHeight 
     * @param pixels 
     * @param pw 
     * @param ph 
     * @param firstChar 
     * @param numChars 
     */
    public static  function bakeFontBitmap(data:Bytes, offset:Int, pixelHeight:Float, pixels:Bytes, pw:Int, ph:Int, firstChar:Int, numChars:Int) {
        
    }
}