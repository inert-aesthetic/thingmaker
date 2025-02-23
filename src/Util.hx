/*
thingmaker - an app for making things with thinglib
Copyright (C) 2025 inert-aesthetic contact_i_a at tuta dot io

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program.  If not, see <http://www.gnu.org/licenses/>.
*/
package;

import storage.Project;
import thinglib.component.Entity;
import hxd.fs.Convert;
import sys.FileSystem;
using thinglib.component.util.EntityTools;
using Lambda;

class Util{
    public static function fileName(name:String, extension:String, dir:String=""):String{
        return dir+(dir==""?"":"\\")+name+"."+extension;
    }

    public static function getAllOfTypeInDirectory(typename:String, directory:String):Array<String>{
        var ret = [];
        typename = short(typename);
        var allfiles = FileSystem.readDirectory(directory);
        for(f in allfiles){
            var exp = f.split(".");
            if(exp.length>=3&&exp[exp.length-2]==typename){
                ret.push(f);
            }
        }
        return ret;
    }

    public static function short(filename:String):String{
        return filename.substr(0, filename.lastIndexOf("."));
    }

    public static function convertEntityToPrefab(entity:Entity, construct:Entity, project:Project){
        var res = thinglib.Util.convertEntityToPrefabAndReplaceWithInstance(entity, construct.reference.getRoot(), project.storage, (removed:Entity)->Comms.send(ENTITY_REMOVED([entity]), {msg:"Prefabify"}));
        if(res.success){
            Comms.toast(Success, 'Prefab saved as ${entity.filename}.', 'Prefab Created');
            Comms.send(REQUEST_ENUMERATE_CONSTRUCTS, {msg:"Prefabify"});
            Comms.send(ENTITY_ADDED([res.instance]), {msg:"Prefabify"});
        }
        else{
            Comms.toast(Error, 'Failed to save prefab.', 'Prefab Not Created');
        }
    }
}

@:keep @:keepSub
class ConvertSVGtoPNG extends Convert {
	override function convert() {
		var size = hasParam("size") ? getParam("size") : 128;
		switch(Sys.systemName()){
			case "Windows":
				command("msdfgen.exe", ["-svg", srcPath, "-size", '$size', '$size', "-autoframe", "-o", dstPath]);
			case "Linux":
				command("inkscape", [srcPath, "-o", dstPath]);
			default:
				throw("No SVG to PNG converter specified.");
		}
	}

	static var _ = Convert.register(new ConvertSVGtoPNG("svg", "png"));
}