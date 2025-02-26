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

import haxe.ui.util.Timer;
import haxe.ui.core.Screen;
import haxe.ui.events.MenuEvent;
import haxe.ui.containers.menus.Menu;
import thinglib.Util.ThingID;
import haxe.ui.containers.TreeViewNode;
import haxe.ui.containers.VBox;
import storage.Project;
import haxe.ui.events.UIEvent;
import haxe.ui.events.ItemEvent;
import Comms.CommType;
import thinglib.component.*;
using Lambda;
using thinglib.component.util.EntityTools;
using thinglib.component.util.PropertyValueTools;

@:build(haxe.ui.ComponentBuilder.build("res/ui/entity_hierarchy.xml"))
class UIEntityHierarchy extends VBox{
    var construct:Entity;
    var project:Project;

    var rightclick_buffer:Array<CommType> = [];
    var rightclick_handle_timer:Timer;

    var to_cut_entity:Entity;

    var selected:Array<Entity> = [];
    public var internal_request:Bool = false;
    public function new(){
        super();

        Comms.subscribe(SELECTED_ENTITIES_CHANGED(null), commsHandler, this);
        Comms.subscribe(CONSTRUCT_CHANGED(null), commsHandler, this);
        Comms.subscribe(ENTITY_ADDED(null), commsHandler, this);
        Comms.subscribe(ENTITY_REMOVED(null), commsHandler, this);
        Comms.subscribe(PROJECT_CHANGED(null), commsHandler, this);
        Comms.subscribe(ENTITY_NAME_CHANGED(null), commsHandler, this);
        Comms.subscribe(REQUEST_ENTITY_HIERARCHY_MENU(null, null, null, 0, 0), (c, p)->{
            switch c {
                default:
                case REQUEST_ENTITY_HIERARCHY_MENU(tree_node, entity, construct, mouse_x, mouse_y):          
                    var menu = new UIEntityHierarchyContextMenu(construct, entity, project, tree_node, to_cut_entity);
                    menu.left = mouse_x;
                    menu.top = mouse_y;
                    Screen.instance.addComponent(menu);
            }
        }, this);
        Comms.subscribe(REQUEST_CUT_ENTITY(null), commsHandler, this);
        Comms.subscribe(REQUEST_PASTE_ENTITY(null), commsHandler, this);
        // registerEvent(ItemEvent.COMPONENT_CLICK_EVENT, (event:ItemEvent)->{
        //     //trace(event.source.id, event.source.value, event.sourceEvent.type, event.data);
        //     switch(event.source.id){                    
        //         default:
        //     }
        // });
        
    }

    override function onDestroy(){
        Comms.cleanupSubscriber(this);
        super.onDestroy();
    }

    @:bind(tree, UIEvent.CHANGE)
    function onTreeNodeSelect(e){
        if(internal_request){
            internal_request = false;
            return;
        }
        if(tree.selectedNode==null) return;
        var obj = project.root.getThing(ENTITY, tree.selectedNode.data.id);
        if(obj==null){
            Comms.toast(Error, "The selected node references an Entity not found on the project's root structure.", "Unable to select Entity");
        }
        else{
            Comms.send(REQUEST_SELECT_ENTITIES([obj]), this);
        }
    }

    function commsHandler(e:CommType, caller:Dynamic):Void{
        switch e {
            case CONSTRUCT_CHANGED(construct):
                onConstructChanged(construct);
            case SELECTED_ENTITIES_CHANGED(entities):
                onComponentsSelected(entities);
            case ENTITY_NAME_CHANGED(entity):
                var target = findNodeByEntity(entity);
                if(target!=null){
                    var d:TreeNodeData = target.data;
                    d.text=entity.name;
                    target.data=d;
                    target.invalidateComponent();
                }
            case PROJECT_CHANGED(project):
                this.project = project;
            case ENTITY_ADDED(entities):
                for(e in entities){
                    var parent = findNodeByEntity(e.parent);
                    var index = e.getChildIndex();
                    if(parent!=null){
                        var newnode = parent.addNode(null);
                    
                        addEntityNode(newnode, e);
                    }
                }   
            case ENTITY_REMOVED(entities):
                for(e in entities){
                    var parent = findNodeByEntity(e.parent);
                    if(parent!=null){
                        var target = findNodeByEntity(e, parent);
                        parent.removeNode(target);
                    }
                }  
            case REQUEST_CUT_ENTITY(entity):
                to_cut_entity = entity;
            case REQUEST_PASTE_ENTITY(entity):
                if(to_cut_entity==null||to_cut_entity==entity) return;
                var paste_node = findNodeByEntity(entity);
                if(paste_node==null) return;
                var cut_node_parent = findNodeByEntity(to_cut_entity.parent);
                if(entity.addChild(to_cut_entity)){
                    if(cut_node_parent!=null){
                        var target = findNodeByEntity(to_cut_entity, cut_node_parent);
                        cut_node_parent.removeNode(target);
                    }
                    var new_node = paste_node.addNode(null);
                    addEntityNode(new_node, to_cut_entity);
                    // paste_node.addNode(cut_node);
                }

            default:
        }
    }

    function findNodeByEntity(e:Entity, start:TreeViewNode=null):TreeViewNode{
        var ret:TreeViewNode = null;
        var nodes = start?.getNodes()??tree.getNodes();
        for(n in nodes){
            var d:TreeNodeData = n.data;
            if(d.id==e.guid){
                ret = n;
            }
            else{
                ret = findNodeByEntity(e, n);
            }
            if(ret!=null){
                break;
            }
        }
        return ret;
    }

    function onComponentsSelected(entities:Array<Entity>):Void{
        selected = entities;
        tree.selectedNode=null;
        if(entities.length==1){
            var treenodes = tree.getNodes();
            var targetnode:TreeViewNode = null;
            for(treenode in treenodes){ 
                targetnode = findMatchingNode(treenode, entities[0]);
                if(targetnode!=null){
                    break;
                }
            }
            tree.selectedNode=targetnode;
            internal_request = true;
        }
    }

    function findMatchingNode(node:TreeViewNode, entity:Entity):TreeViewNode{
        var nodeData:TreeNodeData = node.data;
        if(nodeData.id==entity.guid){
            return node;
        }
        else{
            if(node.getNodes().length>0){
                for(n in node.getNodes()){
                    var res = findMatchingNode(n, entity);
                    if(res!=null){
                        return res;
                    }
                }
            }
        }
        return null;
    }

    function onConstructChanged(construct:Entity):Void{
        if(construct==null) return;
        this.construct = construct;
        buildTree();
    }

    function buildTree(){
        tree.clearNodes();
        tree.unregisterEvents(ItemEvent.COMPONENT_EVENT);
        if(construct==null) return;      
        addEntityNode(tree.addNode(null), construct);
    }

	function moveEntityUp(entity:Entity){
		var pos = entity.getChildIndex();
        var parent = entity.parent;
        if(parent==null){
            return;
        }
		if(pos>0&&pos<entity.parent?.children.length??-1){
			entity.parent.setIndexOfChild(entity, pos-1);
		}
        // else if(pos==0){
        //     var grandparent = parent.parent;
        //     if(grandparent==null){
        //         return;
        //     }
        //     parent.removeChild(entity);
        //     grandparent.addChild()
        // }
	}
	function moveEntityDown(entity:Entity){
		var pos = entity.getChildIndex();
        var parent = entity.parent;
        if(parent==null){
            return;
        }
		if(pos>0&&pos<entity.parent?.children.length??-1){
			entity.parent.setIndexOfChild(entity, pos+1);
		}
	}

    function addEntityNode(root:TreeViewNode, obj:Entity){
        var isInstance = obj.isFromInstance||obj.instanceOf!=null;
        root.data={
            text:obj.name, 
            id:obj.guid, 
            icon: Icon.ForBaseType(obj.getBaseComponent()?.guid??"", SMALL),
            styleNames:isInstance?'tree-element-instance':'tree-element',
            hide_btn:{selected:project.isHidden(obj), 
                onClick:(_)->{
                    project.toggleHidden(obj);
                    Comms.send(ENTITY_VISIBILITY_CHANGED([obj]), this);
                    Comms.send(REQUEST_SAVE_EDITOR_VIEW, this);
                }
            },
            lock_btn:{selected:project.isLocked(obj), 
                onClick:(_)->{
                    project.toggleLocked(obj);
                    Comms.send(REQUEST_SAVE_EDITOR_VIEW, this);
                }
            },
            up_btn:{
                onClick:(_)->{
                    moveEntityUp(obj);
                }
            },
            down_btn:{
                onClick:(_)->{
                    moveEntityDown(obj);
                }
            }
        };
        obj.children?.iter(n->{
            addEntityNode(root.addNode(null), n);
        });
        root.expanded=!isInstance;
        //The order is not guaranteed... instead, we need to make a custom way to grab the deepest in the list, I guess.
        root.onRightClick = e-> {
            if(rightclick_handle_timer!=null){
                rightclick_handle_timer.stop();
            }
            rightclick_buffer.push(REQUEST_ENTITY_HIERARCHY_MENU(root, obj, construct, e.screenX, e.screenY));
            rightclick_handle_timer = Timer.delay(()->{
                var deepest:CommType = null;
                var depth = -1;
                for(e in rightclick_buffer){
                    switch e {
                        default:
                            Comms.log.error('Something other than a rightclick request in buffer: $e.');
                        case REQUEST_ENTITY_HIERARCHY_MENU(tree_node, entity, construct, mouse_x, mouse_y):
                            var e_depth = 0;
                            var p = entity.parent;
                            while(p!=null){
                                p=p.parent;
                                e_depth++;
                            }
                            if(e_depth>depth){
                                deepest = e;
                                depth = e_depth;
                            }
                    }
                }
                if(deepest!=null){
                    Comms.send(deepest, this);
                    rightclick_buffer = [];
                }
            }, 2);
        };
    }
}

typedef TreeNodeData = {text:String, icon:String, id:ThingID};

@:xml('
<menu>
    <label text="${entity.name}"/>
    <menuseparator />
    <menu-item id="add_itm" text="Add child"/>
    <menu-item id="folder_itm" text="Modify child constraints" hidden="${entity.isFromInstance||entity.instanceOf!=null}"/>
    <menuseparator />
    <menu-item id="prefab_itm" text="Convert to prefab" hidden="${entity.isFromInstance||entity.instanceOf!=null}"/>
    <menuseparator />
    <menu-item id="cut_itm" text="Cut" hidden="${entity.isEqualTo(construct)||entity.isFromInstance}"/>
    <menu-item id="paste_itm" text="Paste" disabled="${to_cut_entity==null||to_cut_entity.isEqualTo(entity)||!entity.canAcceptChild(to_cut_entity)}"/>
    <menu-item id="rename_itm" text="Rename" hidden="${entity.isFromInstance}"/>
    <menu-item id="remove_itm" text="Remove" hidden="${entity.isEqualTo(construct)||entity.isFromInstance}"/>
</menu>
')
class UIEntityHierarchyContextMenu extends Menu{
    var construct:Entity;
    var entity:Entity;
    var tree_node:TreeViewNode;
    var project:Project;
    var to_cut_entity:Entity;
    
    public function new(construct:Entity, entity:Entity, project:Project, tree_node:TreeViewNode, ?to_cut_entity:Entity=null){
        this.entity=entity;
        this.tree_node=tree_node;
        this.construct=construct;
        this.project=project;
        this.to_cut_entity = to_cut_entity;
        super();
    }

    @:bind(this, MenuEvent.MENU_SELECTED)
    function onRemoveSelected(e:MenuEvent){
    
        switch(e.menuItem.id){
            case "cut_itm":
                Comms.send(REQUEST_CUT_ENTITY(entity), this);
            case "paste_itm":
                Comms.send(REQUEST_PASTE_ENTITY(entity), this);
            case "add_itm":
                Comms.send(REQUEST_ADD_ENTITY(entity), this);
            case "remove_itm":
                Comms.send(REQUEST_REMOVE_ENTITY(construct, [entity]), this);
            case "prefab_itm":
                if(entity==construct){
                    return;
                }
                if(entity.isFromInstance){
                    trace('Error: $entity is already a prefab instance.');
                    return;
                }
                Util.convertEntityToPrefab(entity, construct, project);
            case "folder_itm":
                new UIConstraintSelectorModal
                (
                    entity,
                    project.availableConstructs,
                    project.components
                )
                .show();
            case "rename_itm":
                new UITextInputModal
                (
                    "Change Entity Name", 
                    (accepted, content)->{
                        if(!accepted) return;
                        entity.name = content;
                        Comms.send(ENTITY_NAME_CHANGED(entity), this);
                    },
                    entity.name
                )
                .show();
        }
    }
}