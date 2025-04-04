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
import thinglib.timeline.Timeline;
import thinglib.Util.ThingID;
import thinglib.storage.Storage;
import thinglib.ThingScape;
import haxe.io.Path;
import thinglib.component.*;
import thinglib.property.Component;
import thinglib.property.PropertyDef;
using Lambda;
using ArrayUtil;
import sys.FileSystem;
import sys.io.File;
import haxe.Json;

/** 
    Structure:
        availableConstructs and availableComponents -> stubs from enumration
        When changing project, destroy root, recreate ALL components and JUST selected 
**/

class Project{
    public var name:String;
    public var extension:String = Consts.FILENAME_PROJECT;
    public var lastOpenConstruct:String;
    public var savedConstructs:Array<String>;
    public var workingDirectory:Path;
    public var workspacePreferences:Map<String, WorkspacePreferences> = new Map();
    public var availableConstructs:Array<Entity>;
    public var magicProps:Map<MagicPropType, String> = new Map();
    public var root:ThingScape;
    public var storage:Storage;
    public var propertyDefs(get, null):Array<PropertyDef>;
    public var components(get, null):Array<Component>;
    public var lockedEntities:Map<ThingID, Bool> = new Map();
    public var hiddenEntities:Map<ThingID, Bool> = new Map();

    public function new(lastOpenConstruct:String = ""){
        name = "proj";
        extension = Consts.FILENAME_PROJECT;
        this.lastOpenConstruct = lastOpenConstruct;
        this.root = new ThingScape();
        //Here is where we would bootstrap any thingmaker-only components, like tether.
        
        this.storage = new Storage("");
        //Todo: Change requesting change project to go through here so we can remove the handler from the current project
    }

    public function save(){
        File.saveContent(workingDirectory.dir+"/"+name+"."+extension, Json.stringify(serialize(),null, "\t"));
    };

    public function enumerateConstructs(){
        availableConstructs = [];//Util.getAllOfTypeInDirectory(thinglib.Consts.FILENAME_CONSTRUCT, workingDirectory.dir);
        var filenames = Util.getAllOfTypeInDirectory(thinglib.Consts.FILENAME_CONSTRUCT, workingDirectory.dir);
        var last = Util.fileName(lastOpenConstruct, thinglib.Consts.FILENAME_CONSTRUCT);
        if(!filenames.contains(last)){
            trace('Last construct opened (${last}) is not in list: ${filenames.join(', ')}');
            lastOpenConstruct = "";
            save();
        }
        for(d in filenames){
            var stub = storage.loadMeta(d);
            if(root.hasThing(stub.guid)){
                availableConstructs.push(root.unsafeGet(stub.guid));
            }
            else{
                availableConstructs.push(storage.createFromFile(Entity, root, d));
            }
        }
        return availableConstructs;
    }

    public function enumerateComponents(){
        var names = Util.getAllOfTypeInDirectory(thinglib.Consts.FILENAME_COMPONENT, workingDirectory.dir);
        for(n in names){
            var stub = storage.loadMeta(n);
            if(!root.hasThing(stub.guid)){
                storage.createFromFile(Component, root, n);
            }
        }
    }

    public function enumerateTimelines(){
        var names = Util.getAllOfTypeInDirectory(thinglib.Consts.FILENAME_TIMELINE, workingDirectory.dir);
        for(n in names){
            var stub = storage.loadMeta(n);
            if(!root.hasThing(stub.guid)){
                storage.createFromFile(Timeline, root, n);
            }
        }
    }

    public function isHidden(entity:Entity):Bool{
        return hiddenEntities.exists(entity.guid)||(entity.parent!=null&&isHidden(entity.parent));
    }

    public function setHidden(entity:Entity, to:Bool){
        if(to){
            hiddenEntities.set(entity.guid, true);
        }
        else{
            hiddenEntities.remove(entity.guid);
        }
    }

    public function isLocked(entity:Entity):Bool{
        return lockedEntities.exists(entity.guid)||(entity.parent!=null&&isLocked(entity.parent));
    }

    public function setLocked(entity:Entity, to:Bool){
        if(to){
            lockedEntities.set(entity.guid, true);
        }
        else{
            lockedEntities.remove(entity.guid);
        }
    }

    public function toggleLocked(entity:Entity){
        setLocked(entity, !isLocked(entity));
    }

    public function toggleHidden(entity:Entity){
        setHidden(entity, !isHidden(entity));
    }

    function get_propertyDefs(){
        return root.getAll(PropertyDef);
    }

    function get_components(){
        return root.getAll(Component);
    }


    // public function setupReservedTypes(){
    //     var reserved_list = new PropertyDefList("internal");
    //     //t-junction component
    //     var t_junction = new ChildDef();
    //     t_junction.name=Consts.JUNCTION_DEF;
    //     var balanceprop = new PropertyDef(Consts.JUNCTION_BALANCE, FLOAT);
    //     balanceprop.default_value = FLOAT(0.5);
    //     balanceprop.minimum_value = FLOAT(0);
    //     balanceprop.maximum_value = FLOAT(1);
    //     balanceprop.step_size = FLOAT(0.05);
    //     reserved_list.properties.push(balanceprop);
    //     var slideprop = new PropertyDef("junction_friction", FLOAT);
    //     slideprop.default_value = FLOAT(0.5);
    //     slideprop.minimum_value = FLOAT(0);
    //     slideprop.maximum_value = FLOAT(1);
    //     slideprop.step_size = FLOAT(0.05);
    //     reserved_list.properties.push(slideprop);
    //     var hostprop = new PropertyDef(Consts.JUNCTION_EDGE, EDGE);
    //     reserved_list.properties.push(hostprop);
    //     reserved_list.save();
    //     t_junction.property_definitions.push(balanceprop);
    //     t_junction.property_definitions.push(slideprop);
    //     t_junction.property_definitions.push(hostprop);
    //     t_junction.for_edges = false;
    //     t_junction.for_nodes = true;
    //     t_junction.save();
    // }

    public function serialize():SerializedProject{
        return  {
                    lastOpenConstruct:lastOpenConstruct,
                    workspacePreferences: workspacePreferences.array(), 
                    magicProps: magicProps,
                    hiddenEntities: [for (a in hiddenEntities.keys()) a],
                    lockedEntities: [for (a in lockedEntities.keys()) a],
                };
    }

    public function loadFromSerialized(data:Dynamic):Void{
        var d:SerializedProject = data;
        if(d.lastOpenConstruct!=null){
            this.lastOpenConstruct = d.lastOpenConstruct;
        }
        if(d.lastOpenConstruct!=null){
            this.lastOpenConstruct = d.lastOpenConstruct;
        }
        if(d.magicProps!=null){
            Reflect.fields(d.magicProps).iter(f->this.magicProps.set(f, Reflect.field(d.magicProps, f)));
        }
        if(d.workspacePreferences!=null){
            d.workspacePreferences.iter(w->workspacePreferences.set(w.constructName, w));
        }
        if(d.hiddenEntities!=null){
            for(e in d.hiddenEntities){
                hiddenEntities.set(e, true);
            }
        }
        if(d.lockedEntities!=null){
            for(e in d.lockedEntities){
                lockedEntities.set(e, true);
            }
        }
    }

    public function setWorkingDirectory(to:Path){
        this.workingDirectory = to;
        storage.working_directory = to;
    }

    public function getMagicProp(type:MagicPropType):String{
        if(magicProps.exists(type)){
            return magicProps.get(type);
        }
        return "";
    }

    public function setOpenConstruct(to:Entity){
        lastOpenConstruct = to.name;
        save();
    }
}

enum abstract MagicPropType(String) from String to String{
    var COLOR = "Color";
    var NAME = "Name";
    var RADIUS = "Radius";
    var THICKNESS = "Thickness";
    var ALPHA = "Alpha";
    public static function constructAll(){
        return [COLOR, NAME, RADIUS, THICKNESS, ALPHA];
    }
    public static function validTypesFor(prop:MagicPropType):Array<PropertyType>{
        switch prop {
            case COLOR:
                return [PropertyType.COLOR];
            case NAME:
                return [STRING];
            case RADIUS:
                return [INT, FLOAT];
            case THICKNESS:
                return [INT, FLOAT];
            case ALPHA:
                return [FLOAT];
        }
    }
}

typedef SerializedProject = {   
                                lastOpenConstruct:String, 
                                ?workspacePreferences:Array<WorkspacePreferences>,
                                magicProps:Dynamic,
                                ?hiddenEntities:Array<ThingID>,
                                ?lockedEntities:Array<ThingID>
                            };

typedef WorkspacePreferences = {
    constructName:String,
    zoom:Float,
    scroll_x:Float,
    scroll_y:Float,
    snap_grid:Bool,
    grid_size:Float,
    show_grid:Bool,
}