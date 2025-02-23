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
import haxe.ui.containers.dialogs.Dialog;
import thinglib.component.Entity;
import storage.Project;
using Lambda;

@:xml('
    <dialog width="300" id="firstconstruct" title="Create First Construct">
        <vbox width="100%">
            <textfield width="70%" id="newconstruct_txt" placeholder="Construct Name"/>  
            <button id="newconstruct_btn" text="Create Construct"/>
        </vbox>
    </dialog>
')
class UICreateConstructDialog extends Dialog{
    public var onGotConstruct:Entity->Void;
    var project:Project;
    public function new(project:Project){
        super();
        this.project = project;
        this.newconstruct_txt.restrictChars="a-zA-Z0-9_";
        this.show();
    }

    
    @:bind(newconstruct_btn, MouseEvent.CLICK)
    function onNewconstructBtnClicked(e){
        if(onGotConstruct==null){
            trace("Missing handler.");
            return;
        }
        //var ret = new Construct(newconstruct_txt.text, null, null, project.getDefaultProps(CONSTRUCT));
        var ret = new Entity(project.root, newconstruct_txt.text);
        project.storage.save(ret.filename, ret);
        project.setOpenConstruct(ret);
        onGotConstruct(ret);
    }
}