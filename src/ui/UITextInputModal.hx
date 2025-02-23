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
import haxe.ui.notifications.NotificationType;
import haxe.ui.notifications.NotificationManager;
import haxe.ui.containers.dialogs.Dialog;
using haxe.ui.animation.AnimationTools;


@:build(haxe.ui.ComponentBuilder.build("res/ui/text_input_modal.xml"))
class UITextInputModal extends Dialog{
    public var callback:(Bool, String)->Void;
    public function new(title:String, callback:(Bool, String)->Void, prefill:String="") {
        super();
        this.callback = callback;
        this.title = title;
        this.txt_content.text = prefill;
        this.buttons = DialogButton.OK|DialogButton.CANCEL;

        onDialogClosed = function(e:DialogEvent) {
            switch e.button {
                case DialogButton.OK:
                    callback(true, txt_content.text);
                case DialogButton.CANCEL:
                    callback(false, "");
                default:
            }
        }
    }

    public override function validateDialog(button:DialogButton, fn:Bool->Void) {
        var valid = true;
        if (button == DialogButton.OK) {
            if (txt_content.text == "" || txt_content.text == null) {
                txt_content.flash();
                valid = false;
            } 

            if (valid == false) {
                NotificationManager.instance.addNotification({
                    body: "Text field can't be empty.",
                    type: NotificationType.Error
                });
                this.shake();
            } 
        }
        fn(valid);
    }
}
/*
    @:bind(btn_okay, MouseEvent.CLICK)
    function onBtnOkay(e) {
        callback(true, txt_content.text);
    }

    @:bind(btn_cancel, MouseEvent.CLICK)
    function onBtnCancel(e){
        callback(false, "");
    }
    */