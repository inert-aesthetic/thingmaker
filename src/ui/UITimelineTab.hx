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

import ui.UITimelineEditor.UITimelineSelectionDrop;
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
        Comms.subscribe(TIMELINE_CHANGED(null, null), (c, p)->{
            switch c {
                default:
                case TIMELINE_CHANGED(entities, timeline):
                    if(entities.length==1&&selected_entities.length==1&&selected_entities[0].isEqualTo(entities[0])){
                        // this.pauseComponentValidation();
                        setup(selected_entities, true);
                        // this.resumeComponentValidation();
                    }
            }
        }, this);
        Comms.subscribe(SELECTED_ENTITIES_CHANGED(null), (c, p)->{
            switch c {
                case SELECTED_ENTITIES_CHANGED(entities):
                    setup(entities);
                default:
            }
        }, this);
    }

    function setup(entities:Array<Entity>, force_rebuild:Bool=false){
        if(!force_rebuild&&entities.equalsUnsorted(selected_entities)){
            return;
        }
        selected_entities=entities;
        // this.pauseComponentValidation();
        this.removeAllComponents();
        // this.resumeComponentValidation();
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
                    new UITextInputModal("Timeline Name", (res, name)->{
                        if(!res) return;
                        entity.timeline = Timeline.Create(entity, name);
                        entity.addComponent(entity.reference.getRoot().unsafeGet(CoreComponent.TIMELINE_CONTROL));
                        selected_entities=[];
                        Comms.send(REQUEST_SELECT_ENTITIES([entity]), this);
                    }).show();
                }));
                var drp = new UITimelineSelectionDrop();
                drp.target=entity;
                drp.updateAvailableTimelines();
                addComponent(drp);
            }
            else{
                if(entity.hasComponentByGUID(CoreComponent.TIMELINE_CONTROL)){
                    // this.pauseComponentValidation();
                    addComponent(new UITimelineEditor(entity.timeline, entity));
                    // this.resumeComponentValidation();
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
    }

    override public function onDestroy(){
        Comms.cleanupSubscriber(this);
        super.onDestroy();
    }
}

@:xml('
<vbox width="100%" height="100%">
    <label id="reason_txt" text="Timeline Unavailable"/>
    <button id="create_btn" text="Create New" />
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