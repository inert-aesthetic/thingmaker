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
package ui;

import thinglib.component.Entity;
import thinglib.property.PropertyDef;
import haxe.ui.containers.properties.Property;
import haxe.ui.containers.properties.PropertyGroup;
import haxe.ui.containers.windows.Window;

using thinglib.component.util.PropertyValueTools;

using Lambda;

@:build(haxe.ui.ComponentBuilder.build("res/ui/multi_prop_editor.xml"))
class UIMultiPropEditor extends Window{
    var def:PropertyDef;
    var targets:Array<Entity>;
    var group:PropertyGroup;
    public function new (definition:PropertyDef, targets:Array<Entity>){
        super();
        this.def = definition;
        this.targets = targets;
        populate();
        Comms.subscribe(REQUEST_MULTI_EDIT_RELOAD, (_,_)->populate(), this);
    }

    override function onDestroy(){
        Comms.cleanupSubscriber(this);
        super.onDestroy();
    }

    function populate(){
        if(group!=null){
            this.checks_grd.removeComponent(group);
        }
        group = new PropertyGroup();
        if(def.options==null){
            this.error_txt.text = "No options set for this multi.";
            this.error_txt.hidden = false;
            return;
        }
        if(targets.length==0){
            this.error_txt.text = "No target objects selected.";
            this.error_txt.hidden = false;
        }

        for(o in def.options){
            var index = def.options.indexOf(o);
            var initial = targets[0].getValue(def).intArrayValue()?.contains(index)??false;
            var changed = false;
            var prop = new Property();
            prop.label = o;
            trace("Checking targets...");
            for(t in targets){
                trace(t.getValue(def).intArrayValue());
                if((t.getValue(def).intArrayValue()?.contains(index)??false)!=initial){
                    changed = true;
                    break;
                }
            }
            if(changed){
                prop.value = "Unify Values";
                prop.type = "action";
                prop.onChange = e->{
                    prop.value = "...";
                    setAll(index, initial);
                    Comms.sendDebounced(REQUEST_MULTI_EDIT_RELOAD, "MultiPropEditor", 300, this);
                }
            }
            else{
                prop.type = "boolean";
                prop.value = initial;
                prop.onChange = e->setAll(index, prop.value);
            }   
            group.addComponent(prop);
        }
        checks_grd.addComponent(group);
    }

    function setAll(index:Int, value:Bool){
        trace('Set $index to $value');
        for(t in targets){
            var p = t.getValue(def);
            trace('...for ${p} (${p.intArrayValue()})');
            var arr = p.intArrayValue();
            if(value){
                if(!arr.contains(index)){
                    trace("Setting true!");
                    arr.push(index);
                    t.setValue(def, MULTI(arr));
                }
            }
            else{
                trace("Setting false!");
                arr.remove(index);
                t.setValue(def, MULTI(arr));
            }
        }
    }
}