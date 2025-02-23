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

import thinglib.Util;
import debug.Logger;
import uuid.Uuid;
import haxe.ui.notifications.NotificationManager;
import haxe.ui.events.UIEvent;
import sys.thread.Thread;
import Comms.CommType;
import thinglib.component.*;
import haxe.Json;
import haxe.ui.Toolkit;
import haxe.ui.core.Screen;
import hxd.*;
import storage.*;
import sys.FileSystem;
import sys.io.File;
import ui.UIEditorLayout;
using ArrayUtil;

class Main extends App{
// #region vars

    //editor ui
    public static var log = new Logger("App");
    var editor:UIEditorLayout;
    var project:Project;
    var global_prefs:GlobalPrefs;
// #endregion

    // #region startup_sequence
    override function init(){
        Comms.log.verbose.enabled=true;
        Util.log.verbose.enabled=true;
        Util.log.info.enabled=true;
        hxd.Res.initLocal();
        Toolkit.init({root:s2d});
        Toolkit.theme = 'dark';
        this.engine.backgroundColor = Nord.dark1;
        //Startup sequence
        Comms.subscribe(PROJECT_CHANGED(null), onProjectChanged);

        //hook up handlers
        Comms.subscribe(REQUEST_SAVE_THING(null), (c, p)->{
            switch c {
                case REQUEST_SAVE_THING(thing):
                    try{
                        project?.storage?.save(thing.filename, thing);
                        NotificationManager.instance.addNotification({body: '${thing.name} saved', type: Success});
                    }
                    catch(e){
                        NotificationManager.instance.addNotification({body: 'Failed to save ${thing.name}: ${e.toString()}', type: Error});
                    }
                default:
            }
        });
        Comms.subscribe(REQUEST_CHANGE_CONSTRUCT, (c, p)->doChangeConstruct());
        Comms.subscribe(REQUEST_CHANGE_PROJECT, (c, p)->doChangeProject());
        Comms.subscribe(REQUEST_SAVE_CONSTRUCT(null), (e, p)->{
            switch(e){
                case REQUEST_SAVE_CONSTRUCT(c):
                    if(c!=null){
                        try{
                            project.storage.save(c.filename, c);
                            NotificationManager.instance.addNotification({body: "Construct saved", type: Success});
                            Comms.send(REQUEST_ENUMERATE_CONSTRUCTS, this);
                        }
                        catch(e){
                            NotificationManager.instance.addNotification({body: 'Failed to save construct: ${e.toString()}', type: Error});
                        }
                    }
                default:
            }
        });
        Comms.subscribe(REQUEST_ENUMERATE_COMPONENTS, (c, p)->{
            if(project!=null){
                project.enumerateComponents();
                Comms.send(COMPONENTS_CHANGED(project), this);
            }
        });
        Comms.subscribe(REQUEST_ENUMERATE_CONSTRUCTS, (c, p)->{
            if(project!=null){
                project.enumerateConstructs();
                Comms.send(AVAILABLE_CONSTRUCTS_CHANGED(project.availableConstructs, project), this);
            }
        });

        Comms.subscribe(REQUEST_STARTUP_CONSTRUCT, (c, p)->doStartupOpenConstruct());
        initializeEditor();
        doStartupOpenProject();
    }

    function doStartupOpenProject(){
        global_prefs = new GlobalPrefs(); //either fill this with loaded data or save it as fresh
        //GlobalPrefs.setGlobalPrefs(global_prefs);
        //First look for the prefs file locally.
        if(FileSystem.exists(Util.fileName("global", Consts.FILENAME_GLOBAL_PREFS))){
            var file = File.getContent(Util.fileName("global", Consts.FILENAME_GLOBAL_PREFS));
            global_prefs.loadFromSerialized(Json.parse(file));
        }
        else{
            global_prefs.save();
        }
        project = global_prefs.tryGetLastOpenProject(); 
        if(project == null){
            doChangeProject();
        }
        else{
            //this will be dev directory, if we find a project file in it.
            log.info('Opened last open project: ${global_prefs.lastOpenProject}');
            log.info('Working directory: ${project.workingDirectory.dir}');
            Comms.send(PROJECT_CHANGED(project), this);
        }
    }

    function doChangeProject(){
        //start first run flow
        var openProjectDialog = new ui.UIOpenProjectDialog();
        openProjectDialog.onGotProject = (path, proj)->
            { //we get back a project; try to do something with it!
                proj.setWorkingDirectory(path);
                openProjectDialog.hide();
                //Close openProjectDialog modal
                //Start "open construct for editing" flow
                
                Comms.send(PROJECT_CHANGED(proj), this);
            };
        openProjectDialog.show();
    }

    function onProjectChanged(c:CommType, caller:Dynamic){
        switch c {
            case PROJECT_CHANGED(project):
                if(project==null){
                    log.error("Got weird project.");
                    return;
                }
                this.project = project;
                if(global_prefs!=null){
                    global_prefs.lastOpenProject=project.workingDirectory;
                    log.info("Saving global prefs: "+global_prefs.lastOpenProject.toString());
                    global_prefs.save();
                }
                else{
                    log.error("Global prefs were null...");
                }
                // Comms.send(COMPONENTS_CHANGED(project), this);
                // Comms.send(AVAILABLE_CONSTRUCTS_CHANGED(project.availableConstructs, project), this);
                Comms.send(REQUEST_ENUMERATE_COMPONENTS, this);
                Comms.send(REQUEST_ENUMERATE_CONSTRUCTS, this);
                Comms.send(REQUEST_STARTUP_CONSTRUCT, this);
            default:
        }
    }

    function doStartupOpenConstruct(){
        log.info("Getting initial construct for project...");
        if(project == null){
            log.error("Fatal: startup construct flow started with no current project open.");
            return;
        }
        //Now we have a project.
        if(project.lastOpenConstruct==""){
            doChangeConstruct();
        }
        else{
            //the last open construct is available -- just open it!
            var loaded = project.storage.createFromFile(Entity, project.root, Util.fileName(project.lastOpenConstruct, thinglib.Consts.FILENAME_CONSTRUCT));
            if(loaded==null){
                log.error("Fatal: Failed to open construct.");
                return; //TODO Recovery from this error
            }
            Comms.send(CONSTRUCT_CHANGED(loaded), this);
        }
    }

    function doChangeConstruct(){
        if(project.availableConstructs.length==0){
            //we never had a construct; do new construct flow
            var firstConstructDialog = new ui.UICreateConstructDialog(project);
            firstConstructDialog.onGotConstruct = (c)->{
                firstConstructDialog.hide();
                Comms.send(CONSTRUCT_CHANGED(c), this);
            }
            firstConstructDialog.show();
        }
        else{
            var selectConstructDialog = new ui.UISelectConstructDialog(project);
            selectConstructDialog.onGotConstruct = (c)->{
                selectConstructDialog.hide();

                // if we just recursively remove it...or add a 'destroy' to Entity, that would fix it?
                
                //project.root.removeThing(c);
                var reloaded = project.storage.createFromFile(Entity, project.root, c.filename);
                project.setOpenConstruct(reloaded);
                Comms.send(CONSTRUCT_CHANGED(reloaded), this);
            }
            selectConstructDialog.show();
            //show list of constructs to open
        }
    }

    function initializeEditor(){
        if(editor==null){
            editor = new UIEditorLayout();
            Screen.instance.addComponent(editor);
        }
        Window.getInstance().addEventTarget(eventDispatcher);
    }
    // #endregion

    // #region input_handlers
    function eventDispatcher(e:Event){
        switch(e.kind){
            case EKeyDown, EKeyUp: handleKeys(e);
            case EWheel: handleScrollWheel(e);
            default:
        }

    }

    function handleScrollWheel(e:Event){
        switch e.kind {
            case EWheel:
                //TODO Refactor this to be handled mostly inside mainview.
                if(editor.mainview.mod_ctrl){
                    var new_zoom = editor.mainview.zoom + (e.wheelDelta<0?0.1:-0.1);
                    if(editor.mainview.zoom!=new_zoom){
                        editor.mainview.zoom=Math.min(10, Math.max(0.2, new_zoom));
                        Comms.sendDebounced(REQUEST_SAVE_EDITOR_VIEW, null, 1000, this);
                        Comms.sendDebounced(EDITOR_VIEW_CHANGED, null, 500, this);
                    }
                }
            default:
        }
    }

    function handleKeys(e:Event){
        if(!editor.mainview_wrapper.focus) return;
        switch(e.kind){
            case EKeyDown:
                switch(e.keyCode){
                    case 65: //A
                        editor.mainview.mod_add = true;
                        Comms.send(REQUEST_EDITOR_MODE(ADD), this);
                    case 68: //D
                        editor.mainview.mod_del = true;
                        Comms.send(REQUEST_EDITOR_MODE(DELETE), this);
                    case 17: //Ctrl
                        editor.mainview.mod_ctrl = true;
                    case 46: //Delete
                        editor.mainview.onDeletePressed();
                    case 49: //1
                    case 50: //2
                    case 51: //3
                    case 52: //4
                    case 79: //O
                    case 81: //Q
                    case 87: //W
                        editor.mainview.mod_weld = true;
                        Comms.send(REQUEST_EDITOR_MODE(WELD), this);
                    case 69: //E
                        editor.mainview.mod_edge = true;
                        Comms.send(REQUEST_EDITOR_MODE(EDGE), this);
                    case 82: //R
                    case "S".code:
                        if(editor.mainview.mod_ctrl) {
                            editor.onSaveConstructClicked(null);
                        }
                        else{
                            Comms.send(REQUEST_EDITOR_MODE(SELECT), this);
                        }
                    case "T".code: 
                        editor.mainview.mod_tether = true;
                    case "Z".code: 
                        editor.mainview.onUndoPressed();
                    case "Y".code:
                        editor.mainview.onRedoPressed();
                    case "0".code:
                        if(editor.mainview.mod_ctrl){
                            editor.mainview.zoom = 1;
                            editor.mainview.scroll.makeZero();
                            Comms.sendDebounced(REQUEST_SAVE_EDITOR_VIEW, null, 1000, this);
                        }
                    case "G".code:
                        editor.mainview.onGroupPressed();
                    default: log.verbose(e.keyCode+" pressed.");
                }
            case EKeyUp:
                switch(e.keyCode){
                    case 65: //A
                        editor.mainview.mod_add = false;
                    case 68: //D
                        editor.mainview.mod_del = false;
                    case 17: //Ctrl
                        editor.mainview.mod_ctrl = false;
                    case 79: //O
                    case 87: //W
                        editor.mainview.mod_weld = false;
                    case 69: //E
                        editor.mainview.mod_edge = false;
                    case "T".code: 
                        editor.mainview.mod_tether = false;
                    default:
                }
            default:
        }
    }
    // #endregion

    override function update(dt:Float){
        super.update(dt);

        if(editor!=null){
            editor.update();
            //Sys.sleep(0.1);
        }
        /*
        var msg:CommType = Thread.readMessage(false);
        while(msg!=null){
            Comms.send(msg, this);
            msg = Thread.readMessage(false);
        }
        */
    }

    public static function main(){
        new Main();
    }   
}