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

import thinglib.property.Property.PropertyValue;
import haxe.ui.containers.properties.PropertyGroup;
import haxe.ui.containers.HBox;
import haxe.ui.containers.properties.Property;
import thinglib.component.Entity;
import thinglib.Util.ThingID;
import thinglib.Thing;
import thinglib.storage.Reference;
import haxe.ui.containers.dialogs.Dialogs;
import haxe.ui.containers.windows.Window;
import haxe.ui.data.ArrayDataSource;
import haxe.ui.events.MouseEvent;
import haxe.ui.events.UIEvent;
import thinglib.property.PropertyDef;
import thinglib.property.Component;
using Lambda;

@:xml('
<window title="Property Settings" width="600" >
    <grid width="100%">
        <label text="Name" verticalAlign="center"/>
        <textfield id="name_txt"/>
        
        <label text="Type" verticalAlign="center" hidden="${type_drp.hidden}"/>
        <dropdown id="type_drp" text="Select Type" width="100%" verticalAlign="center" />

        <label text="Options" verticalAlign="center" hidden="${options_grd.hidden}"/>
        <!-- <textarea height="100" id="options_txt" hidden="true"/> -->
        <property-grid id="options_grd" width="100%" height="300" hidden="true">
            <property-group id="options_grp" text="Options">
                <header style="spacing: 5px;">
                    <button id="add_option_btn" text="+"/>
                </header>
            </property-group>
        </property-grid>
        
        <label text="Default Value" verticalAlign="center" hidden="${default_txt.hidden}"/>
        <textfield id="default_txt" hidden="true"/>

        <label text="Default Value" verticalAlign="center" hidden="${default_drp.hidden}"/>
        <dropdown id="default_drp" dataSource="${multids}" width="100%" text="(None)" hidden="true"/>
        
        <label text="Default Value" verticalAlign="center" hidden="${default_chk.hidden}"/>
        <checkbox id="default_chk" hidden="true"/>

        <label text="Type Constraint" verticalAlign="center" hidden="${constraint_drp.hidden}"/>
        <dropdown id="constraint_drp" width="100%" hidden="true"/>
        
        <label text="Minimum Value" verticalAlign="center" hidden="${min_txt.hidden}"/>
        <textfield id="min_txt" hidden="true"/>
        
        <label text="Max Value" verticalAlign="center" hidden="${max_txt.hidden}"/>
        <textfield id="max_txt" hidden="true"/>
        
        <label text="Step Size" verticalAlign="center" hidden="${precision_txt.hidden}"/>
        <textfield id="precision_txt" hidden="true"/>
        
        <label text="Default Color" verticalAlign="center" hidden="${default_clr.hidden}"/>
        <ColorPickerPopup id="default_clr" hidden="true"/>

        <label text="Timeline Controllable" verticalAlign="center"/>
        <checkbox id="timeline_controllable_chk"/>
    
        <label text="Extra Data" verticalAlign="center"/>
        <textfield id="extra_txt"/>
        
        <label text="Documentation" verticalAlign="center"/>
        <textarea id="documentation_txt" height="100"/>
    </grid>
    <button text="Add" id="finish_btn" disabled="${name_txt.text==''}"/>
</window>
')
class UIPropertyDefEditor extends Window{
    var list:Component;
    var def:PropertyDef;
    var mode:PropDefEditorMode;
    var multids:ArrayDataSource<{text:String, value:Int}> = new ArrayDataSource();
    var multidefaults:Array<Int> = [];
    var type:PropertyType;
    var options:Map<Int, String>;
    var onComplete:()->Void;
    var props:Array<Property> = [];
    public function new(list:Component, mode:PropDefEditorMode=ADD){
        super();
        this.list = list;
        this.mode = mode;

        this.name_txt.restrictChars="a-zA-Z0-9_";
        this.min_txt.restrictChars="0-9";
        this.max_txt.restrictChars="0-9";
        this.precision_txt.restrictChars="0-9";
        var ds = new ArrayDataSource<PropertyType>();
        for(t in PropertyType.createAll()){
            ds.add(t);
        }
        type_drp.dataSource = ds;
        
        var root = list.reference.getRoot();
        var tcds = new ArrayDataSource<{text:String, value:ThingID}>();
        for(c in root.getAll(Component)){
            tcds.add({text:c.name+' (Component)', value:c.guid});
        }
        for(e in root.getAll(Entity)){
            tcds.add({text:e.name+' (Prefab)', value:e.guid});
        }
        constraint_drp.dataSource=tcds;
        switch mode {
            case ADD: 
                this.title = list.name+": Add Prop";
                this.options = new Map();
            case EDIT(property): 
                type_drp.selectedItem=property.type;
                type = property.type;
                switch property.type {
                    case INT:
                        if(property.default_value!=NONE) this.default_txt.text = Std.string(property.defaultValInt());
                        if(property.minimum_value!=NONE) this.min_txt.text = Std.string(property.minValInt());
                        if(property.maximum_value!=NONE) this.max_txt.text = Std.string(property.maxValInt());
                        if(property.step_size!=NONE)     this.precision_txt.text = Std.string(property.stepValInt());
                    case FLOAT:
                        if(property.default_value!=NONE) this.default_txt.text = Std.string(property.defaultValFloat());
                        if(property.minimum_value!=NONE) this.min_txt.text = Std.string(property.minValFloat());
                        if(property.maximum_value!=NONE) this.max_txt.text = Std.string(property.maxValFloat());
                        if(property.step_size!=NONE)     this.precision_txt.text = Std.string(property.stepValFloat());
                    case STRING:
                        if(property.default_value!=NONE) this.default_txt.text = property.defaultValString();
                    case BOOL:
                        if(property.default_value!=NONE) this.default_chk.value = property.defaultValBool();
                    case COLOR:
                        if(property.default_value!=NONE) this.default_clr.value = property.defaultValInt();
                    case SELECT:
                        var selected_default = property.defaultValInt();
                        if(property.options?.exists(selected_default)){
                            default_drp.selectedItem = {text:property.options[selected_default], value:selected_default};
                        }
                        else{
                            default_drp.selectedItem = {text:"(none)", value:-1};   
                        }
                    case REF:
                        if(property.ref_base_type_guid==Reference.EMPTY_ID){
                            constraint_drp.selectedItem={text:"Any", value:Reference.EMPTY_ID};
                        }
                        else{
                            var basetype:Thing = property.reference.getRoot().unsafeGet(property.ref_base_type_guid);
                            if(basetype==null){
                                constraint_drp.selectedItem={text:'Unknown: ${property.ref_base_type_guid}', value:property.ref_base_type_guid};
                            }
                            else{
                                constraint_drp.text='${basetype.name} (${basetype.thingType})';
                                constraint_drp.value=property.ref_base_type_guid;
                            }
                        }
                    case MULTI:
                        multidefaults = property.defaultValIntArray()?.copy()??[];
                    default:
                }
                name_txt.text = property.name;
                timeline_controllable_chk.value = property.timeline_controllable;
                documentation_txt.value = property.documentation??"";
                extra_txt.value = property.extra_data??"";
                finish_btn.text = "Save";
                this.options=property.options?.copy()??null;
                if(options!=null){
                    populateOptions();
                }
                this.title = property.name+": Edit Prop";
        }
    }

    // @:bind(options_txt, UIEvent.CHANGE)
    function onOptionsChange(e){
        var old_value = default_drp.selectedItem?.value??-1;
        multids.clear();
        for(id=>o in options){
            multids.add({text:o, value:id});
        }
        if(!options.exists(old_value)){
            default_drp.selectedItem = {text:"(none)", value:-1};
        }
        else{
            default_drp.selectItemBy(v->v.value==old_value);
        }
    }

    @:bind(add_option_btn, MouseEvent.CLICK)
    function onAddOptionClicked(e){
        var newid = 0;
        for(id in options.keys()){
            if(id>=newid){
                newid = id+1;
            }
        }
        options.set(newid, "");
        addOptionEntry(newid, "");
    }

    function addOptionEntry(id:Int, name:String){
        var prop = new Property();
        prop.type="text";
        prop.value = name;
        var control = new UIPropOptionsControl(options, id, options_grp, prop, type==MULTI, multidefaults.has(id), v->{
            if(v){
                if(!multidefaults.has(id)){
                    multidefaults.push(id);
                }
            }
            else{
                multidefaults.remove(id);
            }
        }, 
        id->onOptionsChange(null));
        prop.addComponent(control);
        options_grp.addComponent(prop);
        props.push(prop);
        prop.onChange = (e)->{
            options.set(id, prop.value);
            onOptionsChange(null);
        };
    }

    function populateOptions(){
        for(p in props){
            options_grp.removeComponent(p);
        }
        props = [];
        if(options==null) return;
        for(index=>option in options){
            addOptionEntry(index, option);
        }
        onOptionsChange(null);
    }

    @:bind(finish_btn, MouseEvent.CLICK)
    function onFinishClicked(e){
        //parse the stuffs into prop def here.
        var type = PropertyType.fromString(type_drp.selectedItem);
        var np = switch mode {
            case ADD: new PropertyDef(list);
            case EDIT(property): property;
        }
        np.name = name_txt.text;
        np.type = type;
        np.documentation = documentation_txt.value;
        np.extra_data = extra_txt.value;
        np.timeline_controllable = timeline_controllable_chk.value;

        var should_close = true;
        switch type {
            case INT:
                np.default_value = default_txt.text==""?NONE:INT(Std.parseInt(default_txt.text));
                np.minimum_value = min_txt.text==""?NONE:INT(Std.parseInt(min_txt.text));
                np.maximum_value = max_txt.text==""?NONE:INT(Std.parseInt(max_txt.text));
                np.step_size = precision_txt.text==""?NONE:INT(Std.parseInt(precision_txt.text));
           case FLOAT:
                np.default_value = default_txt.text==""?NONE:FLOAT(Std.parseFloat(default_txt.text));
                np.minimum_value = min_txt.text==""?NONE:FLOAT(Std.parseFloat(min_txt.text));
                np.maximum_value = max_txt.text==""?NONE:FLOAT(Std.parseFloat(max_txt.text));
                np.step_size = precision_txt.text==""?NONE:FLOAT(Std.parseFloat(precision_txt.text));
            case STRING:
                np.default_value = default_txt.text==""?NONE:STRING(default_txt.text);
            case BOOL:
                np.default_value = BOOL(default_chk.value);
            case COLOR:
                np.default_value = COLOR(Std.parseInt(Std.string(default_clr.value)));
            case SELECT:
                np.options = options.copy();
                np.default_value = SELECT(default_drp.selectedItem.value);
            case MULTI:
                np.options = options.copy();
                np.default_value = MULTI(multidefaults.copy());
            case REF:
                np.default_value = REF(Reference.EMPTY_ID);
                np.ref_base_type_guid = constraint_drp.selectedItem.value;
            default:
                should_close = false;
                Dialogs.messageBox('Invalid property type.', 'Error', 'error');
        }
        if(should_close){
            if(mode==ADD){
                this.list.definitions.push(np);
            }
            Comms.send(REQUEST_SAVE_THING(list), this);
            Comms.send(REQUEST_ENUMERATE_COMPONENTS, this);
            windowManager.closeWindow(this);
        }
    }

    @:bind(type_drp, UIEvent.CHANGE)
    function onTypeSelected(e){
        default_txt.hidden=true;
        min_txt.hidden=true;
        max_txt.hidden=true;
        precision_txt.hidden=true;
        default_chk.hidden=true;
        default_clr.hidden=true;
        // options_txt.hidden=true;
        options_grd.hidden=true;
        constraint_drp.hidden=true;
        var v:PropertyType = Std.string(type_drp.selectedItem);
        type=v;
        switch v {
            case INT:
                default_txt.hidden=false;
                min_txt.hidden=false;
                max_txt.hidden=false;
                precision_txt.hidden=false;
                default_txt.restrictChars="0-9-";
                min_txt.restrictChars="0-9-";
                max_txt.restrictChars="0-9-";
                precision_txt.restrictChars="0-9-";
            case FLOAT:
                default_txt.hidden=false;
                min_txt.hidden=false;
                max_txt.hidden=false;
                precision_txt.hidden=false;
                default_txt.restrictChars="0-9-.";
                min_txt.restrictChars="0-9-.";
                max_txt.restrictChars="0-9-.";
                precision_txt.restrictChars="0-9-.";
            case STRING, URI:
                default_txt.hidden=false;
                default_txt.restrictChars="";
            case BOOL:
                default_chk.hidden=false;
            case COLOR:
                default_clr.hidden=false;
            case SELECT:
                options_grd.hidden = false;
                default_drp.hidden=false;
                populateOptions();
            case MULTI:
                // options_txt.hidden=false;
                options_grd.hidden = false;
                populateOptions();
                // onOptionsTxtChange(null);
                //default_txt.hidden=false;
            case REF:
                constraint_drp.hidden=false;
            default:
        }
    }
}

enum PropDefEditorMode{ADD; EDIT(property:PropertyDef);}


@:xml('
    <hbox>
        <hbox width="100%">
            <label text="${Std.string(index)}"/>
        </hbox>
        <button width="25px" height="25px" verticalAlign="center" id="remove_btn" text="x"/>
        <checkbox verticalAlign="center" id="default_check" value="${is_default}" hidden="${!show_default_checkbox}"/>
    </hbox>
')
class UIPropOptionsControl extends HBox{
    var target:Map<Int, String>;
    public var index:Int;
    var group:PropertyGroup;
    var property:Property;
    var show_default_checkbox:Bool;
    var default_callback:Bool->Void;
    var remove_callback:Int->Void;
    override public function new(target:Map<Int, String>, index:Int, group:PropertyGroup, property:Property, show_default_checkbox:Bool, is_default:Bool, default_callback:Bool->Void, remove_callback:Int->Void){
        this.target = target;
        this.index = index;
        this.group = group;
        this.show_default_checkbox = show_default_checkbox;
        this.property = property;
        this.default_callback=default_callback;
        this.remove_callback=remove_callback;
        super();
    }

    @:bind(remove_btn, MouseEvent.CLICK)
    function removeButtonClicked(e){
        target.remove(index);
        group.removeComponent(property);
        if(remove_callback!=null){
            remove_callback(index);
        }
    }

    @:bind(default_check, UIEvent.CHANGE)
    function defaultCheckboxChanged(e){
        if(default_callback!=null){
            default_callback(default_check.value);
        }
    }
}