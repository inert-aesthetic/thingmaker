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

import haxe.ui.components.Image;
import thinglib.component.Entity;
import storage.Project;
import haxe.ui.containers.VBox;
import haxe.ui.containers.HBox;
import haxe.ui.containers.Box;
import haxe.ui.containers.ScrollView;
import haxe.ui.events.MouseEvent;
using Lambda;

@:xml('
<hbox width="100%" height="100%">
<!--
    <vbox width="15%" height="100%">
    </vbox>
-->
    <scrollview contentWidth="100%" height="100%" width="100%" >
        <hbox id="asset_box" continuous="true" width="100%" style="padding:10px;">
        </hbox>
    </scrollview>
<!---
    <vbox width="5%" height="100%">
    </vbox>
-->
</hbox>
')
class UIAssetExplorer extends HBox{
    public function new(){
        super();
        Comms.subscribe(AVAILABLE_CONSTRUCTS_CHANGED(null, null), (c, p)->{
            switch c {
                default:
                case AVAILABLE_CONSTRUCTS_CHANGED(constructs, project):
                    if(constructs!=null&&project!=null){
                        buildView(constructs, project);
                    }
            }
        }, this);
    }

    function buildView(constructs:Array<Entity>, project:Project){
        asset_box.removeAllComponents();
        for(c in constructs){
            var item = new UIAssetExplorerItem(c);
            asset_box.addComponent(item);
        }
    }
}

@:xml('
<box>
    <style>
        .assetItem{
            margin: 5px;
            width: 100px;
            height: 100px;
            clip:true;
        }
        .assetItem image{
            filter: invert(1) tint($nord-light1, 1);
            margin: 5px;
            verticalAlign: center;
        }
        .assetItem:down{
            background-color:$nord-dark1;
        }

    </style>
    <button     
        id="btn" 
        toggle="true"
        styleName="assetItem" 
    >
        <item-renderer>
            <vbox width="100%">
                <box width="40" height="40" horizontalAlign="center">
                    <image id="icon_img" 
                        verticalAlign="bottom"
                        horizontalAlign="center"
                    />
                </box>
                <label width="100%" id="text"/> 
            </vbox>
        </item-renderer>
    </button>
</box>')
class UIAssetExplorerItem extends Box{

    public function new(item:Entity){
        super();
        btn.text = item.name;
        findComponent("icon_img", Image).resource = Icon.ForBaseType(item.getBaseComponent()?.guid??"");
        Comms.subscribe(STAMPS_CHANGED(null), (c, p)->{
            switch c {
                default:
                case STAMPS_CHANGED(prefabs):
                    var isstamp = prefabs.has(item);
                    btn.selected = isstamp;
            }
        }, this);
        Comms.subscribe(STAMP_SELECTION_REJECTED(null), (c, p)->{
            switch c {
                default:
                case STAMP_SELECTION_REJECTED(prefab):
                    if(prefab==item){
                        btn.selected=false;
                        Comms.toast(Warning, '${item.name} cannot be used as a prefab stamp.', 'Stamp not selected');
                    }
            }
        }, this);
        btn.onClick = (e:MouseEvent)->{
            Comms.send(REQUEST_STAMP_CHANGE(item, !btn.selected), this);
        };
    }

    override function onDestroy(){
        Comms.cleanupSubscriber(this);
        super.onDestroy();
    }
}