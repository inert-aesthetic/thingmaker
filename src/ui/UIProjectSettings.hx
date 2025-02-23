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

import haxe.ui.events.UIEvent;
import thinglib.property.PropertyDef;
import haxe.ui.events.MouseEvent;
import haxe.ui.components.DropDown;
import haxe.ui.data.ArrayDataSource;
import haxe.ui.containers.properties.Property;
import haxe.ui.util.Properties;
import haxe.ui.containers.properties.PropertyGroup;
import storage.Project;
import haxe.ui.containers.windows.Window;
using Lambda;

@:build(haxe.ui.ComponentBuilder.build("res/ui/project_settings.xml"))
class UIProjectSettings extends Window{
    var project:Project;
    var property_group:PropertyGroup;

    public function new(project:Project){
        super();
        this.project = project;
        populate();
        Comms.subscribe(COMPONENTS_CHANGED(null), (c, p)->{
            switch c {
                case COMPONENTS_CHANGED(project):
                    this.project = project;
                    populate();
                default:
            }
        }, this);
    }

    override function onDestroy(){
        Comms.cleanupSubscriber(this);
        super.onDestroy();
    }


    function populate():Void{
        var ds = new ArrayDataSource();
        project.propertyDefs.iter(def->ds.add(def.name));
        

        if(property_group!=null){
            property_group.remove();
        }
        property_group = new PropertyGroup();
        this.magic_props_grd.addComponent(property_group);
        MagicPropType.constructAll().iter(t->{
            var prop = new Property();
            prop.label = t;
            //var drop = new DropDown();
            prop.type = "list";
            var filtered = new ArrayDataSource();
            var added = false;
            filtered.add({text:"None Specified", value:null});
            project.propertyDefs.iter(pd->{
                if(MagicPropType.validTypesFor(t).contains(pd.type)){
                    filtered.add({text:pd.name, value:pd});
                    added = true;
                }
                // var def:PropertyDef = project.propertyDefs[i];
                // return MagicPropType.validTypesFor(t).contains(def.type);
            });
            if(!added){
                filtered.clear();
                filtered.add({text:"No valid property types...", value:null});
            }
            //drop.dataSource = filtered;
            //prop.addComponent(drop);
            //drop.text = filtered.size==0?"No Valid Properties":"Select Property";
            prop.dataSource = filtered;
            
            //prop.disabled = filtered.size==0;
            if(project.magicProps.exists(t)){
                var current:PropertyDef = project.root.getThing(PROPERTYDEF, project.magicProps.get(t));
                //drop.selectedItem = {text:current.name, value:current.guid};
            }
            property_group.addComponent(prop);
            prop.registerEvent(UIEvent.READY, e->{
                var existing = project.magicProps.get(t);
                if(existing!=null){
                    var drop = e.target.findComponent(null, DropDown, true);
                    var ep = project.root.getThing(PROPERTYDEF, existing);
                    drop.selectedItem={text:ep.name, value:ep.guid};
                }
                prop.onChange = e->{
                    var drop = e.target.findComponent(null, DropDown, true);
                    if(drop==null){
                        trace("No drop on list prop...");
                        return;
                    }
                    var item = drop.selectedItem;
                    if(item==null||item.value==null||drop.selectedIndex==-1){
                        project.magicProps.remove(t);
                        project.save();
                        return;
                    }
                    project.magicProps.set(t, drop.selectedItem.value.guid);
                    project.save();
                }
            });
        });
    }
}