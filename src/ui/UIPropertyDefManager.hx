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

import thinglib.property.core.CoreComponents;
import thinglib.property.core.CoreComponents.CoreComponentPosition;
import haxe.ui.containers.TreeView;
import haxe.ui.containers.windows.Window;
import haxe.ui.containers.windows.WindowManager;
import haxe.ui.events.ItemEvent;
import haxe.ui.events.MouseEvent;
import haxe.ui.events.UIEvent;
import thinglib.property.Component;
import thinglib.Util.ThingID;
import haxe.ui.containers.properties.Property;
import haxe.ui.containers.properties.PropertyGroup;
import storage.Project;
using Lambda;

@:xml('
<window title="Component Manager" width="680" height="500">
    <hbox width="100%">
        <textfield width="100%" id="newlist_txt" placeholder="Component Name"/>  
        <button id="newlist_btn" text="Create Component" disabled="${newlist_txt.text==''}"/>
    </hbox>    
    <tree-view width="100%" height="100%" id="prop_def_tree" styleName="full-width">
        <item-renderer layout="horizontal" width="100%">
            <label id="text" width="100" verticalAlign="center"/>
            <hbox style="background-color: $solid-background-color-alt;border-radius:3px;padding: 1px 3px" verticalAlign="center">
                <label id="type_txt" style="color:#888888;font-size: 12px;" width="40" horizontalAlign="center"/>
            </hbox>
            <button id="deleteprop_btn" text="Delete" height="20"/>
            <button id="editprop_btn" text="Edit" height="20"/>
            <!-- <label text="Default: " verticalAlign="center"/>
            <checkbox id="default_node_chk" text="Node" verticalAlign="center" />
            <checkbox id="default_construct_chk" text="Construct" verticalAlign="center" />
            <checkbox id="default_group_chk" text="Group" verticalAlign="center" />
            <checkbox id="default_region_chk" text="Region" verticalAlign="center" /> -->
        </item-renderer>
        <item-renderer id="expandable" layout="horizontal" width="100%">
            <hbox width="100%">        
                <image resource="res/icons/line.png" verticalAlign="center" />
                <label id="text" verticalAlign="center" width="20%"/>
                <checkbox id="user_selectable_chk" text="Selectable" verticalAlign="center" />
                <button text="Dependencies" id="dependencies_btn" height="20"/>
                <button text="Add Prop" id="addprop_btn" height="20"/>
            </hbox>
        </item-renderer>
    </tree-view>
</window>
')
class UIPropertyDefManager extends Window{
    var project:Project;
    public function new(project:Project){
        super();
        this.project = project;
        this.newlist_txt.restrictChars="a-zA-Z0-9_";
        Comms.subscribe(COMPONENTS_CHANGED(null), (c, p)->{
            switch c {
                case COMPONENTS_CHANGED(project):
                    this.project = project;
                    populate(project.root.getAll(Component));
                default:
            }
        }, this);
        Comms.send(REQUEST_ENUMERATE_COMPONENTS, this);
    }

    override function onDestroy(){
        Comms.cleanupSubscriber(this);
        super.onDestroy();
    }

    function populate(components:Array<Component>){
        prop_def_tree.unregisterEvents(ItemEvent.COMPONENT_EVENT);
        for(n in prop_def_tree.getNodes()){
            prop_def_tree.removeNode(n);
        }
        for(component in components.filter(c->!c.base&&c.guid!=CoreComponent.POSITION&&c.guid!=CoreComponent.TIMELINE_CONTROL)){
            var listnode = prop_def_tree.addNode({
                text:component.name, 
                list:component, 
                user_selectable_chk:component.user_selectable,
            });
            listnode.expanded = true;
            for(prop_def in component.definitions){
                listnode.addNode({
                    text:prop_def.name, 
                    type_txt:prop_def.type, 
                    prop:prop_def, 
                    list:component, 
                });
            }
            if(component.definitions.length==0){
                listnode.addNode({text:"No properties..."}).disabled=true;
            }
        }
        prop_def_tree.registerEvent(UIEvent.READY, e->{
            prop_def_tree.registerEvent(ItemEvent.COMPONENT_EVENT, function(event:ItemEvent) {
                switch(event.source.id){
                    case "addprop_btn":
                        WindowManager.instance.addWindow(new UIPropertyDefEditor(event.data.list));
                    case "editprop_btn":
                        WindowManager.instance.addWindow(new UIPropertyDefEditor(event.data.list, EDIT(event.data.prop)));
                    case "dependencies_btn":
                        WindowManager.instance.addWindow(new UIComponentDependencyManager(event.data.list, project.root.getAll(Component), 
                            res->{
                                switch res {
                                    case SAVE(c):
                                        project.storage.save(c.filename, c);
                                    case CANCEL(c):
                                        project.storage.createFromFile(Component, project.root, c.filename);
                                }
                            }
                        ));
                    case "deleteprop_btn":
                        var target = event.data.prop;
                    case "user_selectable_chk":
                        var comp:Component = event.data.list;
                        comp.user_selectable = event.source.value;
                        project.storage.save(comp.filename, comp);
                    default:
                }
            });
        });

    }

    @:bind(newlist_btn, MouseEvent.CLICK)
    public function createPropList(e){
        if(newlist_txt.text=="") return;
        var newpropdeflist = new Component(project.root, newlist_txt.text);
        project.storage.save(newpropdeflist.filename, newpropdeflist);
        Comms.send(REQUEST_ENUMERATE_COMPONENTS, this);
        newlist_txt.text="";
    }
}


@:xml('
<window title="Component Dependency Editor" width="680" height="500">>
    
    <property-grid id="components_grd" width="100%" height="100%">
    </property-grid>
    <hbox>
        <button id="save_btn" text="Save"/>
        <button id="cancel_btn" text="Cancel"/>
    </hbox>
</window>
')
class UIComponentDependencyManager extends Window{
    var props:Array<{prop:Property, comp:Component}>;
    var group:PropertyGroup;
    var components:Array<Component>;
    var component:Component;
    var callback:ComponentDependencyManagerResult->Void;
    override public function new(component:Component, components:Array<Component>, callback:ComponentDependencyManagerResult->Void){
        super();
        this.component=component;
        this.components=components;
        this.callback=callback;
        populate();
    }

    @:bind(save_btn, MouseEvent.CLICK)
    function onSaveButtonClicked(e){
        callback(SAVE(component));
        WindowManager.instance.closeWindow(this);
    }

    @:bind(cancel_btn, MouseEvent.CLICK)
    function onCancelButtonClicked(e){
        callback(CANCEL(component));
        WindowManager.instance.closeWindow(this);
    }

    function populate(){
        if(group!=null){
            components_grd.removeComponent(group);
        }
        var group = new PropertyGroup();
        props=[];
        for(c in components){
            if(c.isEqualTo(component)){
                continue;
            }
            var prop = new Property();
            prop.type="boolean";
            prop.label = c.name;

            prop.onChange = e->{
                if(prop.value){
                    if(!component.requires(c)){
                        component.require(c);
                    }
                }
                else{
                    component.removeRequirement(c);
                }
                refresh();
            }
            group.addComponent(prop);
            props.push({prop:prop, comp:c});
        }
        components_grd.addComponent(group);
        refresh();
    }

    function refresh(){
        var upstreams = component.listRequirementsRecursive();
        for(prop in props){
            prop.prop.disabled=false;
            var base_req = upstreams.find(r->r.base);
            if(prop.comp.base&&base_req!=null&&!base_req.isEqualTo(prop.comp)){
                prop.prop.value=false;
                prop.prop.disabled=true;
            }
            else{
                if(component.requires(prop.comp)){
                    prop.prop.value=true;
                }
                if(component.requiresUpstream(prop.comp)){
                    prop.prop.value=true;
                    prop.prop.disabled=true;
                }
            }
        }   
    }
}

enum ComponentDependencyManagerResult{
    SAVE(c:Component);
    CANCEL(c:Component);
}