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

import haxe.ui.containers.dialogs.Dialog;
import thinglib.component.Entity;
import haxe.ui.events.UIEvent;
import storage.Project;
import Comms.CommType;
import haxe.ui.containers.windows.WindowManager;
import haxe.ui.events.MouseEvent;
import haxe.ui.containers.VBox;
import ui.UIConstructEditor.EditorMode;
using Lambda;

@:build(haxe.ui.ComponentBuilder.build("res/ui/editor_layout.xml"))
class UIEditorLayout extends VBox {
	var project:Project;
	var construct:Entity;
	var bouncing = false;
	public var mainview:UIConstructEditor;
	public function new() {
		super();
		this.mainview = mainview_wrapper.editor;
		Comms.subscribe(CONSTRUCT_CHANGED(null), onConstructChanged, this);
		Comms.subscribe(SELECTED_ENTITIES_CHANGED(null), onSelectedComponentsChanged, this);
		Comms.subscribe(PROJECT_CHANGED(null), (c, p)->{
			switch c {
				case PROJECT_CHANGED(project):
					this.project = project;
				default:
			}
		}, this);
		Comms.subscribe(EDITOR_VIEW_CHANGED, (c, p)->{
			switch c {
				default:return;
				case EDITOR_VIEW_CHANGED:
					zoom_stp.value = mainview.zoom;
					grid_snap_chk.value = mainview.snap_grid;
					ruler_btn.text = mainview.show_grid?"Hide Grid":"Show Grid";
					grid_stp.value = mainview.grid_size;
			}
		}, this);
		Comms.subscribe(EDITOR_MODE_CHANGED(null, null), (c, p)->{
			switch c {
				default: return;
				case EDITOR_MODE_CHANGED(target, initiator):
					if(initiator==this) return;
					bouncing = true;
					switch target {
						case ADD: mode_add_rad.selected = true;
						case DELETE: mode_delete_rad.selected = true;
						case SELECT: mode_select_rad.selected = true;
						case WELD: mode_weld_rad.selected = true;
						case EDGE: mode_edge_rad.selected = true;
						case REGION: mode_region_rad.selected = true;
						case PATH: mode_path_rad.selected = true;
						case TETHER: mode_tether_rad.selected = true;
					}
			}
		}, this);

		mode_select.onChange = (e)->{
			if(bouncing){
				bouncing = false;
				return;
			}
			var target:EditorMode = switch(e.target.text){
				case "Add": ADD;
				case "Delete": DELETE;
				case "Select": SELECT;
				case "Weld": WELD;
				case "Tether": TETHER;
				case "Region": REGION;
				case "Path": PATH;
				default:
					Comms.toast(Error, "Invalid editor mode: "+e.target.text);
					SELECT;
					return;
			}			
			Comms.send(REQUEST_EDITOR_MODE(target), this);
		}
	}

	override function onDestroy() {
		super.onDestroy();
		Comms.cleanupSubscriber(this);
	}

	function onSelectedComponentsChanged(e:CommType, caller:Dynamic):Void{
		switch(e){
			case SELECTED_ENTITIES_CHANGED(entities):
				component_prop_explorer.setObjects(entities);
			default:
		}
	}	
	function onConstructChanged(e:CommType, caller:Dynamic):Void{
		switch(e){
			case CONSTRUCT_CHANGED(construct):
				this.construct = construct;
			default:
		}
	}

	@:bind(change_construct_btn, MouseEvent.CLICK)
	function onChangeConstructClicked(e){
		Comms.send(REQUEST_CHANGE_CONSTRUCT, this);
	}

	@:bind(open_project_btn, MouseEvent.CLICK)
	function onOpenProjectClicked(e){
		Comms.send(REQUEST_CHANGE_PROJECT, this);
	}

	@:bind(save_construct_btn, MouseEvent.CLICK)
	public function onSaveConstructClicked(e){
		Comms.send(REQUEST_SAVE_CONSTRUCT(construct), this);
	}
	
    @:bind(manage_property_defs_btn, MouseEvent.CLICK)
    function onManagePropertyDefsBtnClicked(e){
        WindowManager.instance.addWindow(new UIPropertyDefManager(project));
    }

	@:bind(project_settings_btn, MouseEvent.CLICK)
	function onProjectSettingsBtnClicked(e){
		WindowManager.instance.addWindow(new UIProjectSettings(project));
	}

	@:bind(close_app_btn, MouseEvent.CLICK)
	function onCloseAppBtnClicked(e){
		Comms.send(REQUEST_CLOSE_APP, this);
	}

	@:bind(ruler_btn, MouseEvent.CLICK)
	function onRulerBtnClicked(e){
		mainview.show_grid = !mainview.show_grid;
		ruler_btn.text = mainview.show_grid?"Hide Grid":"Show Grid";
		Comms.sendDebounced(REQUEST_SAVE_EDITOR_VIEW);
	}

	@:bind(zoom_stp, UIEvent.CHANGE)
	function onZoomStpChange(e:UIEvent){
		mainview.zoom = zoom_stp.value;
		Comms.sendDebounced(REQUEST_SAVE_EDITOR_VIEW);
	}

	@:bind(grid_stp, UIEvent.CHANGE)
	function onGridStpChange(e:UIEvent){
		mainview.grid_size = grid_stp.value;
		Comms.sendDebounced(REQUEST_SAVE_EDITOR_VIEW);
	}

	@:bind(grid_snap_chk, UIEvent.CHANGE)
	function onGridSnapChkChange(e:UIEvent){
		mainview.snap_grid = grid_snap_chk.value;
		Comms.sendDebounced(REQUEST_SAVE_EDITOR_VIEW);
	}

	@:bind(help_about_btn, MouseEvent.CLICK)
	function onHelpInfoBtnClick(e:MouseEvent){
		var dia = haxe.ui.containers.dialogs.Dialogs.messageBox([
			'thingmaker copyright 2025 inert-aesthetic contact_i_a at tuta dot io',
			'Free software under GPL3 license.',
			'Source available: github.com/inert-aesthetic/thingmaker',
			'',
			'Icons from Blueprint copyright Palantir used under Apache 2.0 license.',
			'Source available: github.com/palantir/blueprint',
			'',
			'See release directory or source repositories for full license text.'
			].join('\n'), 
			'About thingmaker', 
			'info'
			);
		dia.width=700;
	}

	public function update():Void {
		mainview.update();
	}
}