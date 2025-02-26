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

import thinglib.property.core.CoreComponents.CoreComponent;
import thinglib.component.Entity;
import thinglib.component.Accessors.Node;
import haxe.ui.events.MouseEvent;
import thinglib.component.Accessors.Edge;
import thinglib.property.Property;
import pasta.Vect;
import haxe.ui.containers.HBox;
import haxe.ui.events.UIEvent;
using thinglib.component.util.EntityTools;

@:build(haxe.ui.ComponentBuilder.build("res/ui/edge_control.xml"))
class UIEdgeControl extends HBox{
    var prop:Property;
    var edge:Edge;
    public function new(target:Property){
        super();
        if(target.definition.maxValInt()!=2){
            trace('Error: Edge control should be for max==2 REFS, not $target.');
        }
        switch target.value {
            default: trace('Error: Tried to load Edge prop controller for $target.');
            case REFS(v): 

        }
        this.prop=target;
        var ent:Entity = prop.reference.parent.resolve();
        this.edge = ent.asEdge();
        setup();
        Comms.subscribe(PROPERTY_VALUE_CHANGED(null, null), (c, p)->{
            switch c {
                default:
                case PROPERTY_VALUE_CHANGED(property, owners):
                    if(property.guid == CoreComponent.EDGE && owners.contains(edge)){
                        setup();
                    }
            }
        }, this);
    }

    override function onDestroy(){
        Comms.cleanupSubscriber(this);
        super.onDestroy();
    }

    function setup(){
        this.a_btn.text = (edge.a:Entity)?.name??"[Empty]";
        this.b_btn.text = (edge.b:Entity)?.name??"[Empty]";
    }

    @:bind(this.swap_btn, MouseEvent.CLICK)
    function onSwapButtonClick(e){
        var ob = edge.b;
        edge.b = edge.a;
        edge.a = ob;
        Comms.send(PROPERTY_VALUE_CHANGED(prop.definition, [edge]), this);
    }

    @:bind(this.a_btn, MouseEvent.CLICK)
    function onABtnClick(e){
        new UIComponentSelectModal('Select Node for A', (result, selection)->{
            if(!result) return;
            if(edge.b==selection){
                Comms.toast(Error, 'Could not select ${selection.name}. Already in use as "b" on ${(edge:Entity).name}.', 'Unable to Select');
                return;
            }
            edge.a = selection;
            Comms.send(PROPERTY_VALUE_CHANGED(prop.definition, [edge]), this);
        }, edge.a??null, [NODE] ).show();
    }

    @:bind(this.b_btn, MouseEvent.CLICK)
    function onBBtnClick(e){
        new UIComponentSelectModal('Select Node for B', (result, selection)->{
            if(!result) return;
            if(edge.a==selection){
                Comms.toast(Error, 'Could not select ${selection.name}. Already in use as "a" on ${(edge:Entity).name}.', 'Unable to Select');
                return;
            }
            edge.b = selection;
            Comms.send(PROPERTY_VALUE_CHANGED(prop.definition, [edge]), this);
        }, edge.b??null, [NODE] ).show();
    }
}