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
import thinglib.timeline.Timeline.TimelineIndexedKeyframe;
import thinglib.timeline.Timeline.TimelineKeyframe;
import thinglib.property.core.CoreComponents.CoreComponentPosition;
import thinglib.component.Accessors.Region;
import thinglib.component.Accessors.RegionCorner;
import thinglib.component.Accessors.Tangible;
import thinglib.property.Override;
import pasta.Rect;
import thinglib.component.Accessors.Edge;
import thinglib.component.Accessors.Node;
import thinglib.component.Accessors.Position;
import thinglib.property.PropertyDef;
import thinglib.property.core.CoreComponents.CoreComponent;
import thinglib.storage.StorageTypes.SerializedEntity;
import h2d.Text;
import haxe.ui.components.NumberStepper;
import storage.Project;
import Comms.CommType;
import haxe.ui.components.Canvas;
import haxe.ui.events.MouseEvent;
import thinglib.component.*;
import pasta.Vect;

using Lambda;
using ArrayUtil;
using thinglib.component.util.EntityTools;
using thinglib.component.util.PropertyValueTools;

@:xml('<canvas width="100%" height="100%" style="clip:true"/>')
class UIConstructEditor extends Canvas{
	var construct:Entity;
	var project:Project;
	var stamps:Map<CoreComponent, Entity> = new Map();
	// mouse state
	var mouse:Vect = new Vect();
	var mouse_raw:Vect = new Vect();
	var mouse_down_point:Vect = new Vect();
	var mouse_up_point:Vect = new Vect();
	var mouse_is_down:Bool = false;
	var middle_mouse_is_down:Bool;
	var middle_mouse_down_point:Vect = new Vect();
	var middle_mouse_up_point:Vect = new Vect();
	var middle_mouse_dragged:Bool = false;
	var mouse_dragged:Bool = false;
	var components_moved:Bool = false;
	var mouse_square_top_left:Vect = new Vect();
	var mouse_square_width:Float = 0;
	var mouse_square_height:Float = 0;

	var selected:Array<Entity> = [];

	var candidates:Array<Entity> = [];

	// editor modifiers
	public var mod_add:Bool = false;
	public var mod_del:Bool = false;
	public var mod_ctrl:Bool = false;
	public var mod_weld:Bool = false;
    public var mod_edge:Bool = false;
	public var mod_tether:Bool = false;

	public var mode:EditorMode = SELECT;
	
	public var zoom(default, set):Float = 1;
	public var scroll:Vect = new Vect();

	public var show_grid(default, set):Bool = true;
	public var snap_grid(default, set):Bool = true;
	public var grid_size(default, set):Float = 10;

	var history:Array<HistoryStep> = [];
	var future:Array<HistoryStep> = [];
	var initial_state:HistoryStep;

	var region_drag_point:RegionDragPoint = NONE;

	//UI
	var status_text:Text;

    public function new(){
        super();
		Comms.subscribe(REQUEST_SELECT_ENTITIES(null), onComponentsSelectionRequested, this);
		Comms.subscribe(CONSTRUCT_CHANGED(null), (c, p)->{
			switch c {
				case CONSTRUCT_CHANGED(construct):
					this.construct=construct;
					recalculateEntities();
					selectComponents([]);
					clearHistory();
					pushHistory(true);
					if(project.workspacePreferences.exists(construct.name)){
						var prefs = project.workspacePreferences.get(construct.name);
						grid_size = prefs.grid_size;
						show_grid = prefs.show_grid;
						zoom = prefs.zoom;
						snap_grid = prefs.snap_grid;
						scroll = new Vect(prefs.scroll_x, prefs.scroll_y);
						Comms.send(EDITOR_VIEW_CHANGED, this);
					}
				default:
			}
		}, this);
		Comms.subscribe(PROJECT_CHANGED(null), (c, p)->{
			switch c {
				case PROJECT_CHANGED(project):
					this.project=project;
				default:
			}
		}, this);
		// Comms.subscribe(PROPERTY_VALUE_CHANGED(null, null), (c, p)->{
		// 		pushHistory();
		// 		dirty=true;
		// 	}
		// 	, this);
		Comms.subscribe(REQUEST_SAVE_EDITOR_VIEW, (c, p)->{
			switch c {
				default:return;
				case REQUEST_SAVE_EDITOR_VIEW:
			}
			if(project==null) return;
			if(construct==null) return;
			project.workspacePreferences.set(construct.name, {
					constructName: construct.name,
					zoom: zoom,
					scroll_x: scroll.x,
					scroll_y: scroll.y,
					snap_grid: snap_grid,
					grid_size: grid_size,
					show_grid: show_grid
				});
			project.save();
		}, this);
		Comms.subscribe(REQUEST_EDITOR_MODE(null), (c, p)->{
			switch c{
				default:return;
				case REQUEST_EDITOR_MODE(mode):
					this.mode = mode;
					dirty=true;
					Comms.send(EDITOR_MODE_CHANGED(mode, p), this);
			}
		}, this);
		Comms.subscribe(REQUEST_REMOVE_ENTITY(null, null), (c, p)->{
			switch(c){
				default:
				case REQUEST_REMOVE_ENTITY(target, entities):
					if(target!=this.construct){
						return;
					}
					removeEntities(target, entities);
			}
		}, this);
		Comms.subscribe(REQUEST_STAMP_CHANGE(null, false), (c, p)->{
			switch c {
				default:
				case REQUEST_STAMP_CHANGE(prefab, remove):
					var type:CoreComponent = prefab.getBaseComponent()?.guid??"";
					switch type {
						default:
							if(remove){
								if(stamps.exists(type)&&stamps.get(type)==prefab){
									stamps.remove(type);
									Comms.send(STAMPS_CHANGED(stamps.copy()), this);
								}
							}
							else{
								if(!stamps.exists(type)||stamps.get(type)!=prefab){
									stamps.set(type, prefab);
									Comms.send(STAMPS_CHANGED(stamps.copy()), this);
								}
							}
						// case UNKNOWN:
						// 	Comms.send(STAMP_SELECTION_REJECTED(prefab), this);
					}
			}
		}, this);
		Comms.subscribe(REQUEST_ADD_ENTITY(null), (c, p)->{
			switch c {
				default:
				case REQUEST_ADD_ENTITY(parent):
					addEntity(parent);
			}
		}, this);
		Comms.subscribe(REQUEST_ENTITIES_LIST, (c, p)->{
			Comms.send(PROVIDE_ENTITIES_LIST(getChildrenRecursive(construct, true), p), this);
		}, this);
		Comms.subscribe(ENTITY_ADDED(null), (_,_)->recalculateEntities(), this);
		Comms.subscribe(ENTITY_REMOVED(null), (_,_)->recalculateEntities(), this);
		Comms.subscribe(ENTITY_VISIBILITY_CHANGED(null), (_,_)->recalculateEntities(), this);
    }

	override function onDestroy(){
		Comms.cleanupSubscriber(this);
		super.onDestroy();
	}

	function set_show_grid(v):Bool{
		show_grid=v;
		dirty=true;
		return v;
	}
	function set_snap_grid(v):Bool{
		snap_grid=v;
		dirty=true;
		return v;
	}
	function set_grid_size(v):Float{
		grid_size=v;
		dirty=true;
		return v;
	}

	//group management
	// function group(){
	// 	var g = new Group("group", selected_nodes, selected_edges);
	// 	this.construct.groups.push(g);
	// }

	// #region history management
	function pushHistory(?initial:Bool=false){
		// if(initial){
		// 	initial_state = {construct:construct.serialize()};
		// 	return;
		// }
		// history.push({
		// 	construct: construct.serialize(),
		// });
		// if(future.length>0) future = [];
		// trace(history.length, future.length);
	}

	function applyHistory(step:HistoryStep){
		// construct.loadFromSerialized(construct.reference.parent, step.construct);
		// //Comms.sendDebounced(CONSTRUCT_CHANGED(construct), "UndoRedoHandler", 200, this);
		// return step;
	}

	function clearHistory(){
		history = [];
		future = [];
	}

	//Filters selections so nothing is left selected after being removed from a construct
	function sanitizeSelections(){
		selectComponents([]
			//need to make something that recurses through all children's children etc
			//selected.filter(n->construct.nodes.contains(n)),
		);
	}

	//TODO Handle case where undo redo leaves ghost in selected component arrays
	function undo(){
		// if(history.length==0){
		// 	applyHistory(initial_state);
		// 	return;
		// }
		// future.push(applyHistory(history.pop()));
		// sanitizeSelections();
		// trace(history.length, future.length);
	}

	function redo(){
		// if(future.length==0) return;
		// history.push(applyHistory(future.pop()));
		// sanitizeSelections();
		// trace(history.length, future.length);
	}
	// #endregion

    // #region mouse handlers
	// #region MouseDown
	@:bind(this, MouseEvent.MOUSE_DOWN)
	function onMouseDown(e:MouseEvent) {
		mouse_is_down = true;
		mouse_dragged = false;
		mouse_down_point.makeEqualTo(mouse);
		dirty=true;
	}
	// #endregion
	// #region MiddleMouseDown
	@:bind(this, MouseEvent.MIDDLE_MOUSE_DOWN)
	function onMiddleMouseDown(e:MouseEvent){
		middle_mouse_is_down = true;
		middle_mouse_dragged = false;
		middle_mouse_down_point.makeEqualTo(mouse_raw);
	}		
	// #endregion
	// #region MiddleMouseUp
	@:bind(this, MouseEvent.MIDDLE_MOUSE_UP)
	function onMiddleMouseUp(e:MouseEvent){
		if(!middle_mouse_is_down) return; //???
		middle_mouse_is_down = false;
		middle_mouse_up_point.makeEqualTo(mouse_raw);
	}	
	// #endregion
	// #region #MouseUp
	@:bind(this, MouseEvent.MOUSE_UP)
	function onMouseUp(e:MouseEvent) {

        if(!mouse_is_down) return; //???
		dirty=true;
		mouse_is_down = false;
		mouse_up_point.makeEqualTo(mouse);
		var c = construct;
		if (mouse_dragged) {
			if(mode==REGION){
				if(mouse_dragged){
					switch region_drag_point {
						case NONE:
							var nr = addRegion(mouse_square_top_left.x, mouse_square_top_left.y, mouse_square_width, mouse_square_height);
						case BODY(offset, region):
						case CORNER(corner):
							//Flip the region if it's been dragged inside out to prevent negative width or height
							var r = corner.region;
							var w = r.width;
							var h = r.height;
							if(w<0||h<0){
								var nr = r.asRegion();
								if(w<0){
									nr.x+=w;
									w=Math.abs(w);
								}
								if(h<0){
									nr.y+=h;
									h=Math.abs(h);
								}
								nr.width=w;
								nr.height=h;
								// (r:Entity).getBaseProp().value=RECT(nr, w, h);
							}
					}
					pushHistory();
				}
				region_drag_point = NONE;
			}
			else if (candidates.length==0) {
				var new_selection = 
					c.getChildrenRecursive(true)
					.filter(
						t->
							t.isTangible()
							&&
							t.asTangible()
							.containedByRect(mouse_square_top_left, mouse_square_width, mouse_square_height)
					);
				if (mod_ctrl) {
					new_selection = new_selection.concat(selected.filter(f -> !new_selection.contains(f)));
				}					
				selectComponents(new_selection);

			}
			if(components_moved){
				pushHistory();
				components_moved = false;
			}
			mouse_dragged==false;
		} else {
			onMouseClick(e);
		}
	}	
	// #endregion
// #region MouseClick
	function onMouseClick(e:MouseEvent) {
		var c = construct;

		if(mode==REGION){
			var region = getClosestRegion(mouse, construct.getRegionsRecursive(true));
			if(mod_ctrl&&region!=null){
				if(selected.contains(region)){
					selectComponents(selected.filter(n->n!=region));
				}
				else{
					selectComponents(selected.concat([region]));
				}
			}
			else{
				selectComponents(region==null?[]:[region]);
			}
			return;
		}
		if(mode==PATH){
			//1. Either add a raw path or the selected prefab
			var newpath = addPath(mouse.x, mouse.y);
			pushHistory();
			if(mod_ctrl) return; //Let us hold control to add paths without selecting them
			//2. Select the newly added path
			selectComponents([newpath]);
			//3. Change to 'add node' mode
			Comms.sendDebounced(REQUEST_EDITOR_MODE(ADD), "addPathFromClick", 50, this); //Debounce to avoid editor change catching mouseup
		}
		if (mod_add||mode==ADD) {
			var newnode = addNode(mouse.x, mouse.y);
			if(selected.length==0){
				selectComponents([newnode]);
			}
			pushHistory();
			return;
		}
		if (!anyCandidate()) {
            if((mod_weld||mode==WELD) && selected.length > 0){
                candidates= [addNode(mouse.x, mouse.y)];
                weldCandidate();
				if(!mod_ctrl) selectComponents(candidates);
				pushHistory();
            }
			else{
				selectComponents([]);
			}
		} else {
			if (mod_ctrl) {
				toggleCandidate();
			} else if (mod_weld||mode==WELD) {
				weldCandidate();
				pushHistory();
			} else if (mod_del||mode==DELETE) {
				deleteCandidate();
			} else {
				selectCandidate();
			}
		}
	}
// #endregion
// #region MouseMove
    @:bind(this, MouseEvent.MOUSE_MOVE)
	function onMouseMove(e:MouseEvent) {
		if(construct==null) return;

		var old_mouse = mouse.copy();
		var old_mouse_raw = mouse_raw.copy();
		mouse_raw.set(e.localX, e.localY);
		mouse.makeEqualTo(toWorldSpace(mouse_raw));
		var mouse_unsnapped = mouse.copy();
		if(snap_grid){
			mouse.snapToGrid(grid_size);
		}
		var delta = Vect.Sub(mouse, old_mouse);
		var raw_delta = Vect.Sub(mouse_raw, old_mouse_raw);
		if(middle_mouse_is_down){
			if(mouse.distanceTo(middle_mouse_down_point) > Consts.MOUSE_DRAG_DEADZONE){
				middle_mouse_dragged = true;	
			}
			if(middle_mouse_dragged){
				scroll.add(raw_delta);
				Comms.sendDebounced(REQUEST_SAVE_EDITOR_VIEW);
				dirty = true;
			}
		}

		if (mouse_is_down) {
			dirty = true;
			if (mouse.distanceTo(mouse_down_point) > Consts.MOUSE_DRAG_DEADZONE) {
				mouse_dragged = true;
				mouse_square_top_left.set(Math.min(mouse.x, mouse_down_point.x), Math.min(mouse.y, mouse_down_point.y));
				mouse_square_width = Math.abs(mouse.x - mouse_down_point.x);
				mouse_square_height = Math.abs(mouse.y - mouse_down_point.y);
			}

			if (mouse_dragged && !mod_ctrl) {
				if(mode==REGION||(selected.length==1&&selected[0].baseIs(REGION))){
					switch region_drag_point {
						case NONE:
							var c = construct;
							//if we're near a region's control points, select it for click/drag
							var regions:Array<Region> = c.getRegionsRecursive(true);
							var closest_corner:RegionCorner = null;
							var closest_corner_range:Float = Math.POSITIVE_INFINITY;
							for(r in regions){
								var corners = r.corners;
								for(corner in corners){
									var dist = corner.position.distanceTo(mouse_down_point);
									if(dist<closest_corner_range&&dist<Consts.NODE_SELECT_RADIUS){
										closest_corner = corner;
										closest_corner_range = dist;
									}
								}
							}
							if(closest_corner!=null){
								region_drag_point = CORNER(closest_corner);
							}
							else{
								var closest_center = getClosestRegion(mouse_down_point, regions);
								if(closest_center!=null){
									region_drag_point = BODY(Vect.Sub(closest_center.asPosition().global_position, mouse_down_point), closest_center);
								}
							} 
						case BODY(offset, region):
							region.asPosition().global_position = (Vect.Add(mouse, offset));
							Comms.send(PROPERTY_VALUE_CHANGED(CoreComponentPosition.x_def, [region]), this);
							Comms.send(PROPERTY_VALUE_CHANGED(CoreComponentPosition.y_def, [region]), this);
						case CORNER(corner):
							corner.region.setCorner(corner.corner, mouse);
							Comms.sendDebounced(ENTITY_PROPERTIES_CHANGED(corner.region), "RegionMovedUpdator", 200, this);
					}
				}
				else if (!anyCandidate()) {
					selectComponents([]);
				} else {
					if(candidates.length!=0){
						var candidate = candidates[0];
						if(!selected.contains(candidate)){
							selectComponents([candidate]);
						}
						var move_targets:Array<Position> = [];
						for(s in selected){
							var type:CoreComponent = s.getBaseComponent()?.guid;
							switch type {
								default:
								case NODE, PATH:
									move_targets.push(s);
								case EDGE:
									var e = s.asEdge();
									var a = e.a;
									var b = e.b;
									if(!selected.contains(a)&&!move_targets.contains(a)&&!project.isLocked(a)){
										move_targets.push(a);
									}
									if(!selected.contains(b)&&!move_targets.contains(b)&&!project.isLocked(b)){
										move_targets.push(b);
									}
								case REGION:
									move_targets.push(s);
							}
						}
						move_targets = move_targets.filter(n->!move_targets.exists(t->t!=n&&n.hasAncestor(t)));
						if(move_targets.length>0){
							for(n in move_targets){
								movePosition(n, Vect.Add(n.global_position, delta));
							}
							components_moved=true;
						}
					}
				}
			}
		} else {
			var targets = getChildrenRecursive(construct, true, true, true).filter(t->!project.isLocked(t));
			// var oldcandidates=candidates;
			candidates = targets.filter(
					t->t.isTangible()&&t.asTangible().containsPoint(mouse, getMagicValue(t, RADIUS, Consts.NODE_SELECT_RADIUS))
				);
			candidates.sort(
						(a, b)->{
						var da = a.asTangible().distanceToCenter(mouse);
						var db = b.asTangible().distanceToCenter(mouse);
						return da<db?-1:da>db?1:0;
					}
				);
			// if(oldcandidates.equalsUnsorted(candidates)){
			// 	dirty = true;
			// }
		}
	}
	// #endregion
    // #endregion

    // #region hotkey handlers
	public function onDeletePressed() {

		removeEntities(construct, selected);
		candidates=[];
		selectComponents([]);
		pushHistory();
	}

	public function onUndoPressed(){
		if(mod_ctrl){
			undo();
		}
	}

	public function onRedoPressed(){
		if(mod_ctrl){
			redo();
		}
	}

	public function onGroupPressed(){
		if(mod_ctrl){
			//group();
		}
	}

    // #endregion

    // #region node/edge logic
	function removeEntities(c:Entity, targets:Array<Entity>){
		if(targets.length==0) return;
		var secondaries:Array<Entity> = [];
		for(t in targets){
			if(t.isNode()){
				//TODO Handles the case where the root entity is an affected edge
				var affected_edges = c.getEdgesRecursive().filter(e->e.a==t||e.b==t);
				for(e in affected_edges){
					if(!secondaries.contains(e)){
						secondaries.push(e);
					}
				}
			}
			t.remove();
		} 
		if(secondaries.length>0){
			removeEntities(c, secondaries);
		}
        Comms.send(ENTITY_REMOVED(targets), this);
	}

	function addPath(x:Float, y:Float):Entity{
		var parent = selected.length==1?selected[0]:construct;
		var npos = new Vect(x, y);
		if(snap_grid){
			npos.snapToGrid(grid_size);
		}
		var n:Entity;
		if(stamps.exists(PATH)){
			var prefab = stamps.get(PATH);
			n = Entity.CreateInstance(parent, prefab);
		} 
		else{
			n = new Entity(parent);
		}
		n.addComponent(project.root.getThing(COMPONENT, CoreComponent.PATH));
		var pos = n.asPosition();
		parent.addChild(n);
		pos.global_position = new Vect(x, y);
        Comms.send(ENTITY_ADDED([n]), this);
		populateExplorer();
		return n;
	}
	function addNode(x:Float, y:Float):Entity{
		var parent = selected.length==1?selected[0]:construct;
		var npos = new Vect(x, y);
		if(snap_grid){
			npos.snapToGrid(grid_size);
		}
		var n:Entity;
		if(stamps.exists(NODE)){
			var prefab = stamps.get(NODE);
			n = Entity.CreateInstance(parent, prefab);
		} 
		else{
			n = new Entity(parent, "Node_"+thinglib.Util.name_tail());
		}
		n.addComponent(project.root.getThing(COMPONENT, CoreComponent.NODE));
		var node = n.asNode();
		parent.addChild(n);
		node.global_position = new Vect(x, y);
        Comms.send(ENTITY_ADDED([n]), this);
		populateExplorer();
		return n;
	}
	function addEntity(parent:Entity):Entity{
		parent=parent??construct;
		var n:Entity;
		if(parent.children_base_entity!=null){
			n = Entity.CreateInstance(parent, parent.children_base_entity);
		}
		else if(stamps.exists(NOT_CORE)){
			var prefab = stamps.get(NOT_CORE);
			n = Entity.CreateInstance(parent, prefab);
		} 
		else if(stamps.exists(REGION)){
			var prefab = stamps.get(REGION);
			n = Entity.CreateInstance(parent, prefab);
		}
		else{
			n = new Entity(parent);
		}
		if(parent.children_base_component!=null){
			n.addComponent(parent.children_base_component);
		}
		parent.addChild(n);
        Comms.send(ENTITY_ADDED([n]), this);
		populateExplorer();
		return n;
	}
	function addRegion(x:Float, y:Float, width:Float, height:Float):Entity{
		var parent = selected.length==1?selected[0]:construct;
		var npos = new Vect(x, y);
		if(snap_grid){
			npos.snapToGrid(grid_size);
		}
		var n:Entity;
		if(stamps.exists(REGION)){
			var prefab = stamps.get(REGION);
			n = Entity.CreateInstance(parent, prefab);
		} 
		else{
			n = new Entity(parent, "Region_"+thinglib.Util.name_tail());
			n.addComponent(project.root.getThing(COMPONENT, CoreComponent.REGION));
		}
		var pos = n.asPosition();
		parent.addChild(n);
		pos.global_position = new Vect(x, y);
		var region = n.asRegion();
		region.width = width;
		region.height = height;
        Comms.send(ENTITY_ADDED([n]), this);
		populateExplorer();
		return n;
	}
	
    function anyCandidate():Bool {
		return candidates.length>0;
	}

	function selectCandidate() {
		if (candidates.length!=0) {
			selectComponents([candidates[0]]);
		} 
		else{
			selectComponents([]);
		}
		// populateExplorer();
	}

	function toggleCandidate() {
		if(candidates.length!=0) {
			if(selected.contains(candidates[0])){
				selectComponents(selected.filter(n->n!=candidates[0]));
			}
			else{
				selectComponents(selected.concat([candidates[0]]));
			}
		} 
	}

	function deleteCandidate() {
		if (candidates.length != 0) {
			removeEntities(construct, [candidates[0]]);
			selectComponents(selected.filter(n->n!=candidates[0]));
			candidates = [];
			pushHistory();
		} //else if (edge_candidate != null) {}
	}

	function weldCandidate() {
		var parent:Entity;
		if(candidates.length==0) return;
		var candidate = candidates[0];
		if (candidate.isNode()) {
			parent = candidate;
			for(n in selected.Nodes()){
				var ent:Entity = n;
				if(ent.parent!=parent && ent!=parent){
					parent = parent.parent;
					break;
				}
			}
			if(parent==null){
				parent=construct;
			}
			var new_edges:Array<Edge> = [];
			for (n in selected.Nodes()) {
				var a:Node = n;
				var b:Node = candidate;
				if(a == b) continue;
				var already_joined = false;
				for(e in construct.getEdgesRecursive(true)){
					if((e.a==a&&e.b==b)||(e.a==b&&e.b==a)){
						already_joined = true;
						break;
					}
				}
				if(already_joined) continue;
				var newedge:Entity;
				if(stamps.exists(EDGE)){
					var prefab = stamps.get(EDGE);
					newedge = Entity.CreateInstance(parent, prefab);
					newedge.asEdge().a=a;
					newedge.asEdge().b=b;

				} 
				else{
					newedge = new Entity(parent, "Edge_"+thinglib.Util.name_tail());
					newedge.addComponent(project.root.getThing(COMPONENT, CoreComponent.EDGE));
					newedge.asEdge().a=a;
					newedge.asEdge().b=b;
				}
				parent.addChild(newedge);
				new_edges.push(newedge.asEdge());
			}
			if(new_edges.length>0){
				Comms.send(ENTITY_ADDED(new_edges), this);
				pushHistory();
			}
		} //else if (edge_candidate != null) {
		// 	// uhh we tether here?
		// 	var junction_def = ChildDef.definitions.find(d->d.name==Consts.JUNCTION_DEF);
		// 	if(junction_def==null) return;
		// 	if(selected_nodes.length == 0) return;
		// 	var build_pos = Vect.ProjectPointOnSeg(mouse, edge_candidate.a, edge_candidate.b);
		// 	var seg = edge_candidate.getSegment();
		// 	var new_node = new Node(build_pos.x, build_pos.y, project.getDefaultProps(NODE));
		// 	c.nodes.push(new_node);
		// 	var junction = new Child(new_node);
		// 	junction.definition = junction_def;
		// 	junction.initialize();
		// 	junction.properties.getByName(Consts.JUNCTION_EDGE).value = EDGE(edge_candidate.guid);
		// 	junction.properties.getByName(Consts.JUNCTION_BALANCE).value = FLOAT(seg.getBalanceOfPointOnLine(new_node));
		// 	new_node.children.list.push(junction);
		// 	var new_edges:Array<Edge> = [];
		// 	for(n in selected_nodes){
		// 		var e = new Edge(n, new_node, project.getDefaultProps(EDGE));
		// 		new_edges.push(e);
		// 		c.edges.push(e);
		// 	}
		// 	Comms.send(EDGES_ADDED(new_edges, construct), this);
		// 	Comms.send(NODES_ADDED([new_node], construct), this);
		// }
	}

	// function tether(n:Node, e:Edge){
	// 	var def:ChildDef = ChildDef.definitions.find(f->f.name==Consts.JUNCTION_DEF);
	// 	if(def==null) return;
	// 	var junc = new Child(n);
	// 	junc.definition = def;
	// 	junc.initialize();
	// }

    // #endregion

	function getClosestRegion(to:Vect, regions:Array<Region>):Region{
		var closest_center:Region = null;
		var closest_center_range:Float = Math.POSITIVE_INFINITY;
		for(r in regions){
			if(r.contains(mouse_down_point)){
				var dist = r.center.distanceTo(mouse_down_point);
				if(dist<closest_center_range){
					closest_center = r;
					closest_center_range = dist;
				}
			}
		}
		return closest_center;
	}

	function selectComponents(components:Array<Entity>){
		if(components.length==1&&selected.length==1&&components[0].isEqualTo(selected[0])) return;
		if(components.equalsUnsorted(selected)) return;
		Comms.send(REQUEST_SELECT_ENTITIES(components), this);
	}

	function onComponentsSelectionRequested(c:CommType, caller:Dynamic){
		switch c {
			case REQUEST_SELECT_ENTITIES(components):
				// if(construct == this.construct){
					selected = components.copy();
					//TODO...change all comms to use reference instead of passing objs around.
					dirty=true;
					Comms.send(SELECTED_ENTITIES_CHANGED(selected), this);
				// }
			default:
		}
	}

	function movePosition(position:Position, destination:Vect){
		movePositions([position], destination);
	}

	function movePositions(positions:Array<Position>, destination:Vect){
		for(p in positions){
			p.global_position = destination; //The abstract handles replacing these for us.
			// Comms.sendDebounced(ENTITY_PROPERTIES_CHANGED(p), "ComponentMovedUpdator", 200, this);
		}
		dirty=true;
		Comms.send(PROPERTY_VALUE_CHANGED(CoreComponentPosition.x_def, positions), this);
		Comms.send(PROPERTY_VALUE_CHANGED(CoreComponentPosition.y_def, positions), this);

	}

	public function populateExplorer(){		
		Comms.send(REQUEST_SELECT_ENTITIES(selected), this);

		
	}

    public function getStatusText():String{
		var c = construct;
		if (c == null) return "No construct loaded...";
        return 'Entities: ${c.children.length}\nModifiers: ${mod_edge ? "[Edge]" : ""}${mod_add ? "[Add]" : ""}${mod_del ? "[Del]" : ""}${mod_weld ? "[Weld]" : ""}${mod_ctrl ? "[Ctrl]" : ""}';
    }

	function getChildrenRecursive(root:Entity, includeRoot:Bool=false, excludeHidden:Bool=false, excludeLocked:Bool=false):Array<Entity>{
        if(includeRoot){
			if((excludeHidden&&project.isHidden(root))||(excludeLocked&&project.isLocked(root))){
				return [];
			}
		}
		var out = includeRoot?[root]:[];
        for(c in root.children){
			if((excludeHidden&&project.isHidden(c))||(excludeLocked&&project.isLocked(c))){
				continue;
			}
            out.push(c);
            getChildrenRecursive(c, false, excludeHidden, excludeLocked).iter(g->out.push(g));
        }
        return out;
    }


	//#region rendering

	function getMagicValue(o:Entity, prop:MagicPropType, or:Dynamic):Dynamic{
		var magicProp = project.getMagicProp(prop);
		if(magicProp=="") return or;
		if(o.hasPropByGUID(magicProp)){
			var objprop = o.getValueByGUID(magicProp);
			if(objprop!=null) return objprop.getValueAsDynamic();
		}
		return or;
	}

	function set_zoom(to:Float):Float{
		zoom = to;
		dirty = true;
		return zoom;
	}

	inline function toCameraSpace(v:Vect):Vect{
		//return v.mult(zoom).add(scroll);
		return Vect.Mult(v, zoom).add(scroll);
	}
	inline function toWorldSpace(v:Vect):Vect{
		//return v.sub(scroll).div(zoom);
		return Vect.Sub(v, scroll).div(zoom);
	}

	inline function getRenderPoint(p:Position):Vect{
		if(!rpoint.exists(p.guid)) trace("Miss!");
		return rpoint.get(p.guid)??Vect.Zero;
	}

	var allEntities:Array<Entity>;
	var visibleEntities:Array<Entity>;
	var regions:Array<Region>;
	function recalculateEntities(){
		var c = construct;
		if(c==null) return;
		allEntities = c.getChildrenRecursive(true);
		visibleEntities = getChildrenRecursive(c, true, true);
		visibleEntities.reverse();
		regions = visibleEntities.Regions();
		dirty=true;
	}

	var dirty=false;

	var rpoint:Map<String, Vect> = new Map();
	public function update():Void {
		var c = construct;
		if (c == null) return;

		//if(!dirty) return;
		recalculateEntities();
		dirty=false;
		if(c.hasPosition()){
			c.asPosition().local_position=Vect.Zero;
		}
		for(n in allEntities){
		// 	var junction = n.children.getByName(Consts.JUNCTION_DEF);
		// 	if(junction!=null){
		// 		n.makeEqualTo(
		// 			junction
		// 			.properties
		// 			.getByName(Consts.JUNCTION_EDGE)
		// 			.edgeValue(construct)
		// 			.getSegment()
		// 			.getPointByBalance(
		// 				junction.properties
		// 				.getByName(Consts.JUNCTION_BALANCE)
		// 				.floatValue()
		// 			)
		// 		);
		// 	}

			//why not update our renderpoint map here too
			if(!n.hasPosition()) continue;

			var target:Vect;
			if(rpoint.exists(n.guid)){
				target = rpoint.get(n.guid).makeEqualTo(n.asPosition().global_position);
			}
			else{
				target = n.asPosition().global_position.copy();
				rpoint.set(n.guid, target);
			}
			target.makeEqualTo(toCameraSpace(target));
		}

		var nodeColor:Int = getMagicValue(c, COLOR, Nord.blue1);
		var edgeColor:Int = getMagicValue(c, COLOR, Nord.blue2);
		var nodeRadius:Float = getMagicValue(c, RADIUS, Consts.NODE_RADIUS);
		var nodeAlpha:Float = getMagicValue(c, ALPHA, 1);
		var edgeAlpha:Float = nodeAlpha;
		var edgeThickness:Float = getMagicValue(c, THICKNESS, 1);

        var g = this.componentGraphics;
        g.clear();

		// draw!
		if(show_grid){
			g.strokeStyle(Nord.dark4, 1, 1);
			var x = 0.;
			var zoomed_grid_size = grid_size*zoom;
			while(x<this.width){
				g.moveTo(x+scroll.x%zoomed_grid_size, 0);
				g.lineTo(x+scroll.x%zoomed_grid_size, this.height);
				x+=zoomed_grid_size;
			}	
			var y = 0.;
			while(y<this.height){
				g.moveTo(0, y+scroll.y%zoomed_grid_size);
				g.lineTo(this.width, y+scroll.y%zoomed_grid_size);
				y+=zoomed_grid_size;
			}	
		}

		for(entity in visibleEntities){
			var type:CoreComponent = entity.getBaseComponent()?.guid??"";
			switch type {
				case NODE:
					g.strokeStyle(null, 0);
					var n = entity.asNode();
					var nr = getRenderPoint(n);
					g.fillStyle(getMagicValue(n, COLOR, nodeColor), getMagicValue(n, ALPHA, nodeAlpha));
					g.circle(nr.x, nr.y, getMagicValue(n, RADIUS, nodeRadius)*zoom);
				case EDGE:
					g.fillStyle(null);
					var e = entity.asEdge();
					if(!e.isComplete) continue;
					var ar = getRenderPoint(e.a);
					var br = getRenderPoint(e.b);
					g.strokeStyle(getMagicValue(e, COLOR, edgeColor), getMagicValue(e, THICKNESS, edgeThickness)*zoom, getMagicValue(e, ALPHA, edgeAlpha));
					g.moveTo(ar.x, ar.y);
					g.lineTo(br.x, br.y);
				case GROUP:
				case REGION:
					var r=entity.asRegion();
					var col = getMagicValue(r, COLOR, Nord.red);
					g.strokeStyle(col, 1*zoom, getMagicValue(r, ALPHA, 0.5)*1.5);
					g.fillStyle(col, getMagicValue(r, ALPHA, 0.2));
					var cr = getRenderPoint(entity);//toCameraSpace(r.asNode().global_position);
					var crs = new Vect(r.width, r.height).mult(zoom);
					g.rectangle(cr.x, cr.y, crs.x, crs.y);
				case PATH:
					g.fillStyle(null);
					var p = entity.asPath();
					var points = p.points;
					var pr = getRenderPoint(p);
					g.strokeStyle(getMagicValue(p, COLOR, edgeColor), getMagicValue(p, THICKNESS, edgeThickness)*zoom, getMagicValue(p, ALPHA, edgeAlpha));
					g.circle(pr.x, pr.y, getMagicValue(p, RADIUS, nodeRadius)*zoom);
					if(points.length==0) continue;
					g.moveTo(pr.x, pr.y);
					for(point in points){
						var pointr = getRenderPoint(point);
						g.lineTo(pointr.x, pointr.y);
					}
				case NOT_CORE, POSITION, TIMELINE_CONTROL:
			}
			if(entity.hasPosition()&&entity.timeline!=null&&entity.hasTimelineController()){
				var etc = entity.asTimelineControlled();
				var x_track = etc.current_state.getTrackFor(CoreComponentPosition.x_def);
				var y_track = etc.current_state.getTrackFor(CoreComponentPosition.y_def);
				if(x_track!=null&&y_track!=null){
					var positions:Array<Vect> = [];
					var xkf:Array<TimelineIndexedKeyframe> = (x_track?.getAllKeyframes())??[];
					var ykf:Array<TimelineIndexedKeyframe> = (y_track?.getAllKeyframes())??[];
					for(p in xkf){
						//positions.push(new Vect(p.get))
					}
				}
			}
		}

		for(entity in selected){
			var type:CoreComponent = entity.getBaseComponent()?.guid??"";
			switch type {
				case NODE, PATH:
					var n = entity.asPosition();
					if (visibleEntities.contains(n)) {
						g.strokeStyle(Nord.light1, 1, 0.8);
						g.fillStyle(null);
						var nr = getRenderPoint(n);
						g.circle(nr.x, nr.y, Consts.NODE_SELECT_RADIUS*zoom);
						if(type!=PATH){
							var bounds:Rect = n.getGlobalBoundingRect();
							if(bounds.width>0&&bounds.height>0){	
								var bp = toCameraSpace(new Vect(bounds.left, bounds.top));
								g.strokeStyle(Nord.red, 1, 0.8);
								g.rectangle(bp.x, bp.y, (bounds.right-bounds.left)*zoom, (bounds.bottom-bounds.top)*zoom);
							}
						}
					}
				case EDGE:
					g.strokeStyle(Nord.light1, 3, 0.8);
					var e = entity.asEdge();
					if(!e.isComplete) continue;
					if (visibleEntities.contains(e)) {
						var ar = getRenderPoint(e.a);
						var br = getRenderPoint(e.b);
						g.moveTo(ar.x, ar.y);
						g.lineTo(br.x, br.y);
					}
				case GROUP:
				case REGION:
					var r = entity.asRegion();
					var col = getMagicValue(r, COLOR, Nord.red);
					g.fillStyle(col, 0.4);
					var cr = getRenderPoint(entity);
					var crs = new Vect(r.width, r.height).mult(zoom);		
					g.rectangle(cr.x, cr.y, crs.x, crs.y);
				case NOT_CORE,POSITION,TIMELINE_CONTROL:
			}
		}

		if(mode==REGION){
			if(mouse_dragged&&mouse_is_down){
				switch region_drag_point { 
					case NONE:

					case BODY(offset, r):				
						var col = getMagicValue(r, COLOR, Nord.red);
						g.fillStyle(col, 0.4);
						var cr = toCameraSpace(r.asPosition().global_position);
						var crs = new Vect(r.width, r.height).mult(zoom);		
						g.rectangle(cr.x, cr.y, crs.x, crs.y);
					case CORNER(corner):
						g.strokeStyle(Nord.green, 1*zoom, 0.8);
						g.fillStyle(Nord.green, 0.8);
						var rcp = toCameraSpace(corner.region.getCorner(corner.corner).position); //Because the region corner is being updated, not the one in the enum
						g.circle(rcp.x, rcp.y, Consts.NODE_SELECT_RADIUS*zoom);
				}
			}
			else{
				for(r in regions){
					for(rc in r.corners){
						g.strokeStyle(Nord.green, 1*zoom, 0.8);
						g.fillStyle(null, 0);
						var rcp = toCameraSpace(rc.position);
						g.circle(rcp.x, rcp.y, Consts.NODE_SELECT_RADIUS*zoom);
					}
				}
				var closest_corner:RegionCorner = null;
				var closest_corner_range:Float = Math.POSITIVE_INFINITY;
				var closest_center:Region = null;
				var closest_center_range:Float = Math.POSITIVE_INFINITY;
				for(r in regions){
					var corners = r.corners;
					for(corner in corners){
						var dist = corner.position.distanceTo(mouse);
						if(dist<closest_corner_range&&dist<Consts.NODE_SELECT_RADIUS){
							closest_corner = corner;
							closest_corner_range = dist;
						}
					}
					if(r.contains(mouse)){
						var dist = r.center.distanceTo(mouse);
						if(dist<closest_center_range){
							closest_center = r;
							closest_center_range = dist;
						}
					}
				}
				if(closest_corner!=null){
					g.strokeStyle(Nord.green, 1*zoom, 0.8);
					g.fillStyle(Nord.green, 0.3);
					var rcp = toCameraSpace(closest_corner.position);
					g.circle(rcp.x, rcp.y, Consts.NODE_SELECT_RADIUS*zoom);
				}
				else if(closest_center!=null){
					var r = closest_center;
					var col = getMagicValue(r, COLOR, Nord.red);
					g.strokeStyle(col, 1*zoom, 0.5);
					g.fillStyle(col, 0.2);
					var cr = toCameraSpace(r.asPosition().global_position);
					var crs = new Vect(r.width, r.height).mult(zoom);
					g.rectangle(cr.x, cr.y, crs.x, crs.y);
				}
				for(r in selected.Regions()){
					var col = getMagicValue(r, COLOR, Nord.red);
					g.strokeStyle(Nord.green, 2*zoom, 0.5);
					g.fillStyle(col, 0.4);
					var cr = toCameraSpace(r.asPosition().global_position);
					var crs = new Vect(r.width, r.height).mult(zoom);
					g.rectangle(cr.x, cr.y, crs.x, crs.y);
				}
			}
		}

        if(mod_weld||mode==WELD){
			if(selected.Nodes().length>0){
				var candidate:Entity = null;
				if(candidates.length!=0){
					candidate=candidates[0];
				}
				g.fillStyle(null);
				g.strokeStyle(Nord.blue2, 1, 0.5);
				
				var p:Vect;
				if(candidate != null && candidate.isNode()) {
					p = getRenderPoint(candidate);
				}
				else{
					p = snap_grid?Vect.SnapToGrid(mouse, grid_size):mouse;
					p = toCameraSpace(p);
				}
				for(n in selected.Nodes()){
					var nr = getRenderPoint(n);
					g.moveTo(nr.x, nr.y);
					g.lineTo(p.x, p.y);
				}
			}
        }

		var highlights:Array<Entity>;
        if (selected.length == 0 && mouse_is_down && mouse_dragged && (mode != REGION  || region_drag_point == NONE)) {
			g.strokeStyle(Nord.green, 1, 0.8);
			g.fillStyle(Nord.green, 0.3);
			var ms_tl = toCameraSpace(mouse_square_top_left.copy());
			var ms_w = mouse_square_width*zoom;
			var ms_h = mouse_square_height*zoom;
			g.rectangle(ms_tl.x, ms_tl.y, ms_w, ms_h);
            g.fillStyle(null);

            highlights = visibleEntities.filter(e->e.isTangible()&&e.asTangible().containedByRect(mouse_square_top_left, mouse_square_width, mouse_square_height));
		}
		else{
			highlights = candidates.length==0?[]:[candidates[0]];
		}
		for(e in highlights){
			var type:CoreComponent = e.getBaseComponent()?.guid??"";
			switch type {
				case NODE, PATH:
					g.fillStyle(null);
					g.strokeStyle(Nord.green, 1);
					var nr = getRenderPoint(e);
					g.circle(nr.x, nr.y, Consts.NODE_SELECT_RADIUS*zoom);
				case EDGE:
					var edge=e.asEdge();
					g.fillStyle(null);
					g.strokeStyle(Nord.green, 3, 0.5);
					var ar = getRenderPoint(edge.a);
					var br = getRenderPoint(edge.b);                    
					g.moveTo(ar.x, ar.y);
					g.lineTo(br.x, br.y);
				case GROUP:
				case REGION:
					var r:Region = e.asRegion();
					var col = getMagicValue(r, COLOR, Nord.red);
					g.strokeStyle(col, 1*zoom, 0.5);
					g.fillStyle(col, 0.2);
					var cr = toCameraSpace(r.asPosition().global_position);
					var crs = new Vect(r.width, r.height).mult(zoom);
					g.rectangle(cr.x, cr.y, crs.x, crs.y);
				case NOT_CORE,POSITION,TIMELINE_CONTROL:
			}
		}
		// //draw origin widget
		// var cr = toCameraSpace(c.origin.copy());
		// g.strokeStyle(Nord.yellow, 1, 0.8);
		// g.moveTo(cr.x-5, cr.y-5);
		// g.lineTo(cr.x+5, cr.y+5);
		// g.moveTo(cr.x+5, cr.y-5);
		// g.lineTo(cr.x-5, cr.y+5);

		// //temp draw groups
		// for(c in construct.groups){
		// 	var t:Float = 999999;
		// 	var l:Float = 999999;
		// 	var b:Float = -999999;
		// 	var r:Float = -999999;
		// 	for(n in c.nodes??[]){
		// 		var rad:Float = getMagicValue(n, RADIUS, nodeRadius);
		// 		t=n.y-rad<t?n.y-rad:t;
		// 		l=n.x-rad<l?n.x-rad:l;
		// 		b=n.y+rad>b?n.y+rad:b;
		// 		r=n.x+rad>r?n.x+rad:r;
		// 	}
		// 	g.strokeStyle(Nord.red, 1, 0.8);
		// 	var tl = toCameraSpace(new Vect(l, t));
		// 	g.rectangle(tl.x, tl.y, (r-l)*zoom, (b-t)*zoom);
		// }
	}
}
//#endregion

typedef HistoryStep = {
	construct:SerializedEntity,
}

enum EditorMode {
	ADD;
	DELETE;
	SELECT;
	WELD;
	EDGE;
	REGION;
	PATH;
	TETHER;
}

enum RegionDragPoint{
	NONE;
	BODY(offset:Vect, region:Region);
	CORNER(corner:RegionCorner);
}
