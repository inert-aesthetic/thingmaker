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

import haxe.ui.containers.dialogs.Dialogs;
import haxe.ui.containers.windows.Window;
import haxe.ui.data.ArrayDataSource;
import haxe.ui.events.MouseEvent;
import haxe.ui.events.UIEvent;
import thinglib.property.PropertyDef;
import thinglib.property.Component;
using Lambda;

@:build(haxe.ui.ComponentBuilder.build("res/ui/property_def_editor.xml"))
class UIPropertyDefEditor extends Window{
    var list:Component;
    var mode:PropDefEditorMode;
    var multids:ArrayDataSource<String> = new ArrayDataSource();
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
        switch mode {
            case ADD: 
                this.title = list.name+": Add Prop";
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
                        options_txt.text = (property.options??[]).join(",");
                        default_drp.selectedIndex = property.defaultValInt()??-1;
                    case MULTI:
                        var arr = property.defaultValIntArray();
                        default_txt.text = property.defaultValIntArray().map(i->(property.options??[])[i]??'').join(',');
                        options_txt.text = (property.options??[]).join(",");
                    default:
                }
                name_txt.text = property.name;
                // nodes_chk.value = property.available_on_nodes;
                // edges_chk.value = property.available_on_edges;
                // groups_chk.value = property.available_on_groups;
                // regions_chk.value = property.available_on_regions;
                //show_in_prop_explorer_chk.value = property.user_selectable;
                documentation_txt.value = property.documentation??"";
                extra_txt.value = property.extra_data??"";
                finish_btn.text = "Save";
                this.title = property.name+": Edit Prop";
        }
    }

    @:bind(options_txt, UIEvent.CHANGE)
    function onOptionsTxtChange(e){
        multids.clear();
        options_txt.text.split(",").iter(o->multids.add(o));
        default_drp.selectedIndex = -1;
        default_drp.text = "(None)";
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
        // np.available_on_constructs = constructs_chk.value;
        // np.available_on_edges = edges_chk.value;
        // np.available_on_nodes = nodes_chk.value;
        // np.available_on_groups = groups_chk.value;
        // np.available_on_regions = regions_chk.value;
        np.documentation = documentation_txt.value;
        np.extra_data = extra_txt.value;
        //np.user_selectable = show_in_prop_explorer_chk.value;

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
                np.options = options_txt.text.split(",").filter(f->f!='');
                np.default_value = SELECT(default_drp.selectedIndex);
            case MULTI:
                np.options = options_txt.text.split(",").filter(f->f!='');
                np.default_value = MULTI(default_txt.text.split(",").map(t->np.options.indexOf(t)??-1).filter(v->v!=-1));
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
        options_txt.hidden=true;
        
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
                options_txt.hidden=false;
                default_drp.hidden=false;
                onOptionsTxtChange(null);
                //default_txt.hidden=false;
            default:
        }
    }
}

enum PropDefEditorMode{ADD; EDIT(property:PropertyDef);}