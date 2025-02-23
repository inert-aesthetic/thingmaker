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

import haxe.io.Path;
import sys.io.File;
import haxe.ui.events.MouseEvent;
import haxe.ui.containers.dialogs.Dialogs.SelectedFileInfo;
import haxe.ui.backend.OpenFileDialogBase.OpenFileDialogOptions;
import haxe.ui.containers.dialogs.Dialog;


@:build(haxe.ui.ComponentBuilder.build("res/ui/file_picker_dialog.xml"))
class UIFilePickerDialog extends Dialog{
    public var options:OpenFileDialogOptions;
    public var callback:(DialogButton, Array<SelectedFileInfo>)->Void;
    public function new() {
        super();

    }

    // typedef FileInfo = {
    //     @:optional var name:String;
    //     @:optional var text:String;
    //     @:optional var bytes:Bytes;
    //     @:optional var isBinary:Bool;
    // }
    
    // typedef SelectedFileInfo = { > FileInfo,
    //     @:optional var fullPath:String;
    // }

    @:bind(btn_open, MouseEvent.CLICK)
    function onBtnOpen(e) {
        var filepath = txt_proj_path.text;
        var path = new Path(filepath);
        var file = File.getContent(filepath);
        callback(null, [{name:path.file, text:file, bytes:null, isBinary: false, fullPath: filepath}]);
    }
}