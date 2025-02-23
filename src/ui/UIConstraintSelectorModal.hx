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
import haxe.ui.events.MouseEvent;
import thinglib.property.Component;
import haxe.ui.data.ArrayDataSource;
import thinglib.component.Entity;
import haxe.ui.containers.dialogs.Dialog;
import thinglib.property.core.CoreComponents.CoreComponent;
using Lambda;

@:xml('
<dialog width="300" title="Select Children Constraint">
    <label text="Constrain to prefab"/>
    <dropdown width="100%" id="entities_drp" searchable="true" searchPrompt="Prefab name..."/>
    <label text="Constrain to component"/>
    <dropdown width="100%" id="components_drp" searchable="true" searchPrompt="Component name..."/>
    <button id="reset_btn" text="Reset"/>
</dialog>
')
class UIConstraintSelectorModal extends Dialog{
    var target:Entity;
    override public function new(target:Entity, entities:Array<Entity>, components:Array<Component>){
        super();
        this.buttons = DialogButton.APPLY|DialogButton.CANCEL;
        this.target=target;
        var eds:ArrayDataSource<{text:String, value:Entity}> = new ArrayDataSource();
        eds.add({text:"No Constraint", value:null});
        entities=entities.filter(c->!c.isEqualTo(target));
        entities.iter(c->eds.add({text:c.name, value:c}));
        entities_drp.dataSource = eds;
        
        var cds:ArrayDataSource<{text:String, value:Component}> = new ArrayDataSource();
        cds.add({text:"No Constraint", value:null});
        components.iter(c->cds.add({text:c.name, value:c}));
        components_drp.dataSource = cds;
        
        if(target.children_base_entity!=null){
            entities_drp.selectedItem={text:target.children_base_entity.name, value:target.children_base_entity};
            components_drp.disabled=true;
        }
        else if(target.children_base_component!=null){
            components_drp.selectedItem={text:target.children_base_component.name, value:target.children_base_component};
            entities_drp.disabled=true;
        }

        entities_drp.onChange = e->{
            var val:{text:String, value:Entity} = entities_drp.selectedItem;
            if(val?.value==null){
                components_drp.disabled=false;
            }
            else{
                components_drp.disabled=true;
            }
        }

        components_drp.onChange = e->{
            var val:{text:String, value:Component} = components_drp.selectedItem;
            if(val?.value==null){
                entities_drp.disabled=false;
            }
            else{
                entities_drp.disabled=true;
            }
        }
        //TODO Prevent adding incompatible base types or components
        onDialogClosed = function(e:DialogEvent) {
            switch e.button {
                case DialogButton.APPLY:
                    var selected_entity:Entity = entities_drp.selectedItem?.value;
                    var selected_component:Component = components_drp.selectedItem?.value;
                    target.children_base_component=null;
                    target.children_base_entity=null;
                    if(selected_entity!=null){
                        target.children_base_entity=selected_entity;
                    }
                    else if(selected_component!=null){
                        target.children_base_component=selected_component;
                        for(c in target.children){
                            c.addComponent(selected_component);
                        }
                    }
                case DialogButton.CANCEL:
                default:
            }
        }
        reset_btn.onClick = e->{
            entities_drp.selectedItem=target.children_base_entity==null?
                {text:"No constraint", value:null}
            :
                {text:target.children_base_entity.name, value:target.children_base_entity};

            components_drp.selectedItem=target.children_base_component==null?
                {text:"No constraint", value:null}
            :
                {text:target.children_base_component.name, value:target.children_base_component};
        }
    }
}