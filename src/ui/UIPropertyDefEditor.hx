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
    var options:Map<Int, String>;
    var onComplete:()->Void;
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
                        var arr = property.defaultValIntArray();
                        default_txt.text = property.defaultValIntArray().map(i->(property.options??[])[i]??'').join(',');
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
    function onOptionsTxtChange(e){
        multids.clear();
        for(id=>o in options){
            multids.add({text:o, value:id});
        }
        default_drp.selectedIndex = -1;
        default_drp.text = "(None)";
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
        prop.label = Std.string(id);
        prop.value = name;
        options_grp.addComponent(prop);
        prop.onChange = (e)->{
            options.set(id, prop.value);
        };
    }

    function populateOptions(){
        if(options==null) return;
        for(index=>option in options){
            addOptionEntry(index, option);
        }
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
                np.default_value = SELECT(default_drp.selectedIndex);
            case MULTI:
                np.options = options.copy();
                np.default_value = MULTI(default_txt.text.split(",").map(t->np.options.indexOf(t)??-1).filter(v->v!=-1));
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
            case STRING:
                default_txt.hidden=false;
                default_txt.restrictChars="";
            case BOOL:
                default_chk.hidden=false;
            case COLOR:
                default_clr.hidden=false;
            case SELECT, MULTI:
                // options_txt.hidden=false;
                options_grd.hidden = false;
                default_drp.hidden=false;
                // onOptionsTxtChange(null);
                //default_txt.hidden=false;
            case REF:
                constraint_drp.hidden=false;
            default:
        }
    }
}

enum PropDefEditorMode{ADD; EDIT(property:PropertyDef);}