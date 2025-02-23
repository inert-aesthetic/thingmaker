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
package storage;

import sys.FileSystem;
import haxe.io.Path;
import sys.io.File;
import haxe.Json;

class GlobalPrefs{
    public var lastOpenProject:Path;
    public var name:String;
    public var extension:String;

    public function new(lastOpenProject:Path = null){
        name = "global";
        extension = Consts.FILENAME_GLOBAL_PREFS;
        this.lastOpenProject = lastOpenProject==null?new Path(""):lastOpenProject;
    }

    public function serialize():SerializedGlobalPrefs{
        return {lastOpenProject:lastOpenProject.toString()};
    }

    public function loadFromSerialized(data:Dynamic):Void{
        var d:SerializedGlobalPrefs = data;
        this.lastOpenProject = new Path(d.lastOpenProject);
    }

    public function save():Void{
        File.saveContent(name+"."+extension, Json.stringify(serialize()));
    }

    /**
     * Tries to load the last project open into the Project singleton
     * @return Bool
     */
    public function tryGetLastOpenProject():Project{
        if(lastOpenProject.toString()!="" && FileSystem.exists(lastOpenProject.toString())){
            var proj = new Project();
            proj.loadFromSerialized(Json.parse(File.getContent(lastOpenProject.toString())));
            proj.setWorkingDirectory(lastOpenProject);
            return proj;
        }
        return null;
    }
}

typedef SerializedGlobalPrefs = {lastOpenProject:String};