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

import thinglib.property.core.CoreComponents.CoreComponentTimelineControl;
import thinglib.component.Accessors.TimelineControlled;
import haxe.ui.containers.dialogs.MessageBox.MessageBoxType;
import haxe.ui.containers.dialogs.Dialogs;
import haxe.ui.containers.dialogs.Dialog;
import thinglib.property.core.CoreComponents.CoreComponent;
import thinglib.property.Property;
import thinglib.property.PropertyDef;
import thinglib.component.Entity;
import haxe.ui.events.UIEvent;
import haxe.ui.data.ArrayDataSource;
import h2d.TextInput;
import haxe.ui.events.MenuEvent;
import haxe.ui.core.Screen;
import haxe.ui.containers.menus.Menu;
import haxe.ui.events.MouseEvent;
import haxe.ui.containers.Box;
import haxe.ui.containers.HBox;
import haxe.ui.events.ScrollEvent;
import haxe.ui.containers.VBox;

import thinglib.timeline.Timeline;
using Lambda;
using StringTools;
using thinglib.component.util.EntityTools;

@:xml('
<vbox style="padding: 5px;" width="100%" height="100%">
    <style>
    .timeline-button image{
        filter: invert(1) tint($nord-light1, 1);
    }
    </style>
    <hbox id="timeline_control_bar" width="100%">
        <button id="add_state_btn" width="25" text="+"/>
        <button id="remove_state_btn" width="25" text="-"/>
        <dropdown id="states_drp" width="100px">
        </dropdown>
        <rule direction="vertical" height="100%" />
        <button id="to_start_btn" icon="${Icon.fast_backward_16}" width="25" styleName="timeline-button"/>
        <button id="to_prev_btn" icon="${Icon.step_backward_16}" width="25"  styleName="timeline-button"/>
        <button id="play_pause_btn" icon="${Icon.play_16}" width="25"  styleName="timeline-button"/>
        <button id="to_next_btn" icon="${Icon.step_forward_16}" width="25"  styleName="timeline-button"/>
        <button id="to_end_btn" icon="${Icon.fast_forward_16}" width="25"  styleName="timeline-button"/>
        <rule direction="vertical" height="100%" />
        <dropdown id="add_track_drp" width="100px"/>
        <button id="add_track_btn" tooltip="Add Track" icon="${Icon.add_row_bottom_16}" width="25"  styleName="timeline-button"/>
        <rule direction="vertical" height="100%" />
        <hbox>
            <image resource="${Icon.flows_16}" verticalAlign="center" tooltip="Interpolation" style="filter: invert(1) tint($nord-light1, 1)"/>
            <dropdown id="interpolation_drp" width="100px"/>
        </hbox>
        <rule direction="vertical" height="100%" />
        <hbox>
            <image resource="${Icon.flow_end_16}" verticalAlign="center" tooltip="On finish" style="filter: invert(1) tint($nord-light1, 1)"/>
            <dropdown id="on_end_drp" width="100px">
                <data>
                    <item text="Stop"/>
                    <item text="Loop"/>
                    <item text="Go to frame"/>
                    <item text="Go to state"/>
                </data>
            </dropdown>
            <number-stepper id="on_end_frame_stp" pos="0" step="1" min="0"/>
            <dropdown id="on_end_state_drp" width="100px"/>
        </hbox>
    </hbox>
    <grid id="mainGrid" width="100%" height="100%" style="spacing: 0px">
        <hbox width="200px">
            <hbox>
                <image resource="${Icon.search_16}" verticalAlign="center" style="filter: invert(1) tint($nord-light1, 1)"/>
                <dropdown id="zoom_drp">
                    <data>
                        <item text="1.00x" value="${TimelineZoom.ONE}"/>
                        <item text="0.10x" value="${TimelineZoom.TEN}"/>
                        <item text="0.01x" value="${TimelineZoom.HUNDRED}"/>
                    </data>
                </dropdown>
            </hbox>
            <rule direction="vertical" height="100%" />
            <hbox>
                <image resource="${Icon.film_16}" verticalAlign="center" style="filter: invert(1) tint($nord-light1, 1)"/>
                <number-stepper id="frames_stp" pos="30" step="1" min="1" width="90"/>
            </hbox>
        </hbox>
        <scrollview id="headerScroller" width="100%" styleNames="no-padding no-border" allowFocus="false" horizontalScrollPolicy="never">
            <hbox id="frameHolder" height="30" style="background-color: $nord-dark3; spacing:15px;padding-left:15px;">
            </hbox>
        </scrollview>
        <vbox width="200" height="100%" style="spacing:0">
        <scrollview id="tracksScroller" width="100%" height="100%" contentWidth="100%" styleNames="no-padding no-border" allowFocus="false" verticalScrollPolicy="never">
            <vbox id="trackLabelsHolder" style="spacing:0" width="100%">    
            </vbox>
        </scrollview>
        <spacer height="8px" /> <!-- account for scrollbar on content scroller -->
        </vbox>    
        <scrollview id="contentScroller" width="100%" height="100%" styleNames="no-padding no-border" allowFocus="false">
            <absolute>
                <vbox id="tracksHolder" style="spacing:0; top:0px; left:0px;">
                </vbox>
                <rule id="playhead" direction="vertical" height="100%" style="top:0px;"/>
            </absolute>
        </scrollview>
    </grid>
</vbox>
')
class UITimelineEditor extends VBox{
    public var frames(default, set):Int = 300;
    public var current_frame(default, set):Int;
    public var current_state(default, set):TimelineState;
    public var selected_frame(default, set):UITimelineKeyframe;
    var tracks:Array<UITimelineTrackCombo> = [];
    public var target:TimelineControlled;
    var is_playing:Bool=false;
    var frame_holder_mouse_down:Bool = false;
    var is_ready:Bool = false;

    public var zoom_factor:Float = 1;
    
    public var timeline:Timeline;

    public function new(timeline:Timeline, target:TimelineControlled){
        super();
        
        this.target=target;
        this.timeline=timeline;
    
    }

    override function onReady(){
        super.onReady();
        contentScroller.scrollMode = NORMAL; //prevent dragging keyframe from dragging scroll view
        headerScroller.scrollMode = NORMAL; //prevent dragging keyframe from dragging scroll view
        tracksScroller.scrollMode = NORMAL; //prevent dragging keyframe from dragging scroll view
        
        var interpolation_ds = new ArrayDataSource<InterpolationMethod>();
        InterpolationMethod.createAll().iter(t->{
            interpolation_ds.add(t);
        });
        interpolation_drp.dataSource = interpolation_ds;
        interpolation_drp.disabled=true;
        
        to_start_btn.onClick = _->current_frame=0;
        to_next_btn.onClick = _->current_frame++;
        play_pause_btn.onClick = _ ->{
            is_playing=!is_playing;
            //play_pause_btn.text=is_playing?"||":"|>";
            play_pause_btn.icon=is_playing?Icon.pause_16:Icon.play_16;
        } 
        to_prev_btn.onClick = _->current_frame--;
        to_end_btn.onClick = _->current_frame=frames;

        updateAvailableStates();
        selectState(target.current_state?.name);
        this.current_frame=(target.frame);

        Comms.subscribe(PROPERTY_VALUE_CHANGED(null, null), (c, p)->{
            switch c {
                default:
                case PROPERTY_VALUE_CHANGED(property, owners):
                    //if(p==this) return;
                    if(!owners.exists(o->o.isEqualTo(target))){
                        return;
                    }
                    switch(property.guid){
                        default:
                        case CoreComponentTimelineControl.FRAME:
                            var f = target.frame;
                            if(current_frame!=f){
                                current_frame=f;
                            }
                        case CoreComponentTimelineControl.STATE:
                            var s = target.current_state;
                            if(current_state.name!=s.name){
                                selectState(s.name);
                            }
                        case CoreComponentTimelineControl.PLAYBACK:
                            if(is_playing!=target.is_playing){
                                is_playing = target.is_playing;
                            }
                    }
            }
        }, this);
        is_ready=true;
    }

    override function onDestroy(){
        Comms.cleanupSubscriber(this);
        super.onDestroy();
    }

    function updateAvailableStates(){
        var states_ds = new ArrayDataSource<String>();
        for(state in timeline.states){
            states_ds.add(state.name);
        }
        states_drp.dataSource=states_ds;
        on_end_state_drp.dataSource=states_ds;
        if(current_state!=null){
            states_drp.selectedItem=current_state.name;
        }
    }

    function updateAvailableProps(){
        if(current_state==null){
            return;
        }
        var props:Array<PropertyDef> = [];
        for(c in target.components){
            for(d in c.definitions){
                if(d.timeline_controllable && current_state.getTrackFor(d)==null){
                    props.push(d);
                }
            }
        }
        //TODO sort props here
        //Just alphabetical sort is bad; it will be confusing. 
        //should add component name to start and then sort.
        // props.sort((a, b)->a.name>b.name?1:a.name<b.name?-1:0);
        var ds = new ArrayDataSource<{text:String, value:PropertyDef}>();
        for(p in props){
            ds.add({text:p.name, value:p});
        }
        add_track_drp.dataSource=ds;
        if(ds.size==0){
            
            add_track_drp.selectedItem = {text:"No Valid Tracks", value:null};
            add_track_drp.text="---";
            add_track_drp.disabled=true;
            add_track_btn.disabled=true;
        }
        else{
            add_track_drp.selectedItem = ds.get(0);
            add_track_drp.disabled=false;
            add_track_btn.disabled=false;
        }
    }

    @:bind(add_track_btn, MouseEvent.CLICK)
    function onAddTrackBtnClicked(e){
        if(current_state==null) {
            return;
        }
        var newtrack:{text:String, value:PropertyDef} = add_track_drp.selectedItem;
        if(newtrack?.value!=null){
            var new_track = current_state.addTrack(newtrack.value);
            if(new_track!=null){
                addTrack(new_track);
            }
            updateAvailableProps();
        }
    }

    @:bind(zoom_drp, UIEvent.CHANGE)
    function onZoomDropChange(e){
        var target:TimelineZoom = zoom_drp.selectedItem.value;
        var new_value:Float = switch target {
            case ONE: 1.0;
            case TEN: 0.1;
            case HUNDRED: 0.01;
        }
        if(zoom_factor!=new_value){
            zoom_factor=new_value;
            rebuildFramesHeader();
            for(track in tracks){
                track.track.rebuildPositions();
            }
        }
    }

    function selectState(stateName:String){
        if(current_state?.name==stateName) return;
        this.pauseComponentValidation();
        tracksHolder.removeAllComponents();
        trackLabelsHolder.removeAllComponents();
        this.resumeComponentValidation();
        tracks = [];
        var target_state = timeline.getState(stateName);
        if(target_state==null){
            trace('No state "$stateName" found.');
            return;
        }
        current_state=target_state;
        target.setState(stateName);
        Comms.send(PROPERTY_VALUE_CHANGED(CoreComponentTimelineControl.state_def, [target]));
        on_end_frame_stp.max=current_state.frames;
        frames_stp.pos=current_state.frames;
        frames=current_state.frames;
        if(current_state.tracks!=null){
            for(t in current_state.tracks){
                addTrack(t);
            }
        }
        updateAvailableStates();
        switch current_state.onEnd {
            case STOP: 
                on_end_drp.selectedItem="Stop";
                on_end_frame_stp.visible=false;
                on_end_state_drp.visible=false;
            case LOOP: 
                on_end_drp.selectedItem="Loop";
                on_end_frame_stp.visible=false;
                on_end_state_drp.visible=false;
            case GO_TO_FRAME(frame): 
                on_end_frame_stp.pos = frame;
                on_end_drp.selectedItem="Go to frame";
                on_end_frame_stp.visible=true;
                on_end_state_drp.visible=false;
            case GO_TO_STATE(state): 
                on_end_state_drp.selectedItem=state;
                on_end_drp.selectedItem="Go to state";
                on_end_frame_stp.visible=false;
                on_end_state_drp.visible=true;
        }
        // onEndDrpChange(null);
        updateAvailableProps();
    }

    @:bind(frames_stp, UIEvent.CHANGE)
    function onFramesStepChange(e:UIEvent){
        this.frames=Std.int(frames_stp.pos);
    }

    @:bind(on_end_drp, UIEvent.CHANGE)
    function onEndDrpChange(?e:UIEvent){
        var val = on_end_drp.selectedItem.text;
        switch val{
            case "Stop":
                if(current_state!=null) current_state.onEnd = STOP;
                on_end_frame_stp.visible=false;
                on_end_state_drp.visible=false;
            case "Loop":
                if(current_state!=null) current_state.onEnd = LOOP;
                on_end_frame_stp.visible=false;
                on_end_state_drp.visible=false;
            case "Go to frame":
                if(current_state!=null) current_state.onEnd = GO_TO_FRAME(Std.int(on_end_frame_stp.pos));
                on_end_frame_stp.visible=true;
                on_end_state_drp.visible=false;
            case "Go to state":
                if(current_state!=null) current_state.onEnd = GO_TO_STATE(on_end_state_drp.selectedItem);
                on_end_frame_stp.visible=false;
                on_end_state_drp.visible=true;
            default:
        }
    }

    @:bind(on_end_state_drp, UIEvent.CHANGE)
    function onEndStateDropChange(e:UIEvent){
        if(on_end_drp.selectedItem?.text=="Go to state"){
            current_state?.onEnd=GO_TO_STATE(on_end_state_drp.selectedItem);
        }
    }

    @:bind(on_end_frame_stp, UIEvent.CHANGE)
    function onEndFrameStepChange(e:UIEvent){
        if(on_end_drp.selectedItem?.text=="Go to frame"){
            current_state?.onEnd=GO_TO_FRAME(Std.int(on_end_frame_stp.pos));
        }
    }

    @:bind(states_drp, UIEvent.CHANGE)
    function onStateDropChange(e:UIEvent){
        selectState(states_drp.selectedItem);
    }

    @:bind(frameHolder, MouseEvent.MOUSE_DOWN)
    function onFrameHolderMouseClick(e:MouseEvent){
        frame_holder_mouse_down = true;
        var target_frame = Math.round((e.localX-5)/20/zoom_factor);
        current_frame=target_frame;
    }

    @:bind(frameHolder, MouseEvent.MOUSE_UP)
    @:bind(frameHolder, MouseEvent.MOUSE_OUT)
    function onFrameHolderMouseUp(e:MouseEvent){
        frame_holder_mouse_down = false;
    }

    @:bind(frameHolder, MouseEvent.MOUSE_MOVE)
    function onFrameHolderMouseDrag(e:MouseEvent){
        if(!frame_holder_mouse_down) return;
        var target_frame = Math.round((e.localX-5)/20/zoom_factor);
        if(target_frame==current_frame) return;
        current_frame=target_frame;
    }

    @:bind(add_state_btn, MouseEvent.CLICK)
    function onAddStateClicked(e){
        //Pop up the generic text input modal
        new UITextInputModal("Input new timeline state name.", (result, text)->{
            if(timeline.getState(text)!=null){
                Comms.toast(Error, 'A state named $text already is in this timeline.', "State not created");
                return;
            }
            var new_state = timeline.addState(text, 30);
            updateAvailableStates();
            selectState(new_state.name);
        }).show();
    }

    @:bind(remove_state_btn, MouseEvent.CLICK)
    function onRemoveStateClicked(e){
        Dialogs.messageBox('Delete state "${current_state.name}"? State contents will be lost.', "Confirmation", MessageBoxType.TYPE_YESNO, true, (res)->
        {
            switch res {
                case DialogButton.YES:
                    timeline.states.remove(current_state);
                    updateAvailableStates();
                    selectState("Default");
                default:
            }
        });
    }

    function addTrack(track:TimelineTrack){
        var prop:PropertyDef = target.reference.getRoot().getThing(PROPERTYDEF, track.target);
        var label = new UITimelineTrackLabel(prop.name, this, track);
        var track_ui = new UITimelineTrack(this, track);
        trackLabelsHolder.addComponent(label);
        tracksHolder.addComponent(track_ui);
        tracks.push({track:track_ui, label:label});
    }

    public function removeTrack(track:TimelineTrack){
        var to_remove = tracks.find(t->t.track.track==track);
        if(to_remove!=null){
            tracksHolder.removeComponent(to_remove.track);
            trackLabelsHolder.removeComponent(to_remove.label);
            current_state.removeTrack(track);
            updateAvailableProps();
        }
    }

    function set_current_state(to:TimelineState){
        remove_state_btn.disabled = to.name=="Default";
        current_state = to;
        return to;
    }

    function set_frames(to:Int){
        if(!is_ready) return to;
        var largest_keyframe = 0;
        for(t in current_state.tracks){
            var kfs = t.getAllKeyframes();
            for(k in kfs){
                if(k.frame>largest_keyframe){
                    largest_keyframe=k.frame;
                }
            }
        }
        if(to<largest_keyframe){
            to = largest_keyframe;
        }
        frames_stp.pos = to;
        on_end_frame_stp.max = to;
        if(to==frames){ return frames; }
        frames=to;
        current_state.frames=to;
        rebuildFramesHeader();
        for(track in tracks){
            track.track.rebuildPositions();
        }
        if(to<current_frame){
            current_frame=to;
        }
        return frames;
    }

    function rebuildFramesHeader(){
        frameHolder.pauseComponentValidation();
        frameHolder.removeAllComponents();
        if(frames>5000){
            zoom_drp.selectedIndex = 2;
        }
        else if(frames > 500){
            zoom_drp.selectedIndex = 1;
        }
        onZoomDropChange(null);
        frameHolder.width=(frames+1/zoom_factor)*20*zoom_factor;

        for(i in 0...(Math.ceil(frames*zoom_factor))){
            frameHolder.addComponent(new UITimelineFrameMarker(Math.round(i/zoom_factor), Math.round(5/zoom_factor)));
        }
        frameHolder.resumeComponentValidation();
    }

    public function keyframeSelected(keyframe:UITimelineKeyframe, track:UITimelineTrack){
        for(t in tracks){
            if(t.track!=track){
                t.track.deselectAll();
            }
        }
        selected_frame=keyframe;
    }

    function set_selected_frame(to:UITimelineKeyframe){
        this.selected_frame=to;
        interpolation_drp.disabled = to==null;
        interpolation_drp.selectedItem = to.keyframe.interpolation;
        return to;
    }

    @:bind(interpolation_drp, UIEvent.CHANGE)
    function onInterpolationDropdownChange(e){
        if(selected_frame!=null){
            selected_frame.keyframe.interpolation=interpolation_drp.selectedItem;
        }
    }

    function set_current_frame(to:Int){
        if(to<0) to = 0;
        if(to>=frames) to = frames-1;
        current_frame = to;
        playhead.left = 18+current_frame*20*zoom_factor;
        target.frame = current_frame;
        Comms.send(PROPERTY_VALUE_CHANGED(CoreComponentTimelineControl.frame_def, [target]), this);
        for(t in target.current_state?.tracks??[]){
            Comms.send(PROPERTY_VALUE_CHANGED(target.reference.getRoot().unsafeGet(t.target), [target]), this);
        }
        return current_frame;
    }

    @:bind(contentScroller, ScrollEvent.CHANGE)
    private function onContentScrollerChange(_) {
        headerScroller.hscrollPos = contentScroller.hscrollPos;
        tracksScroller.vscrollPos = contentScroller.vscrollPos;
    }

    public function update(){
        if(is_playing){
            current_frame++;
            if(current_frame>=frames){
                is_playing=false;
            }
        }
    }
}

typedef UITimelineTrackCombo ={
    track:UITimelineTrack,
    label:UITimelineTrackLabel
}

@:xml('
    <vbox width="5" style="padding:2.5;">
        <label id="marker_lbl" text="${frame_label}" verticalAlign="bottom" horizontalAlign="center" />
        <rule id="marker_rule" direction="vertical"/>
    </vbox>
')
class UITimelineFrameMarker extends VBox{
    var number:Int;
    var frame_label:String="";
    var rule_height:Int=10;
    public function new(num:Int=0, number_per:Int=5){
        this.number=num;
        if(number%number_per==0){
            frame_label=Std.string(number);
        }        
        super();
        if(number%number_per==0){
            marker_rule.height=15;
        }
        else{
            marker_rule.height=5;
        }
    }
}

@:xml('
<hbox width="100%" height="30" style="background-color: $nord-dark2;border-bottom:1px solid $nord-dark1;">
    <button width="25px" height="25px" verticalAlign="center" id="remove_track_btn" icon="${Icon.trash_16}" tooltip="Remove track and all keyframes" styleName="timeline-button"/>
    <spacer width="5px"/>
    <label text="${track_name}" verticalAlign="center" width="80px" />
    <dropdown id="offset_drp" width="80px">
        <data>
            <item text="Absolute" value="${TimelineOffsetMethod.ABSOLUTE}"/>
            <item text="Relative" value="${TimelineOffsetMethod.RELATIVE}"/>
        </data>
    </dropdown>
</hbox>
')
class UITimelineTrackLabel extends HBox{
    var track_name:String;
    var timeline:UITimelineEditor;
    var track:TimelineTrack;
    public function new(track_name:String, timeline:UITimelineEditor, track:TimelineTrack){
        this.track_name=track_name;
        this.timeline = timeline;
        this.track=track;
        super();
        offset_drp.text = switch track.offset {
            case ABSOLUTE: "Absolute";
            case RELATIVE: "Relative";
        };
    }

    @:bind(offset_drp, UIEvent.CHANGE)
    function onOffsetDrpChanged(e){
        track.offset = offset_drp.selectedItem.value;
    }

    @:bind(remove_track_btn, MouseEvent.CLICK)
    function onRemoveTrackClicked(e){
        timeline.removeTrack(track);
    }
}

@:xml('
<hbox height="30" style="background-color: $nord-dark4;border-bottom:1px solid $nord-dark1;">
    <absolute id="frame_layout" width="100%" height="100%">
    </absolute>;
</hbox>
')
class UITimelineTrack extends HBox{
    public var mouse_x:Float=0;
    public var keyframes:Map<Int, UITimelineKeyframe> = [];
    var property:PropertyDef;
    public var timeline:UITimelineEditor;
    public var track:TimelineTrack;
    public function new(timeline:UITimelineEditor, track:TimelineTrack){
        this.timeline = timeline;
        this.track=track;
        super();
        width=timeline.frames*20*timeline.zoom_factor;
        this.property = timeline.target.reference.getRoot().getThing(PROPERTYDEF, track.target);
        this.onDblClick = onDoubleClick;
        this.onRightClick = _->trace("rght");
        for(k in track.getAllKeyframes()){
            addKeyframeUI(k.frame, k.keyframe);
        }
    }
    public function rebuildPositions(){
        width=(timeline.frames+1/timeline.zoom_factor)*20*timeline.zoom_factor;
        for(i=>keyframe in keyframes){
            keyframe.updateFramePosition();
        }
    }

    @:bind(this, MouseEvent.MOUSE_MOVE)
    function onMouseMove(e:MouseEvent){
        mouse_x = e.localX;
        for(k in keyframes){
            if(k.is_mouse_down){
                k.onMouseMove(e);
            }
        }
    }

    function onDoubleClick(e:MouseEvent){
        var target_frame = Math.round(((e.localX-5)/20)/timeline.zoom_factor);
        if(!keyframes.exists(target_frame)){
            addKeyframe(target_frame);
        }
    }

    public function addKeyframe(frame:Int){
        if(!keyframes.exists(frame)&&track.getKeyframe(frame)==null){
            var kf = track.addKeyframe(frame, (track.getPreviousKeyframe(frame)?.keyframe?.value)??timeline.target.getValue(property));
            addKeyframeUI(frame, kf);
        }
        else{
            trace('Warning: Tried to add frame where there already is one ($frame).');
        }
    }

    function addKeyframeUI(frame:Int, data:TimelineKeyframe){
        var kf_ui = new UITimelineKeyframe(frame, this, data);
        keyframes.set(frame, kf_ui);
        this.frame_layout.addComponent(kf_ui);
    }

    public function removeKeyframe(frame:Int){
        if(!keyframes.exists(frame)){
            trace('Warning: Tried to remove frame where there is not one ($frame).');
            return;
        }
        var target = keyframes.get(frame);
        track.removeKeyframe(frame);
        keyframes.remove(frame);
        this.frame_layout.removeComponent(target);
    }

    public function keyframeSelected(keyframe:UITimelineKeyframe){
        for(k in keyframes){
            if(k.frame!=keyframe.frame){
                k.is_selected = false;
            }
        }
        timeline.keyframeSelected(keyframe, this);
        timeline.current_frame = keyframe.frame;
    }

    public function deselectAll(){
        for(k in keyframes){
            k.is_selected=false;
        }
    }

    public function tryMoveKeyframe(keyframe:UITimelineKeyframe, old_frame:Int, new_frame:Int):Bool{
        if(!keyframes.exists(new_frame)&&track.tryMoveKeyframe(old_frame, new_frame)){
            keyframes.remove(old_frame);
            keyframes.set(new_frame, keyframe);
            return true;
        }
        return false;
    }
}

@:xml('
<box width="10" height="20" style="background-color: $nord-blue4;border:1px solid; top:5px;" verticalAlign="center" />
')
class UITimelineKeyframe extends Box{
    public var frame(default, set):Int = -1;
    public var is_selected(default, set):Bool;
    public var is_mouse_down:Bool = false;
    var mouse_down_x:Float = 0;
    var pre_drag_margin:Float = 0;
    var track:UITimelineTrack;
    public var keyframe:TimelineKeyframe;
    public function new(frame:Int, parent:UITimelineTrack, keyframe:TimelineKeyframe){
        super();
        this.track = parent;
        this.frame = frame;
        this.is_selected=false;
        this.keyframe=keyframe;

        this.onRightClick = e->{
            var menu = new UITimelineKeyframeMenu(this);
            menu.top = e.screenY;
            menu.left = e.screenX;
            Screen.instance.addComponent(menu);
        }
    }

    @:bind(this, MouseEvent.MOUSE_DOWN)
    function onMouseDown(e:MouseEvent){
        is_mouse_down = true;
        //pre_drag_margin = this.marginLeft;
        mouse_down_x = track.mouse_x;
    }

    @:bind(this, MouseEvent.MOUSE_MOVE)
    public function onMouseMove(e:MouseEvent){
        if(this.frame==0) return; //cannot move frame 0
        if(is_mouse_down){
            this.left = track.mouse_x-5;
        }
    }

    @:bind(this, MouseEvent.MOUSE_UP)
    function onMouseUp(e){
        if(!is_mouse_down) return; //bounce protection...
        is_mouse_down = false;
        if(mouse_down_x==track.mouse_x){
            is_selected=!is_selected;
        }
        else{
            snapToFrame();
        }
    }

    @:bind(this, MouseEvent.MOUSE_OUT)
    function onMouseLost(e){
        // if(is_mouse_down){
        //     snapToFrame();
        // }
        // is_mouse_down = false;
    }

    function snapToFrame(){
        set_frame(Math.round((this.left-4)/20/track.timeline.zoom_factor));
    }

    function set_is_selected(to){
        this.is_selected = to;
        borderColor=is_selected?Nord.red:Nord.blue1;
        if(is_selected){
            track.keyframeSelected(this);
        }
        return is_selected;
    }

    function set_frame(to:Int){
        if(frame==-1||track.tryMoveKeyframe(this, frame, to)){
            frame = to;
        }
        updateFramePosition();
        return frame;
    }

    public function updateFramePosition(){
        this.left=20*(frame*track.timeline.zoom_factor)+4;
    }

    public function removeSelf(){
        if(frame==0) return;
        track.removeKeyframe(frame);
    }
}

@:xml('
<menu>
    <menu-item id="remove_itm" text="Remove" disabled="${keyframe.frame==0}"/>
</menu>
')
class UITimelineKeyframeMenu extends Menu{
    var keyframe:UITimelineKeyframe;
    public function new(keyframe:UITimelineKeyframe){
        this.keyframe=keyframe;
        super();
    }

    @:bind(this, MenuEvent.MENU_SELECTED)
    function onRemoveSelected(e:MenuEvent){
        switch(e.menuItem.id){
            case "remove_itm":
                keyframe.removeSelf();
        }
    }
}

enum TimelineZoom{
    ONE;
    TEN;
    HUNDRED;
}