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

import haxe.ui.data.ArrayDataSource;
import thinglib.component.Entity;
import haxe.ui.containers.dialogs.Dialog;
import thinglib.property.core.CoreComponents.CoreComponent;
using Lambda;

@:xml('
<dialog width="300" height="200">
    <dropdown width="100%" id="content_drp" searchable="true" searchPrompt="Node name..."/>
</dialog>
')
class UIComponentSelectModal extends Dialog{
    public var callback:(Bool, Entity)->Void;
    public function new(title:String, callback:(Bool, Entity)->Void, ?prefill:Entity, ?include_only:Array<CoreComponent>) {
        super();
        this.callback = callback;
        this.title = title;
        this.buttons = DialogButton.OK|DialogButton.CANCEL;

        Comms.subscribe(PROVIDE_ENTITIES_LIST(null, null), (c, p)->{
            switch c {
                default:
                case PROVIDE_ENTITIES_LIST(components, for_caller):
                    if(for_caller!=this) return;
                    var ds = new ArrayDataSource();
                    if(include_only!=null){
                        components=components.filter(c->include_only.contains(c.getBaseComponent()?.guid??""));
                    }
                    components.iter(c->ds.add({text:c.name, value:c}));
                    content_drp.dataSource = ds;
            }
        }, this);

        Comms.send(REQUEST_ENTITIES_LIST, this);

        onDialogClosed = function(e:DialogEvent) {
            switch e.button {
                case DialogButton.OK:
                    callback(true, content_drp.selectedItem.value);
                case DialogButton.CANCEL:
                    callback(false, null);
                default:
            }
        }
    }
}