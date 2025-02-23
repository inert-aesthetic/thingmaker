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
import haxe.ui.events.MouseEvent;
import haxe.ui.containers.dialogs.Dialog;
import thinglib.component.*;
import haxe.ui.data.ArrayDataSource;
import storage.Project;
using Lambda;

@:build(haxe.ui.ComponentBuilder.build("res/ui/select_construct_dialog.xml"))
class UISelectConstructDialog extends Dialog{
    public var onGotConstruct:Entity->Void;
    var project:Project;
    public function new(project:Project){
        super();
        this.project = project;
        for(f in project.availableConstructs){
            constructs_list.dataSource.add({
                item: f.name,
                entity: f
            });
        }
        var ds = new ArrayDataSource();
        project.availableConstructs.iter(c->ds.add({text:c.name, value:c.guid}));
        template_drp.dataSource = ds;

        this.newconstruct_txt.restrictChars="a-zA-Z0-9_";
        this.show();
    }

    @:bind(constructs_list, UIEvent.CHANGE)
    function onSelectedConstructChanged(e){
        if(constructs_list.selectedItem!=null){
            confirm_btn.disabled = false;
        }
    }

    @:bind(newconstruct_btn, MouseEvent.CLICK)
    function onNewconstructBtnClicked(e){
        if(onGotConstruct==null){
            trace("Missing handler.");
            return;
        }
        var ret:Entity;
        if(template_drp.selectedIndex==-1){
            ret = new Entity(project.root, newconstruct_txt.text);
        }
        else{
            ret = Entity.CreateInstance(project.root, project.root.getThing(ENTITY, template_drp.selectedItem.value), null, newconstruct_txt.text);
        }
        project.storage.save(ret.filename, ret);
        project.setOpenConstruct(ret);
        onGotConstruct(ret);
    }

    @:bind(newconstruct_txt, UIEvent.CHANGE)
    function onNewconstructTxtChanged(e){
        var name = newconstruct_txt.text;
        newconstruct_btn.disabled = name=='';
    }

    @:bind(confirm_btn, MouseEvent.CLICK)
    function onConfirmClicked(e){
        if(onGotConstruct==null){
            trace("Missing handler for confirm button.");
            return;
        }
        onGotConstruct(constructs_list.selectedItem.entity);
    }

}