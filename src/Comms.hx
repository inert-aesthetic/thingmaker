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
package;

import haxe.ui.containers.TreeViewNode;
import ui.UIEntityHierarchy.TreeNodeData;
import debug.Logger;
import thinglib.property.core.CoreComponents.CoreComponent;
import thinglib.Thing;
import ui.UIConstructEditor.EditorMode;
import haxe.ui.notifications.NotificationType;
import haxe.ui.notifications.NotificationManager;
import haxe.Timer;
import thinglib.property.Property;
import storage.Project;
import thinglib.property.Component;
import thinglib.property.PropertyDef;
import thinglib.component.*;
using Lambda;
using haxe.EnumTools;

class Comms{
    //TODO implement event queue here that isn't overengineered
    //Concept: Handlers return false if they don't want to be here anymore.
    public static var log = new Logger("Comms", WARN, NONE);
    static var subscriptions:Map<String, Array<Subscription>> = new Map();
    static var debounce_queue:Map<String, Timer> = new Map();
    static var queue:Array<{call:CommType, caller:Dynamic}> = [];
    static var in_call:Bool = false;
    public static function subscribe(comm_type:CommType, callback:CommHandler, subscriber:Dynamic){
        var typename = comm_type.getName();
        if(subscriptions.exists(typename)){
            subscriptions.get(typename).push({subscriber:subscriber, callback:callback});
        }
        else{
            subscriptions.set(typename, [{subscriber:subscriber, callback:callback}]);
        }
    }
    public static function unsubscribe(comm_type:CommType, callback:CommHandler, subscriber:Dynamic=null){
        var typename = comm_type.getName();
        if(subscriptions.exists(typename)){
            subscriptions.get(typename).iter(sub->{
                if(sub.subscriber == subscriber && sub.callback == callback){
                    subscriptions.get(typename).remove(sub);
                }
            });
        }
    }

    public static function cleanupSubscriber(subscriber:Dynamic){
        subscriptions.array().iter(arr->{
            arr.iter(sub->{
                if(sub.subscriber==subscriber){
                    arr.remove(sub);
                }
            });
        });
    }

    public static function send(comm_type:CommType, ?caller:Dynamic){
        log.verbose("Event fired: "+comm_type+" by "+(Std.string(caller)??"anon"));
        if(!in_call){
            in_call = true;
            var typename = comm_type.getName();
            if(subscriptions.exists(typename)){
                var subscribers = subscriptions.get(typename);
                for(subscriber in subscribers){
                    subscriber.callback(comm_type, caller);
                }
            }
            in_call = false;
            if(queue.length>0){
                log.verbose(queue.length+" calls in queue: "+queue.join(', '));
                var queue_item = queue.shift();
                send(queue_item.call, queue_item.caller);
            }
        }
        else{
            queue.push({call:comm_type, caller:caller});
        }
    }

    public static function sendDebounced(comm_type:CommType, ?signature:String, delay:Int=1000, ?caller:Dynamic){
        var sig = signature??comm_type.getName();
        if(debounce_queue.exists(sig)){
            var curtimer = debounce_queue.get(sig);
            curtimer.stop();
        }
        debounce_queue.set(sig, Timer.delay(()->{
            log.verbose('Fired after delay: ${sig}');
            send(comm_type, caller);
        }, delay));
    }

    public static function toast(type:NotificationType, body:String, title:String=null){
        NotificationManager.instance.addNotification({body: body, title: title, type: type});
    }
}


typedef CommHandler = (CommType, Dynamic)->Void;
typedef Subscription = {subscriber:Dynamic, callback:CommHandler};

enum CommType{
    PROJECT_CHANGED(project:Project);
    CONSTRUCT_CHANGED(construct:Entity);
    SELECTED_ENTITIES_CHANGED(entities:Array<Entity>);
    REQUEST_SELECT_ENTITIES(entities:Array<Entity>);
    REQUEST_ADD_ENTITY(parent:Entity);
    ENTITY_ADDED(entities:Array<Entity>);
    ENTITY_REMOVED(entities:Array<Entity>);
    ENTITY_VISIBILITY_CHANGED(entities:Array<Entity>);
    REQUEST_REMOVE_ENTITY(construct:Entity, entities:Array<Entity>);
    REQUEST_SAVE_CONSTRUCT(construct:Entity);
    REQUEST_SAVE_THING(thing:Thing);
    REQUEST_CHANGE_CONSTRUCT;
    REQUEST_STARTUP_CONSTRUCT;
    REQUEST_ENUMERATE_CONSTRUCTS;
    REQUEST_STAMP_CHANGE(prefab:Entity, remove:Bool);
    STAMPS_CHANGED(prefabs:Map<CoreComponent, Entity>);
    STAMP_SELECTION_REJECTED(prefab:Entity);
    AVAILABLE_CONSTRUCTS_CHANGED(construct_names:Array<Entity>, project:Project);
    REQUEST_CHANGE_PROJECT;
    REQUEST_ENUMERATE_COMPONENTS;
    COMPONENT_ENUMERATION_COMPLETE(defs:Map<String, PropertyDef>, def_lists:Array<Component>);
    COMPONENTS_CHANGED(project:Project);
    PROPERTY_VALUE_CHANGED(property:PropertyDef, owners:Array<Entity>);
    ENTITY_PROPERTIES_CHANGED(obj:Entity);
    ENTITY_NAME_CHANGED(obj:Entity);
    REQUEST_SAVE_EDITOR_VIEW;
    EDITOR_VIEW_CHANGED;
    REQUEST_MULTI_EDIT_RELOAD;
    REQUEST_EDITOR_MODE(mode:EditorMode);
    EDITOR_MODE_CHANGED(target:EditorMode, initiator:Dynamic);
    REQUEST_ENTITIES_LIST;
    PROVIDE_ENTITIES_LIST(components:Array<Entity>, for_caller:Any);
    REQUEST_ENTITY_HIERARCHY_MENU(tree_node:TreeViewNode, entity:Entity, construct:Entity, mouse_x:Float, mouse_y:Float);
    REQUEST_CUT_ENTITY(entity:Entity);
    REQUEST_PASTE_ENTITY(entity:Entity);
}