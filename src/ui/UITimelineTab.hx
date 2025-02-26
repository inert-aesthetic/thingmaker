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

import thinglib.component.Entity;
import thinglib.property.core.CoreComponents.CoreComponent;
import thinglib.timeline.Timeline;
import haxe.ui.containers.VBox;
import haxe.ui.containers.Box;
using ArrayUtil;
@:xml('
<box text="Timeline" width="100%" height="100%">
    
</box>
')
class UITimelineTab extends Box{
    var selected_entities:Array<Entity> = [];
    public function new(){
        super();
        Comms.subscribe(SELECTED_ENTITIES_CHANGED(null), (c, p)->{
            switch c {
                case SELECTED_ENTITIES_CHANGED(entities):
                    if(entities.equalsUnsorted(selected_entities)){
                        return;
                    }
                    selected_entities=entities;
                    this.removeAllComponents();
                    if(entities?.length==0){
                        addComponent(new UITimelineUnavailable("No entity selected.", false));
                    }
                    else if(entities.length>1){
                        addComponent(new UITimelineUnavailable("Multiple entities selected.", false));
                    }
                    else{ //exactly one entity selected
                        var entity = entities[0];
                        if(entity.timeline==null){
                            addComponent(new UITimelineUnavailable("Entity has no timeline.", true, ()->{
                                entity.timeline = Timeline.Create(entity);
                                entity.addComponent(entity.reference.getRoot().unsafeGet(CoreComponent.TIMELINE_CONTROL));
                                selected_entities=[];
                                Comms.send(REQUEST_SELECT_ENTITIES([entity]), this);
                            }));
                        }
                        else{
                            if(entity.hasComponentByGUID(CoreComponent.TIMELINE_CONTROL)){
                                if(entity.timeline.owner!=entity.guid){
                                    //TODO replace with 'read only' timeline mode, where you can play/pause etc but not edit frames
                                    addComponent(new UITimelineUnavailable("Selected entity's timeline is inherited from prefab.", true, ()->{
                                    entity.timeline = Timeline.Create(entity);
                                    selected_entities=[];
                                    Comms.send(REQUEST_SELECT_ENTITIES([entity]), this);
                                }));
                                }
                                else{
                                    //Finally we are here with editable timeline
                                    addComponent(new UITimelineEditor(entity.timeline, entity));
                                }
                            }
                            else{
                                addComponent(new UITimelineUnavailable("Entity has no timeline controller component.", true, ()->{
                                    entity.addComponent(entity.reference.getRoot().unsafeGet(CoreComponent.TIMELINE_CONTROL));
                                    selected_entities=[];
                                    Comms.send(REQUEST_SELECT_ENTITIES([entity]), this);
                                }));
                            }
                        }
                    }
                default:
            }
        }, this);
    }

    override public function onDestroy(){
        Comms.cleanupSubscriber(this);
        super.onDestroy();
    }
}

@:xml('
<vbox width="100%" height="100%">
    <label id="reason_txt" text="Timeline Unavailable"/>
    <button id="create_btn" text="Create" />
</vbox>
')
class UITimelineUnavailable extends VBox{
    public function new(reason:String, showButton:Bool, ?createButtonCallback:()->Void){
        super();
        reason_txt.text=reason;
        if(showButton){
            create_btn.visible=true;
            if(createButtonCallback!=null){
                create_btn.onClick=e->createButtonCallback();
            }
        }
        else{
            create_btn.visible=false;
        }
    }
}