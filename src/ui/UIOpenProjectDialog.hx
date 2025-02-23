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
import sys.FileSystem;
import haxe.ui.core.Platform;
import haxe.ui.events.MouseEvent;
import haxe.Json;
import haxe.io.Path;
import haxe.ui.containers.dialogs.Dialog;
import storage.Project;

@:build(haxe.ui.ComponentBuilder.build("res/ui/open_project_dialog.xml"))
class UIOpenProjectDialog extends Dialog{
    public var onGotProject:Path->Project->Void;
    public function new(){
        super();
        this.show();
    }

    @:bind(create_new, MouseEvent.CLICK)
    private function newProject(e){
        var project = new Project();
        var callback = (button, success, path)->{
            if(path == null){
                trace("No path!");
                path = "";
            }
            if(success){
                trace('saved to ${path}.');
                onGotProject(new Path(path), project);
                project.save;
                //project.setupReservedTypes();
            }
            else{
                trace('User canceled.');
            }
        };        
        if(Sys.systemName()=="Windows"){
            var sfd = new haxe.ui.containers.dialogs.SaveFileDialog({extensions:[{extension:Consts.FILENAME_PROJECT, label:"Project File"}], title:"Create Project"});
            sfd.fileInfo = {text:Json.stringify(project.serialize()), name:"proj.project.json"};
            sfd.callback = callback;
            sfd.show();
        }
        else{
            var inpt = new UITextInputModal("New Project Folder Path", (success, path) -> {
                FileSystem.createDirectory(path);
                callback(DialogButton.OK, success, path+"/proj.project.json");
            });
            inpt.show();
        }
    }

    @:bind(open_existing, MouseEvent.CLICK)
    private function openProject(e){
        trace(Sys.systemName());
        var options = {readContents:true, title:"Open Existing Project", extensions:[{extension:Consts.FILENAME_PROJECT, label:"Project File"}]};
        var callback = (bn, fi)->{
            if(fi.length<1) {
                trace('User canceled.');
                return; //TODO: Handle user clicked cancel->length is null case
            }
            var file = fi[0];
            var project = new Project();
            project.loadFromSerialized(haxe.Json.parse(file.text));
            onGotProject(new Path(file.fullPath), project);
        }
        if(Sys.systemName()=="Windows"){
            var ofd = new haxe.ui.containers.dialogs.OpenFileDialog();
            ofd.options = options;
            ofd.callback = callback;
            ofd.show();
        }
        else{
            var ofd = new UIFilePickerDialog();
            ofd.options = options;
            ofd.callback = callback;
            ofd.show();
        }
    }
}