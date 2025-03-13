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

import thinglib.Thing;
import thinglib.component.Accessors.TimelineControlled;
import thinglib.storage.Reference;
import thinglib.Util.ThingID;
import haxe.ui.events.UIEvent;
import haxe.ui.components.DropDown;
import thinglib.property.Component;
import haxe.EnumTools.EnumValueTools;
import haxe.ui.containers.HBox;
import format.abc.Data.ABCData;
import Comms.CommType;
import pasta.Vect;
import haxe.ui.components.Label;
import thinglib.component.Entity;
import haxe.ui.containers.windows.WindowManager;
import haxe.ui.components.Button;
import thinglib.property.Property.PropertyValue;
import haxe.ui.data.ArrayDataSource;
import thinglib.property.PropertyDef;
import haxe.ui.components.popups.ColorPickerPopup;
import haxe.ui.containers.VBox;
import haxe.ui.containers.properties.Property;
import haxe.ui.containers.properties.PropertyGrid;
import haxe.ui.containers.properties.PropertyGroup;
import haxe.ui.events.MouseEvent;

using Lambda;
using thinglib.component.util.EntityTools;
using thinglib.component.util.PropertyValueTools;

@:build(haxe.ui.ComponentBuilder.build("res/ui/property_explorer.xml"))
class UIPropertyExplorer extends VBox{
    private var attached_objects:Array<Entity> = [];
    private var object:Entity;
    
    private var construct:Entity;
    private var components:Array<Component> = [];
    private var common_components:Array<Component>;
    var property_groups:Array<PropertyGroupComponent> = [];
    var property_editors:Map<ThingID, {header:PropertyLabelControl, editor:Property}> = [];
    var components_drop_lookup:Array<Component> = [];

    public function new(){
        super();
        Comms.subscribe(COMPONENTS_CHANGED(null), (c, p)->{
            switch c {
                case COMPONENTS_CHANGED(project):
                    //if(defs==null) return;
                    this.components = project.components;
                    buildComponentsDrop(project.components.filter(f->f.user_selectable));
                default:
            }
        }, this);
        Comms.subscribe(CONSTRUCT_CHANGED(null), (c,p)->{
            switch c {
                default:
                case CONSTRUCT_CHANGED(construct):
                    this.construct=construct;
            }
        }, this);
        Comms.subscribe(ENTITY_PROPERTIES_CHANGED(null), (c, p)->populate(), this);
        Comms.subscribe(PROPERTY_VALUE_CHANGED(null, null), updatePropertyValue, this);
    }

    override function onDestroy(){
        Comms.cleanupSubscriber(this);
        super.onDestroy();
    }

    public function attachObject(object:Entity, skip_population:Bool=false){   
        this.attached_objects.push(object);
        if(skip_population) return;
        this.populate();
    }

    function buildComponentsDrop(components:Array<Component>){
        var ds = new ArrayDataSource();
        components_drop_lookup = [];
        components.iter(component->{
            ds.add(component.name);
            components_drop_lookup.push(component);
        });
        component_type_drp.dataSource = ds;
    }

    function populate(){
        count.text = attached_objects.length==1?attached_objects[0].name:Std.string(attached_objects.length);
        property_grid.removeAllComponents(true);
        property_groups=[];
        common_components = [];
        property_editors = [];
        if(attached_objects.length==0){
            return;
        }
        else if(attached_objects.length==1){
            var object = attached_objects[0];
            for(c in object.components){
                var property_group:PropertyGroupComponent = new PropertyGroupComponent(attached_objects, c);
                property_groups.push(property_group);
                property_group.text = c.name;
                this.property_grid.addComponent(property_group);
                for(pd in c.definitions){
                    var prop = new Property();
                    var control = new PropertyLabelControl(pd, object);
                    prop.addComponent(control);
                    switch pd.type {
                        case INT: 
                            prop.type = "number"; 
                            prop.precision = 0;
                            if(pd.minimum_value!=NONE) prop.min = pd.minValInt();
                            if(pd.maximum_value!=NONE) prop.max = pd.maxValInt();
                            if(pd.step_size!=NONE) prop.step = pd.stepValInt(); 
                        case FLOAT: 
                            prop.type = "number"; 
                            prop.precision = 2;
                            if(pd.minimum_value!=NONE) prop.min = pd.minValFloat();
                            if(pd.maximum_value!=NONE) prop.max = pd.maxValFloat();
                            if(pd.step_size!=NONE) prop.step = pd.stepValFloat();  
                        case STRING: prop.type = "text";
                        case BOOL: prop.type = "boolean";
                        case REFS:
                            prop.addComponent(new UIMultiNotSupported());
                        case COLOR: prop.type = "color";
                        case REF:
                            prop.type = "list";
                            var ds = new ArrayDataSource<{text:String, value:ThingID}>();
                            ds.add({text:"None", value:Reference.EMPTY_ID});
                            var valid_choices:Array<Entity> = construct?.getChildrenRecursive(true);
                            if(pd.ref_base_type_guid!=Reference.EMPTY_ID){
                                var constraint:Thing = construct.reference.getRoot().unsafeGet(pd.ref_base_type_guid);
                                if(constraint?.thingType==ENTITY){
                                    valid_choices = valid_choices.filter(vc->vc.instanceOf?.isEqualTo(constraint));
                                }
                                else if(constraint?.thingType==COMPONENT){
                                    valid_choices = valid_choices.filter(vc->vc.hasComponentByGUID(constraint.guid));
                                }
                            }
                            for(n in valid_choices){
                                ds.add({text:n.name, value:n.guid});
                            }
                            prop.dataSource=ds;
                            var s = object.getValue(pd).entityValue(object);
                            prop.registerEvent(UIEvent.READY, e->{
                                var drop = e.target.findComponent(null, DropDown, true);
                                var val = {text:"None", value:Reference.EMPTY_ID};
                                if(s!=null){
                                    val={text:s.name, value:s.guid};
                                }
                                drop.unregisterEvents(UIEvent.CHANGE);
                                object.setValue(pd, REF(val.value));
                                drop.selectedItem = val;
                                drop.onChange = e->{
                                    var val:{text:String, value:ThingID} = drop.selectedItem;
                                    object.setValue(pd, REF(val.value));
                                    Comms.sendDebounced(PROPERTY_VALUE_CHANGED(pd, [object]), "PropExpOnChangeClosure", 100, this);
                                    // Comms.send(PROPERTY_VALUE_CHANGED(pd, [object]), this);
                                }
                            });
                        case SELECT:
                            prop.type = "list";
                            var ds = new ArrayDataSource();
                            for(o in pd.options) ds.add(o);
                            prop.dataSource = ds;
                            prop.registerEvent(UIEvent.READY, e->
                            {
                                var drop = e.target.findComponent(null, DropDown, true);
                                drop.unregisterEvents(UIEvent.CHANGE);
                                var id = object.getValue(pd).intValue();
                                drop.selectedItem = {text:pd.options[id]??"[Invalid]", value:id};
                                drop.onChange = e->{
                                    object.setValue(pd, SELECT(pd.options.indexOf(e.value)));
                                    Comms.sendDebounced(PROPERTY_VALUE_CHANGED(pd, [object]), "PropExpOnChangeClosure", 100, this);
                                    // Comms.send(PROPERTY_VALUE_CHANGED(pd, [object]), this);
                                }
                            });
                        case MULTI:
                            prop.value = "Edit";
                            prop.type = "action";
                        default: prop.type = "text";
                    }

                    switch(pd.type){
                        case MULTI:
                            prop.onChange = e->{
                                var editor = new UIMultiPropEditor(pd, attached_objects);
                                WindowManager.instance.addWindow(editor);
                            }
                        case REFS, REF, SELECT:
                        default:
                            prop.value = object.getValue(pd).getValueAsDynamic();
                            prop.onChange = e->{
                                var changed:Bool = false;
                                var setvalue = prop.value;      
                                if(setvalue!=null){
                                    //TODO And ignore change on first load!
                                    var res = object.setValueFromDynamic(pd, setvalue);
                                    changed = changed||res;
                                }
                                if(changed){
                                    //Comms.send(PROPERTY_VALUE_CHANGED(pd, attached_objects), this);
                                    Comms.sendDebounced(PROPERTY_VALUE_CHANGED(pd, attached_objects), "PropExpOnChangeClosure", 100, this);
                                
                                }
                            };
                    }
                    property_group.addComponent(prop);
                    property_editors.set(pd.guid, {header:control, editor:prop});
                }
            }
        }
        else{
            var first_obj = true;
            for(o in attached_objects){
                var l = o.components;
                for(p in l){
                    var def = p.guid;
                    if(first_obj){
                        common_components.push(p);
                    }
                }
                if(!first_obj){
                    for(e in common_components){
                        if(!l.exists(p->p.guid==e.guid)){ //If this object doesn't have it, it's not common 
                            common_components.remove(e);
                        }
                    }
                }
                first_obj = false;
            }
            for(c in common_components){
                if(c.base){
                    common_components.remove(c);
                    common_components.unshift(c);//move base component to top
                }
            }
            for(c in common_components){
                var property_group:PropertyGroupComponent = new PropertyGroupComponent(attached_objects, c);
                property_groups.push(property_group);
                property_group.text = c.name;
                this.property_grid.addComponent(property_group);
                addCommonPropsToGroup(cast attached_objects, property_group, c);
            }

        }
    }

    function updatePropertyValue(c:CommType, p:Dynamic){
        // if(p==this) return;
        if(object==null) return; //only for single selections
        switch c {
            default:
            case PROPERTY_VALUE_CHANGED(propertydef, owners):
                if(!owners.exists(o->o.isEqualTo(object))){
                    return;
                }
                if(!property_editors.exists(propertydef.guid)){
                    return;
                }
                var editor = property_editors.get(propertydef.guid);
                switch propertydef.type {
                    case SELECT:
                        var dd = editor.editor.findComponent(null, DropDown, true);
                        var val = object.getValue(propertydef).intValue();
                        if(dd!=null) dd.selectedItem={text:propertydef.options[val], value:null};
                    default:
                        editor.editor.value=object.getValue(propertydef).getValueAsDynamic();
                }
        }
    }

    function addCommonPropsToGroup(objects:Array<Entity>, group:PropertyGroup, component:Component){
        //want the properties that are shared between all objects selected

        for(prop_def in component.definitions){
            var prop = new Property();
            prop.label = prop_def.name;

            var values:Array<PropertyValue> = [];
            for(o in objects){
                var val = o.getValue(prop_def);
                if(values.length==0||(!val.equals(values[0]))){
                    values.push(val);
                }
            }            
            if(values.length == 1 || prop_def.type==MULTI){
                switch prop_def.type {
                    case INT: prop.type = "number"; prop.precision = 0;
                    case FLOAT: prop.type = "number"; prop.precision = 2;
                    case STRING: prop.type = "text";
                    case BOOL: prop.type = "boolean";
                    case REFS:
                        prop.addComponent(new UIMultiNotSupported());
                    case COLOR: prop.type = "color";
                    case REF:
                        prop.type = "list";
                        var ds = new ArrayDataSource<{text:String, value:ThingID}>();
                        ds.add({text:"None", value:Reference.EMPTY_ID});
                        for(n in construct?.getChildrenRecursive(true).Nodes()){
                            ds.add({text:n.name, value:n.guid});
                        }
                        prop.dataSource=ds;
                        var s = objects[0].getValue(prop_def).entityValue(objects[0]);
                        prop.registerEvent(UIEvent.READY, e->{
                            var drop = e.target.findComponent(null, DropDown, true);
                            var val = {text:"None", value:Reference.EMPTY_ID};
                            if(s!=null){
                                val={text:s.name, value:s.guid};
                            }
                            drop.unregisterEvents(UIEvent.CHANGE);
                            //objects[0].setValue(prop_def, REF(val.value));
                            drop.selectedItem = val;
                            drop.onChange = e->{
                                var val:{text:String, value:ThingID} = drop.selectedItem;
                                for(o in objects){
                                    o.setValue(prop_def, REF(val.value));
                                }
                                Comms.sendDebounced(PROPERTY_VALUE_CHANGED(prop_def, objects), "PropExpOnChangeClosure", 100, this);
                                // Comms.send(PROPERTY_VALUE_CHANGED(prop_def, objects));
                            }
                        });
                    case SELECT:
                        prop.type = "list";
                        var ds = new ArrayDataSource();
                        var id:Int = 0;
                        for(o in prop_def.options) ds.add({text:o, value:id++});
                        prop.dataSource = ds;
                        prop.registerEvent(UIEvent.READY, e->
                        {
                            var drop = e.target.findComponent(null, DropDown, true);
                            drop.unregisterEvents(UIEvent.CHANGE);
                            drop.selectedItem = {text:prop_def.options[values[0].intValue()]??"[Invalid]", value:values[0].intValue()};
                            drop.onChange = e->{
                                var val = drop.selectedItem.value;
                                for(o in objects){
                                    o.setValue(prop_def, SELECT(val));
                                }
                                Comms.sendDebounced(PROPERTY_VALUE_CHANGED(prop_def, objects), "PropExpOnChangeClosure", 100, this);
                                // Comms.send(PROPERTY_VALUE_CHANGED(prop_def, objects));
                            }
                        });
                    case MULTI:
                        prop.value = "Edit";
                        prop.type = "action";
                    default: prop.type = "text";
                }
                switch prop_def.type {
                    case INT:
                        if(prop_def.minimum_value!=NONE) prop.min = prop_def.minValInt();
                        if(prop_def.maximum_value!=NONE) prop.max = prop_def.maxValInt();
                        if(prop_def.step_size!=NONE) prop.step = prop_def.stepValInt(); 
                    case FLOAT:
                        if(prop_def.minimum_value!=NONE) prop.min = prop_def.minValFloat();
                        if(prop_def.maximum_value!=NONE) prop.max = prop_def.maxValFloat();
                        if(prop_def.step_size!=NONE) prop.step = prop_def.stepValFloat();                
                    default:
                }
                switch prop_def.type {
                    case MULTI:
                        prop.onChange = e->{
                            var editor = new UIMultiPropEditor(prop_def, objects);
                            WindowManager.instance.addWindow(editor);
                        }
                    case REFS, REF, SELECT:
                    default:
                        prop.value = values[0].getValueAsDynamic();//getParameters()[0];
                        prop.onChange = e->{
                            var updated:Array<Entity> = [];
                            var changed:Bool = false;
                            var v = prop.value;
                            objects.iter(obj->{
                                if(obj.hasPropByDef(prop_def)){
                                    var setvalue:Dynamic = prop.value;
                                    if(setvalue!=null){
                                        //TODO And ignore change on first load!
                                        var res = obj.setValueFromDynamic(prop_def, setvalue);
                                        changed = changed||res;
                                        updated.push(obj);
                                    }
                                };
                            });
                            if(updated.length>0&&changed){
                                Comms.sendDebounced(PROPERTY_VALUE_CHANGED(prop_def, updated), "PropExpOnChangeClosure", 100, this);
                            }
                        };
                    }
            }
            else{
                switch prop_def.type {
                    case REF, REFS, UNKNOWN:
                        prop.addComponent(new UIMultiNotSupported());
                    default:
                        prop.value = "Unify Values";
                        prop.type = "action";
                        prop.onChange = _->{
                            objects.iter(obj->{
                                obj.setValue(prop_def, values[0]);
                            });
                            Comms.sendDebounced(PROPERTY_VALUE_CHANGED(prop_def, objects), "PropExpOnChangeClosure", 100, this);
                            populate();
                        }
                }

            }
            group.addComponent(prop);
        }
    }

    public function setObjects(objects:Array<Entity>){
        attached_objects = [];
        object=null;
        for(o in objects){
            attachObject(o, true);
        }
        if(objects.length==1){
            object=objects[0];
        }
        this.populate();
    }

    @:bind(add_component_btn, MouseEvent.CLICK)
    function onAddComponentClicked(e){
        if(attached_objects.length==0) return;
        if(component_type_drp.selectedItem==null) return;
        if(component_type_drp.selectedIndex==-1) return;
        var guid:String = components_drop_lookup[component_type_drp.selectedIndex].guid;
        var component = components.find(d->d.guid==guid);
        if(component==null) return;
        if(common_components.exists(c->c.isEqualTo(component))) return;
        for(obj in attached_objects){
            if(!obj.hasPropByGUID(component.guid)){
                obj.addComponent(component);
                Comms.send(ENTITY_PROPERTIES_CHANGED(obj), this);
            }
        }
    }
}

@:xml('
    <hbox width="100%">
        <textfield id="dummy" visible="false"/> 
        <label text="Multi-select not supported" verticalAlign="center"/>
    </hbox>
')
class UIMultiNotSupported extends HBox{

}

@:xml('
<hbox  width="100%" verticalAlign="center" style="padding-right: 5px;">
    <hbox width="100%">
        <label id="property_name_txt" text="${prop.name}" verticalAlign="center"/>
    </hbox>
    <label id="base_value_txt" style="color: $nord-dark4;" text="${'Base: ${owner.instanceOf?.hasPropByDef(prop)?owner.instanceOf.getValue(prop).stringValue():'None'}'}" hidden="${!owner.isComponentFromPrefab(prop.component)}"/>
    <button width="25px" height="25px" verticalAlign="center" id="commit_btn" icon="${Icon.geofence_16}" tooltip="Apply value to source prefab"/>
    <button width="25px" height="25px" verticalAlign="center" id="revert_btn" icon="${Icon.undo_16}" tooltip="Revert to prefab value"/>
</hbox>')
class PropertyLabelControl extends HBox{
    var prop:PropertyDef;
    var owner:Entity;
    public function new(prop:PropertyDef, owner:Entity){
        this.prop=prop;
        this.owner=owner;
        super();
        updateButtons();
        Comms.subscribe(PROPERTY_VALUE_CHANGED(null, null), (c, p:Dynamic)->{
            if(p==this) return;
            switch c {
                default:
                case PROPERTY_VALUE_CHANGED(property, owners):
                    if(owners.length==1&&owners[0].isEqualTo(owner)&&property.isEqualTo(prop)){
                        updateButtons();
                    }
            }
        }, this);
    }

    function updateButtons(){
        var in_timeline = !owner.changeWillAffectValue(prop);
        var is_overridden = owner.isOverridden(prop);
        revert_btn.visible=is_overridden;
        commit_btn.visible=is_overridden;
        base_value_txt.visible=is_overridden;
        revert_btn.disabled=in_timeline;
        commit_btn.disabled=in_timeline;            
    }

    override function onDestroy(){
        Comms.cleanupSubscriber(this);
        super.onDestroy();
    }
    
    @:bind(revert_btn, MouseEvent.CLICK)
    function onRevertButtonClicked(e:MouseEvent){
        owner.clearOverride(prop);
        Comms.send(PROPERTY_VALUE_CHANGED(this.prop, [this.owner]), this);
        updateButtons();
    }

    @:bind(commit_btn, MouseEvent.CLICK)
    function onCommitButtonClicked(e){
        owner.instanceOf.setValue(prop, owner.getValue(prop));
        Comms.send(REQUEST_SAVE_THING(owner.instanceOf), this);
        owner.clearOverride(prop);
        updateButtons();
    }
}

@:xml('
<property-group>
    <header verticalAlign="center" style="spacing: 5px;">
        <label id="extra_txt" style="color: $nord-blue3;" hidden="true"/>
        <button id="remove_btn" icon="${Icon.trash_16}" style="font-size: 10px; padding: 3px 6px;" />
    </header>
</property-group>
')
class PropertyGroupComponent extends PropertyGroup {
    var component:Component;
    var entities:Array<Entity>;
    var instanced:Bool=false;
    override public function new(entities:Array<Entity>, component:Component){
        super();
        this.component=component;
        this.entities=entities;
        if(entities.length==1){
            var obj = entities[0];
            instanced=obj.isComponentFromPrefab(component);
            if(instanced){
                extra_txt.hidden=false;
                extra_txt.text = 'Via ${obj.instanceOf?.name??obj.reference.getRoot().unsafeGet(obj.guid.unInstancedID).name}';
                var lbl:Label = this.findComponent(null, Label, true);
                lbl.styleString="color: $nord-blue3;";
                remove_btn.hidden=true;
            }
        }
        var removable = !component.base&&!instanced;
        if(removable){
            for(e in entities){
                for(c in e.components){
                    if(c.requirements?.exists(r->r.isEqualTo(component))){
                        removable = false;
                        break;
                    }
                }
                if(!removable){
                    break;
                }
            }
        }
        remove_btn.disabled = !removable;
    }

    @:bind(remove_btn, MouseEvent.CLICK)
    function onRemoveBtnClick(event){
        for(entity in entities){
            entity.removeComponent(component);
            Comms.send(ENTITY_PROPERTIES_CHANGED(entity), this);
        }
    }
}