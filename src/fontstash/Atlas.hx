package fontstash;
import polygonal.ds.ArrayList;


typedef AtlasNode = {
	?x:I16,
	?y:I16,
	?width:I16
}

class Atlas  {
    public var width:Int;
	public var height:Int;
	public var nodes:ArrayList<AtlasNode>;
	public var nnodes:Int;
    public var cnodes:Int;
    

	public function new(width:I16, height:I16, nnodes:Int) {
        this.width = width;
        this.height = height;
        this.nnodes = nnodes;
		this.nodes = new ArrayList<AtlasNode>(this.nnodes != null ? this.nnodes : 1);
		this.nodes.get(0).x = 0;
		this.nodes.get(0).y = 0;
		this.nodes.get(0).width = this.width;
	}

	public function rectFits(i:Int, w:Int, h:Int):Int {
		var x = Std.int(this.nodes.get(i).x);
		var y = Std.int(this.nodes.get(i).y);
		if (x+w > this.width) {
			return -1;
		}
		var spaceLeft = w;
		while (spaceLeft > 0) {
			if (i == this.nodes.size) {
				return -1;
			}
			y = FONS.__maxi(y, Std.int(this.nodes.get(i).y));
			if (y+h > this.height) {
				return -1;
			}
			spaceLeft -= Std.int(this.nodes.get(i).width);
			i++;
		}
		return y;
	}

	public function addSkylineLevel(idx:Int, x:Int, y:Int, w:Int, h:Int){
        insertNode(idx, x, y+h, w);
        var atlas = this;
        var i = (idx+1);
        while(i  < nodes.size){
            if (atlas.nodes.get(i).x < atlas.nodes.get(i-1).x+atlas.nodes.get(i-1).width) {
                var shrink = atlas.nodes.get(i-1).x + atlas.nodes.get(i-1).width - atlas.nodes.get(i).x;
                atlas.nodes.get(i).x += shrink;
                atlas.nodes.get(i).width -= shrink;
                if (atlas.nodes.get(i).width <= 0) {
                    atlas.removeNode(i);
                    i--;
                } else {
                    break;
                }
            } else {
                break;
            }
            i++;
        }

        i = 0;
        while(i < (nodes.size - 1)){
            if (atlas.nodes.get(i).y == atlas.nodes.get(i+1).y) {
                atlas.nodes.get(i).width += atlas.nodes.get(i+1).width;
                atlas.removeNode(i + 1);
                i--;
            }

            i++;
        }

    }

    public function removeNode(idx:Int) {
        var atlas = this;
        if (atlas.nnodes == 0) return;
        for(i in idx...(atlas.nnodes -1)){
            atlas.nodes.set(i, atlas.nodes.get(i+1));
        }

        atlas.nnodes--;
    }
    
    public function insertNode(idx:Int, x:Int, y:Int, w:Int) {
        var node:AtlasNode = {
            x:     x,
            y:     y,
            width: w,
        };

        var i = nnodes;
        while(i > idx){
            nodes.set(i, nodes.get(i-1));
            i--;
        }
        nodes.get(idx).x = x;
        nodes.get(idx).y = y;
        nodes.get(idx).width = w;
        nnodes++;
    }

	public function addRect(rw:Int, rh:Int):{?bestX:Int, ?bestY:Int} {
        var atlas = this;
        var bestH = atlas.height;
        var bestW = atlas.width;
        var bestI = -1;
        var bestX = -1;
        var bestY = -1;

        for(i in 0...atlas.nodes.size){
            var node = atlas.nodes.get(i);
            var y = atlas.rectFits(i, rw, rh);
            if (y != -1) {
                if (y+rh < bestH || ((y+rh == bestH) && (node.width) < bestW)) {
                    bestI = i;
                    bestW = node.width;
                    bestH = y + rh;
                    bestX = node.x;
                    bestY = y;
                }
            }
        }
        if (bestI == -1) {
            trace("can't find space");
            return {};
        }
        // Perform the actual packing.
        atlas.addSkylineLevel(bestI, bestX, bestY, rw, rh);

		return {bestX:bestX, bestY:bestY};
	}

	public function reset(width:Int, height:Int) {
        var atlas = this;
        atlas.width = width;
        atlas.height = height;
        if (atlas.nodes.size != 1) {
            atlas.nodes = new ArrayList<AtlasNode>(atlas.nodes.size > 1 ? atlas.nodes.size : 1);
            atlas.nodes.get(0).x = 0;
            atlas.nodes.get(0).y = 0;
            atlas.nodes.get(0).width = width;
        }
    }
}

