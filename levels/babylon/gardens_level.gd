extends Node2D
## Geometry-only inspection scene for Babylon stage 1 (hanging gardens).
## Hero, enemies, clay, and UI are markers for the assembler. They are not simulated.

const TILE := 16
const MAP_PATH := "res://levels/babylon/gardens_map.txt"
const CONTRACT_PATH := "res://levels/babylon/gardens_contract.json"
const FONT_PATH := "res://levels/babylon/fonts/NotoNaskhArabic-Regular.ttf"

const COLOR_SKY := Color("c7ebda")
const COLOR_SKY_TOP := Color("f3ddb8")
const COLOR_DIRT := Color("8c5a34")
const COLOR_GRASS := Color("3f8f4a")
const COLOR_WET := Color("3d7d58")
const COLOR_STONE := Color("6e6a64")
const COLOR_WATER := Color(0.18, 0.53, 0.78, 0.38)
const COLOR_FALL := Color(0.93, 0.98, 1.0, 0.48)
const COLOR_CLAY := Color("c47a3a")
const COLOR_GHOST := Color(0.88, 0.63, 0.35, 0.55)
const COLOR_RIBBON := Color("3ee0d0")
const COLOR_GOLD := Color("e2b657")
const COLOR_BRANCH := Color("1aa58f")
const COLOR_WOOD := Color("7a4b2a")
const COLOR_TOWER := Color("6d5344")
const COLOR_SUN := Color("f2c14e")
const COLOR_SPIKE := Color("3e434a")
const COLOR_PLAQUE := Color("f6efe2")

var _built := false
var _grid: PackedStringArray = PackedStringArray()
var _contract: Dictionary = {}
var _cam: Camera2D
var _chrome: CanvasLayer
var _pan := false
var _pan_t := 0.0
var _font: Font


func _ready() -> void:
	build()
	var mode := OS.get_environment("BABYLON_CAPTURE")
	if mode == "":
		return
	if mode == "pan":
		_pan = true
		_apply_view("opening")
		_hide_chrome()
		return
	_hide_chrome()
	await RenderingServer.frame_post_draw
	_apply_view(mode)
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	var path := OS.get_environment("BABYLON_CAPTURE_PATH")
	if path == "":
		path = "user://babylon_capture.png"
	var err := image.save_png(path)
	print("CAPTURE %s err=%s %sx%s" % [path, err, image.get_width(), image.get_height()])
	get_tree().quit()


func _process(delta: float) -> void:
	if _cam == null:
		return
	if _pan:
		_pan_t += delta
		var t := clampf(_pan_t / 10.0, 0.0, 1.0)
		_cam.position = Vector2(lerpf(240.0, 2100.0, t), 265.0)
		if _pan_t >= 10.4:
			get_tree().quit()
		return
	var dir := Vector2.ZERO
	if Input.is_key_pressed(KEY_LEFT) or Input.is_key_pressed(KEY_A):
		dir.x -= 1.0
	if Input.is_key_pressed(KEY_RIGHT) or Input.is_key_pressed(KEY_D):
		dir.x += 1.0
	if Input.is_key_pressed(KEY_UP) or Input.is_key_pressed(KEY_W):
		dir.y -= 1.0
	if Input.is_key_pressed(KEY_DOWN) or Input.is_key_pressed(KEY_S):
		dir.y += 1.0
	_cam.position += dir * 220.0 * delta / _cam.zoom.x
	if Input.is_key_pressed(KEY_EQUAL) or Input.is_key_pressed(KEY_KP_ADD):
		_cam.zoom = (_cam.zoom * 1.02).clamp(Vector2(0.35, 0.35), Vector2(3.0, 3.0))
	if Input.is_key_pressed(KEY_MINUS) or Input.is_key_pressed(KEY_KP_SUBTRACT):
		_cam.zoom = (_cam.zoom * 0.98).clamp(Vector2(0.35, 0.35), Vector2(3.0, 3.0))
	if Input.is_key_pressed(KEY_ESCAPE):
		get_tree().quit()


func build() -> void:
	if _built:
		return
	_built = true
	_contract = _load_contract()
	_grid = _load_map()
	_font = load(FONT_PATH)
	var geometry := _nest(self, "Geometry")
	var dressing := _nest(self, "Dressing")
	var markers := _nest(self, "Markers")
	_build_sky(dressing)
	_build_terrain(geometry)
	_build_water(dressing)
	_build_waterfall(dressing)
	_build_markers(markers, dressing)
	_build_inspection()
	_apply_root_meta()


func _load_contract() -> Dictionary:
	var text := FileAccess.get_file_as_string(CONTRACT_PATH)
	var parsed = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("Could not parse %s" % CONTRACT_PATH)
		return {}
	return parsed


func _load_map() -> PackedStringArray:
	var rows := PackedStringArray()
	for line in FileAccess.get_file_as_string(MAP_PATH).split("\n"):
		if line != "":
			rows.append(line)
	return rows


func _nest(parent: Node, node_name: String) -> Node2D:
	var node := Node2D.new()
	node.name = node_name
	parent.add_child(node)
	return node


func _rect(parent: Node, node_name: String, at: Vector2, size: Vector2, color: Color, z: int) -> ColorRect:
	var rect := ColorRect.new()
	rect.name = node_name
	rect.position = at
	rect.size = size
	rect.color = color
	rect.z_as_relative = false
	rect.z_index = z
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(rect)
	return rect


func _meta(node: Node, group: String, data: Dictionary) -> void:
	if group != "":
		node.add_to_group(group)
	for key in data.keys():
		node.set_meta(key, data[key])


func _build_sky(dressing: Node2D) -> void:
	var width := float(_grid[0].length() * TILE)
	var height := float(_grid.size() * TILE)
	_rect(dressing, "SkyTop", Vector2.ZERO, Vector2(width, 150), COLOR_SKY_TOP, -20)
	_rect(dressing, "Sky", Vector2(0, 120), Vector2(width, height), COLOR_SKY, -19)
	var sun := Polygon2D.new()
	sun.name = "Sun"
	sun.z_as_relative = false
	sun.z_index = -18
	sun.color = COLOR_SUN
	var pts := PackedVector2Array()
	for i in 18:
		var angle := TAU * float(i) / 18.0
		pts.append(Vector2(230, 78) + Vector2(cos(angle), sin(angle)) * 34.0)
	sun.polygon = pts
	dressing.add_child(sun)
	_tower(dressing, "TowerOpening", Vector2(268, 300), 1.0)
	_tower(dressing, "TowerExit", Vector2(1980, 300), 1.35)
	_tree(dressing, Vector2(150, 320))
	_tree(dressing, Vector2(430, 320))
	_tree(dressing, Vector2(1040, 320))
	_tree(dressing, Vector2(1210, 320))
	_rect(dressing, "DistantFallLeft", Vector2(48, 80), Vector2(10, 140), COLOR_FALL, -16)
	_rect(dressing, "DistantFallRight", Vector2(520, 100), Vector2(8, 120), COLOR_FALL, -16)


func _tower(parent: Node, node_name: String, base: Vector2, scale: float) -> void:
	var tower := Polygon2D.new()
	tower.name = node_name
	tower.z_as_relative = false
	tower.z_index = -17
	tower.color = COLOR_TOWER
	var shape := PackedVector2Array([
		Vector2(-70, 0), Vector2(-48, -150), Vector2(-20, -168), Vector2(0, -230),
		Vector2(20, -168), Vector2(48, -150), Vector2(70, 0),
	])
	var pts := PackedVector2Array()
	for point in shape:
		pts.append(base + point * scale)
	tower.polygon = pts
	parent.add_child(tower)
	_meta(tower, "", {
		"placeholder_art": true,
		"motif": "distant_tower_covering_the_sun",
		"collapses": false,
	})
	_rect(parent, node_name + "Garden", base + Vector2(-36 * scale, -120 * scale), Vector2(72 * scale, 10 * scale), COLOR_GRASS, -16)


func _tree(parent: Node, base: Vector2) -> void:
	_rect(parent, "Trunk", base + Vector2(-3, -28), Vector2(6, 28), COLOR_WOOD, -15)
	var crown := Polygon2D.new()
	crown.z_as_relative = false
	crown.z_index = -15
	crown.color = Color("2f7a3e")
	var pts := PackedVector2Array()
	for i in 8:
		var angle := TAU * float(i) / 8.0
		pts.append(base + Vector2(0, -36) + Vector2(cos(angle) * 18.0, sin(angle) * 12.0))
	crown.polygon = pts
	parent.add_child(crown)


func _build_terrain(geometry: Node2D) -> void:
	var visual := _nest(geometry, "Terrain")
	var body := StaticBody2D.new()
	body.name = "Collision"
	body.collision_layer = 1
	body.collision_mask = 0
	geometry.add_child(body)
	_meta(body, "babylon_world", {
		"collision_layer": 1,
		"placeholder_geometry": true,
		"tile_size": TILE,
	})
	var height := _grid.size()
	var width := _grid[0].length()
	for y in height:
		var run_start := -1
		var run_color := Color.BLACK
		for x in width + 1:
			var solid := x < width and _grid[y][x] == "#"
			var color := _terrain_color(x, y) if solid else Color.BLACK
			if solid and run_start >= 0 and color == run_color:
				continue
			if run_start >= 0:
				_commit_run(visual, body, run_start, x, y, run_color)
			run_start = x if solid else -1
			run_color = color


func _terrain_color(x: int, y: int) -> Color:
	if x >= _grid[0].length():
		return COLOR_DIRT
	var top := y == 0 or _grid[y - 1][x] != "#"
	if top and x >= 119 and x <= 121 and y == 19:
		return COLOR_STONE
	if top and x >= 83 and x <= 100 and y >= 21:
		return COLOR_WET
	if top:
		return COLOR_GRASS
	return COLOR_DIRT


func _commit_run(visual: Node, body: StaticBody2D, x0: int, x1: int, y: int, color: Color) -> void:
	var pixel_w := float((x1 - x0) * TILE)
	_rect(visual, "Tile", Vector2(x0 * TILE, y * TILE), Vector2(pixel_w, TILE), color, 0)
	var shape := RectangleShape2D.new()
	shape.size = Vector2(pixel_w, TILE)
	var collider := CollisionShape2D.new()
	collider.shape = shape
	collider.position = Vector2(x0 * TILE + pixel_w * 0.5, y * TILE + TILE * 0.5)
	body.add_child(collider)


func _build_water(dressing: Node2D) -> void:
	var stream := _nest(dressing, "Stream")
	_meta(stream, "babylon_decorative_water", {
		"damage": false,
		"hidden_damage": false,
		"ranges_tiles": [[24, 24], [28, 35], [83, 100]],
		"note": "Shallow garden water and the stream under the falls. Cold to the story, not a hazard.",
	})
	for x in [24]:
		_water_strip(stream, x, x + 1)
	_water_strip(stream, 28, 36)
	_water_strip(stream, 83, 101)


func _water_strip(parent: Node, x0: int, x1: int) -> void:
	for x in range(x0, x1):
		var stand := _top_stand(x)
		if stand < 0:
			continue
		_rect(parent, "Water", Vector2(x * TILE, (stand + 1) * TILE - 6), Vector2(TILE, 6), COLOR_WATER, 1)


func _top_stand(x: int) -> int:
	for y in _grid.size() - 1:
		if _grid[y][x] != "#" and _grid[y + 1][x] == "#":
			return y
	return -1


func _build_waterfall(dressing: Node2D) -> void:
	var falls := _nest(dressing, "Waterfall")
	falls.z_as_relative = false
	falls.z_index = 6
	_meta(falls, "babylon_waterfall", {
		"x_tiles": [90, 94],
		"decorative": true,
		"damage": false,
		"hides_optional_path": "translucent_only",
	})
	for x in range(90, 95):
		var alpha := 0.34 if x == 93 else 0.5
		var column := _rect(falls, "Column", Vector2(x * TILE + 2, 72), Vector2(12, 280), Color(COLOR_FALL.r, COLOR_FALL.g, COLOR_FALL.b, alpha), 6)
		column.z_as_relative = true
		_rect(falls, "Highlight", Vector2(x * TILE + 6, 72), Vector2(3, 280), Color(1, 1, 1, alpha * 0.85), 6)


func _ix(data: Dictionary, key: String) -> int:
	return int(data[key])


func _sx(data: Dictionary, key: String) -> String:
	return str(data[key])


func _build_markers(markers: Node2D, dressing: Node2D) -> void:
	var spawn: Dictionary = _contract["spawn"]
	_marker(markers, "PlayerSpawn", "", _ix(spawn, "x"), _ix(spawn, "y"), "babylon_player_spawn", {
		"spawn_id": "gardens_player_spawn",
		"expected_hero_root": "res://gameplay/babylon/",
		"hero_present": false,
		"do_not_instance": "res://player/player.tscn",
		"forbidden_assumptions": "double_jump,wall_jump,pogo,stomp,sword,dash,reflect",
		"run_speed_px_estimate": 130,
		"single_jump_px_estimate": 48,
		"estimates_tested_with_hero": false,
	}, Color("f4e1c1"), Vector2(10, 18))
	_plaque(markers, "OpeningLine", 1, 1, _contract["opening_line"], "opening line — not one of the four signs", 230, 0)
	_meta(markers.get_node("OpeningLine"), "babylon_opening_line", {
		"text": _contract["opening_line"],
		"counts_as_story_sign": false,
	})

	var signs := _nest(markers, "Signs")
	for sign_variant in _contract["signs"]:
		var sign: Dictionary = sign_variant
		var index := _ix(sign, "index")
		var node := _marker(signs, "Sign_%02d" % index, "", _ix(sign, "x"), _ix(sign, "y"), "babylon_story_sign", {
			"id": _sx(sign, "id"),
			"index": index,
			"x_tile": _ix(sign, "x"),
			"y_tile": _ix(sign, "y"),
			"text": _sx(sign, "text"),
			"purpose": _sx(sign, "purpose"),
			"unlocks_ability": false,
		}, COLOR_WOOD, Vector2(4, 16))
		_plaque(node, "Plaque", 0, 0, _sx(sign, "text"), _sx(sign, "purpose"), 220, -108)

	var checks := _nest(markers, "Checkpoints")
	for point_variant in _contract["checkpoints"]:
		var point: Dictionary = point_variant
		_marker(checks, "Checkpoint_%s" % _sx(point, "id"), "", _ix(point, "x"), _ix(point, "y"), "babylon_checkpoint", {
			"id": _sx(point, "id"),
			"x_tile": _ix(point, "x"),
			"y_tile": _ix(point, "y"),
			"safe": true,
			"inside_hazard": false,
			"respawn_order": "respawn_started resets enemies before the hero is re-enabled; respawned fires afterwards",
		}, Color("f0d48a"), Vector2(8, 14))

	var abilities := _nest(markers, "Abilities")
	var clay: Dictionary = _contract["clay_pickup"]
	_marker(abilities, "ClayPlatformPickup", "", _ix(clay, "x"), _ix(clay, "y"), "babylon_ability_pickup", {
		"ability_id": _sx(clay, "id"),
		"x_tile": _ix(clay, "x"),
		"y_tile": _ix(clay, "y"),
		"unlock": "explicit_pickup_event_not_the_sign",
		"sign_unlocks_ability": false,
		"contract_status": _sx(clay, "contract_status"),
		"draft_size_px": Vector2(32, 16),
		"draft_lifetime_sec": 4.0,
		"draft_charges": 1,
		"draft_restore": "real_ground_only",
		"ui_signal": "ability_requested",
		"ui_connection": "connect_once_direct_to_ability_request_do_not_also_synth_input",
		"wired_in_this_scene": false,
		"provisional": true,
	}, COLOR_CLAY, Vector2(12, 12))
	_plaque(abilities.get_node("ClayPlatformPickup"), "Plaque", 0, 0, "", "clay pickup marker — the sign does not unlock it", 210, -36)

	var ghosts := _nest(dressing, "ProvisionalClay")
	_meta(ghosts, "babylon_provisional_clay", {
		"provisional": true,
		"required_for_exit": false,
		"label": "Clay teaching geometry is provisional. The ground route does not need a clay platform.",
		"x_tile_range": Vector2i(50, 58),
	})
	for ghost_variant in _contract["provisional_clay_ghosts"]:
		var ghost: Dictionary = ghost_variant
		var gx := _ix(ghost, "x")
		var gy := _ix(ghost, "y")
		var slab := _rect(ghosts, "ClayGhost_%d_%d" % [gx, gy], Vector2(gx * TILE, gy * TILE + 8), Vector2(TILE, 8), COLOR_GHOST, 3)
		_meta(slab, "babylon_provisional_clay", {
			"provisional": true,
			"solid": false,
			"x_tile": gx,
			"y_tile": gy,
			"required_for_exit": false,
		})
	_plaque(ghosts, "TrainingRangeLabel", 49, 11, "", "PROVISIONAL clay teaching — walkable without clay", 230, 0)

	var guides := _nest(dressing, "RouteGuides")
	for guide_variant in _contract["route_guides"]:
		var guide: Dictionary = guide_variant
		var gx := _ix(guide, "x")
		var gy := _ix(guide, "y")
		var root := _nest(guides, "RouteGuide_%s" % _sx(guide, "id"))
		root.position = Vector2(gx * TILE, gy * TILE)
		_rect(root, "Branch", Vector2(-2, 8), Vector2(20, 4), COLOR_WOOD, 8)
		_rect(root, "Band", Vector2(0, 6), Vector2(14, 3), COLOR_BRANCH, 8)
		_meta(root, "babylon_route_guide", {
			"id": _sx(guide, "id"),
			"x_tile": gx,
			"y_tile": gy,
			"visual_class": "branch_band",
			"collectible": false,
			"optional_secret": false,
			"distinct_from": "hanging_ribbon",
		})

	var guard_data: Dictionary = _contract["guard"]
	var guards := _nest(markers, "Guards")
	var guard := _marker(guards, "GardensGuardSpawn", "", _ix(guard_data, "x"), _ix(guard_data, "y"), "babylon_guard_spawn", {
		"spawn_id": _sx(guard_data, "id"),
		"x_tile": _ix(guard_data, "x"),
		"y_tile": _ix(guard_data, "y"),
		"expected_scene_root": "res://enemies/babylon/",
		"ai_status": "spawn_marker_only",
		"blocks_path": false,
		"damage_api": "take_damage(amount, from_position)",
		"touch_policy": "any_touch_hurts_including_from_above",
		"hero_owns_invulnerability": true,
		"no_stomp": true,
		"reset_signal": "respawn_started",
		"reset_order": "before_hero_reenable",
		"after_signal": "respawned",
		"taunt": _sx(guard_data, "taunt"),
		"defeat_line": _sx(guard_data, "defeat_line"),
	}, Color("5c6670"), Vector2(14, 22))
	_rect(guard, "Shield", Vector2(-16, -16), Vector2(8, 12), Color("8a6a3b"), 12)
	_plaque(guard, "Plaque", 0, 0, _sx(guard_data, "taunt"), "guard spawn marker — no AI in this scene", 200, -96)

	var ribbon: Dictionary = _contract["ribbon"]
	var cloth := _nest(dressing, "SecretRibbon")
	cloth.position = Vector2(_ix(ribbon, "x") * TILE + 5, _ix(ribbon, "y") * TILE)
	cloth.z_as_relative = false
	cloth.z_index = 2
	_rect(cloth, "Ring", Vector2(-2, 0), Vector2(10, 3), COLOR_GOLD, 2)
	_rect(cloth, "Cloth", Vector2(0, 3), Vector2(6, 20), COLOR_RIBBON, 2)
	_meta(cloth, "", {
		"visual_class": "hanging_ribbon",
		"behind_waterfall": true,
		"placeholder_art": true,
	})
	var collectibles := _nest(markers, "Collectibles")
	var ribbon_marker := _marker(collectibles, "PrincessRibbonL1", "", _ix(ribbon, "x"), _ix(ribbon, "y"), "babylon_princess_ribbon", {
		"collectible_id": _sx(ribbon, "id"),
		"x_tile": _ix(ribbon, "x"),
		"y_tile": _ix(ribbon, "y"),
		"text": _sx(ribbon, "text"),
		"optional": true,
		"required_for_exit": false,
		"required_for_clay": false,
		"visual_class": "hanging_ribbon",
		"visual_node": "Dressing/SecretRibbon",
		"interaction": "marker_only",
		"save_ui": "not_in_this_scene",
		"behind_waterfall": true,
	}, COLOR_RIBBON, Vector2(6, 20))
	ribbon_marker.visible = false
	_plaque(collectibles, "RibbonPlaque", 84, 1, _sx(ribbon, "text"), "optional princess ribbon — not required to exit or unlock clay", 250, 0)

	var hazards := _nest(markers, "Hazards")
	for spike_variant in _contract["spikes"]:
		var spike: Dictionary = spike_variant
		var sx := _ix(spike, "x")
		var sy := _ix(spike, "y")
		var spike_node := _marker(hazards, "Spike_%d_%d" % [sx, sy], "", sx, sy, "babylon_hazard", {
			"x_tile": sx,
			"y_tile": sy,
			"damage_enabled": false,
			"hurt_owner": "res://gameplay/babylon/",
			"damage_api": "take_damage(amount, from_position)",
			"volume": "cavity_tile_only_not_the_cap_stand",
			"required_to_cross": false,
			"cap_route_y_tile": sy - 2,
		}, COLOR_SPIKE, Vector2(14, 8))
		var tooth := Polygon2D.new()
		tooth.color = COLOR_SPIKE
		tooth.z_as_relative = false
		tooth.z_index = 4
		tooth.polygon = PackedVector2Array([Vector2(-6, 0), Vector2(0, -10), Vector2(6, 0)])
		spike_node.add_child(tooth)
	var drip := _marker(hazards, "TimingDripPlaceholder", "", 124, 16, "", {
		"timing_placeholder": true,
		"blocks_path": false,
		"damage_enabled": false,
		"note": "A timing beat is not built. Jump reach is still unmeasured.",
	}, Color(0.7, 0.88, 0.95, 0.0), Vector2(4, 10))
	_rect(drip, "Drop", Vector2(-2, -18), Vector2(4, 8), Color(0.75, 0.9, 1.0, 0.8), 4)
	_plaque(drip, "Plaque", 0, 0, "", "timing gate not built — jump reach unmeasured", 200, -28)

	var exit_data: Dictionary = _contract["exit"]
	var exit_root := _nest(markers, "Exit")
	var arch := _marker(exit_root, "StageExit", "", _ix(exit_data, "x"), _ix(exit_data, "y"), "babylon_stage_exit", {
		"x_tile": _ix(exit_data, "x"),
		"y_tile": _ix(exit_data, "y"),
		"next_stage_id": str(_contract["next_stage_id"]),
		"next_stage_title": str(_contract["next_stage_title"]),
		"exit_line": str(_contract["exit_line"]),
		"visible": true,
		"changes_scene": false,
		"tower_collapses": false,
	}, Color("d7c4a3"), Vector2(18, 28))
	_rect(arch, "LeftPillar", Vector2(-16, -28), Vector2(6, 28), Color("d7c4a3"), 11)
	_rect(arch, "RightPillar", Vector2(10, -28), Vector2(6, 28), Color("d7c4a3"), 11)
	_rect(arch, "Lintel", Vector2(-16, -32), Vector2(32, 6), Color("c6b08a"), 11)
	_plaque(arch, "Plaque", 0, 0, str(_contract["exit_line"]), "visible exit toward stage 2 — no scene change in this build", 230, -120)

	for petal in [Vector2(70, 300), Vector2(210, 304), Vector2(2160, 230), Vector2(2200, 236)]:
		_rect(dressing, "Flower", petal, Vector2(4, 4), Color("e07a9a"), 3)


func _marker(parent: Node, node_name: String, _unused: String, x: int, y: int, group: String, data: Dictionary, color: Color, size: Vector2) -> Marker2D:
	var marker := Marker2D.new()
	marker.name = node_name
	marker.position = Vector2(x * TILE + TILE * 0.5, (y + 1) * TILE)
	parent.add_child(marker)
	data["x_tile"] = x
	data["y_tile"] = y
	_meta(marker, group, data)
	if size != Vector2.ZERO and color.a > 0.0:
		_rect(marker, "Body", Vector2(-size.x * 0.5, -size.y), size, color, 11)
	return marker


func _plaque(parent: Node, node_name: String, tile_x: int, tile_y: int, arabic: String, caption: String, width: int, y_offset: int) -> Node2D:
	var root := Node2D.new()
	root.name = node_name
	if parent is Marker2D:
		root.position = Vector2(-width * 0.5, y_offset)
	else:
		root.position = Vector2(tile_x * TILE, tile_y * TILE + y_offset)
	root.z_as_relative = false
	root.z_index = 30
	parent.add_child(root)
	var panel := ColorRect.new()
	panel.color = COLOR_PLAQUE
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var has_story := arabic != ""
	var story_h := 22
	if has_story:
		story_h = 22 * maxi(1, int(float(arabic.length()) / 26.0) + 1)
	panel.size = Vector2(width, (story_h + 22) if has_story else 24)
	panel.z_index = 30
	root.add_child(panel)
	if has_story:
		var story := Label.new()
		story.text = arabic
		story.position = Vector2(6, 4)
		story.size = Vector2(width - 12, story_h)
		story.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		story.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		story.text_direction = Control.TEXT_DIRECTION_RTL
		story.language = "ar"
		story.add_theme_font_override("font", _font)
		story.add_theme_font_size_override("font_size", 14)
		story.add_theme_color_override("font_color", Color("1c140e"))
		story.mouse_filter = Control.MOUSE_FILTER_IGNORE
		root.add_child(story)
	var note := Label.new()
	note.text = caption
	note.position = Vector2(6, story_h + 2 if has_story else 3)
	note.size = Vector2(width - 12, 18)
	note.add_theme_font_size_override("font_size", 8)
	note.add_theme_color_override("font_color", Color("5c4636"))
	note.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(note)
	return root


func _build_inspection() -> void:
	var inspection := _nest(self, "Inspection")
	_cam = Camera2D.new()
	_cam.name = "Camera"
	_cam.position = Vector2(220, 200)
	_cam.zoom = Vector2(1, 1)
	_cam.limit_left = 0
	_cam.limit_top = 0
	_cam.limit_right = _grid[0].length() * TILE
	_cam.limit_bottom = _grid.size() * TILE
	_cam.enabled = true
	inspection.add_child(_cam)
	if _cam.is_inside_tree():
		_cam.make_current()
	else:
		_cam.call_deferred("make_current")
	_meta(_cam, "", {
		"role": "inspection_camera_not_the_hero",
		"pan": "arrows_or_wasd",
		"zoom": "minus_and_equals",
	})
	_chrome = CanvasLayer.new()
	_chrome.name = "Chrome"
	inspection.add_child(_chrome)
	var hint := Label.new()
	hint.name = "Hint"
	hint.position = Vector2(8, 6)
	hint.size = Vector2(460, 36)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.text = "Inspection camera, not the hero. Arrows pan, -/= zoom. No clay, dash, reflect, sword, stomp, or enemy AI."
	hint.add_theme_font_size_override("font_size", 10)
	hint.add_theme_color_override("font_color", Color("1a140f"))
	_chrome.add_child(hint)


func _hide_chrome() -> void:
	if _chrome:
		_chrome.visible = false


func _apply_view(mode: String) -> void:
	if _cam == null:
		return
	var view := get_viewport().get_visible_rect().size
	if view.x < 10.0:
		view = Vector2(480, 270)
	# Keep about 34 tiles on screen whether the window is the 480 viewport or a scaled desktop window.
	var zoom_value := view.x / 544.0
	_cam.zoom = Vector2(zoom_value, zoom_value)
	var visible_h := view.y / zoom_value
	var ground_y := 20.0 * TILE
	var focus_x := 220.0
	match mode:
		"opening":
			focus_x = 240.0
		"waterfall":
			focus_x = 93.0 * TILE
		"clay":
			focus_x = 50.0 * TILE
		"exit":
			focus_x = 132.0 * TILE
			ground_y = 17.0 * TILE
		"guard":
			focus_x = 68.0 * TILE
		_:
			focus_x = 240.0
	_cam.position = Vector2(focus_x, ground_y - visible_h * 0.18)
	print("VIEW size=%s zoom=%s cam=%s" % [view, _cam.zoom, _cam.position])


func _apply_root_meta() -> void:
	set_meta("stage_id", str(_contract.get("stage_id", "")))
	set_meta("stage_index", int(_contract.get("stage_index", 1)))
	set_meta("title", str(_contract.get("title", "")))
	set_meta("integration_status", "markers_only_no_hero")
	set_meta("placeholder_art", true)
	set_meta("hero_root_expected", "res://gameplay/babylon/")
	set_meta("enemy_root_expected", "res://enemies/babylon/")
	set_meta("ui_root_expected", "res://ui/babylon/")
	set_meta("mandatory_clay_gap", false)
	set_meta("clay_geometry", "provisional")
	set_meta("tile_size", TILE)
	set_meta("map_size_tiles", Vector2i(_grid[0].length(), _grid.size()))


func validate_contract() -> Array:
	build()
	var errors: Array = []
	if _grid.size() != 26 or _grid[0].length() != 140:
		errors.append("map bounds are %sx%s, expected 140x26" % [_grid[0].length(), _grid.size()])
	var expected_signs := 4
	if _nodes_in_group("babylon_story_sign").size() != expected_signs:
		errors.append("story sign count != 4")
	for sign in _nodes_in_group("babylon_story_sign"):
		if bool(sign.get_meta("unlocks_ability")):
			errors.append("sign unlocks an ability: %s" % sign.name)
		if str(sign.get_meta("text")) == "":
			errors.append("sign missing text")
	var ribbons := _nodes_in_group("babylon_princess_ribbon")
	if ribbons.size() != 1:
		errors.append("princess ribbon count != 1")
	else:
		var ribbon: Node = ribbons[0]
		if not bool(ribbon.get_meta("optional")) or bool(ribbon.get_meta("required_for_exit")) or bool(ribbon.get_meta("required_for_clay")):
			errors.append("ribbon is not optional")
		var ribbon_contract: Dictionary = _contract["ribbon"]
		if str(ribbon.get_meta("text")) != _sx(ribbon_contract, "text"):
			errors.append("ribbon text mismatch")
		if str(ribbon.get_meta("visual_class")) == "branch_band":
			errors.append("ribbon uses the route-guide visual")
	var ribbon_contract_check: Dictionary = _contract["ribbon"]
	for guide in _nodes_in_group("babylon_route_guide"):
		if str(guide.get_meta("visual_class")) != "branch_band":
			errors.append("route guide is not a branch band")
		if int(guide.get_meta("x_tile")) == _ix(ribbon_contract_check, "x"):
			errors.append("route guide shares the ribbon tile")
	if get_node_or_null("Markers/PlayerSpawn") == null:
		errors.append("missing Markers/PlayerSpawn")
	if get_node_or_null("Markers/Abilities/ClayPlatformPickup") == null:
		errors.append("missing clay pickup")
	if get_node_or_null("Markers/Guards/GardensGuardSpawn") == null:
		errors.append("missing guard spawn")
	if get_node_or_null("Markers/Exit/StageExit") == null:
		errors.append("missing exit")
	if get_node_or_null("Dressing/Waterfall") == null or get_node_or_null("Dressing/SecretRibbon") == null:
		errors.append("missing waterfall or secret ribbon visual")
	var report := route_report()
	if not bool(report.exit_reachable):
		errors.append("required route does not reach the exit")
	if bool(report.ribbon_on_required):
		errors.append("ribbon lies on the required route")
	if not bool(report.ribbon_reachable) or not bool(report.ribbon_returns):
		errors.append("ribbon route is missing a return")
	if int(report.min_clearance) < 32:
		errors.append("required-route clearance is under 32px")
	if int(report.cliff_count) != 0 or int(report.softlock_count) != 0:
		errors.append("cliff or softlock under the step model")
	if not bool(report.avoids_spikes):
		errors.append("exit requires stepping on spikes")
	for child in find_children("*", "", true, false):
		if child.get_script() != null:
			errors.append("unexpected script on %s" % child.name)
	return errors


func route_report() -> Dictionary:
	build()
	var blocked := {}
	var ribbon_data: Dictionary = _contract["ribbon"]
	blocked[Vector2i(_ix(ribbon_data, "x"), _ix(ribbon_data, "y"))] = true
	for spike_variant in _contract["spikes"]:
		var spike: Dictionary = spike_variant
		blocked[Vector2i(_ix(spike, "x"), _ix(spike, "y"))] = true
	var spawn_data: Dictionary = _contract["spawn"]
	var exit_data: Dictionary = _contract["exit"]
	var start := Vector2i(_ix(spawn_data, "x"), _ix(spawn_data, "y"))
	var exit := Vector2i(_ix(exit_data, "x"), _ix(exit_data, "y"))
	var ribbon := Vector2i(_ix(ribbon_data, "x"), _ix(ribbon_data, "y"))
	var required := _reach(start, 1, blocked)
	var optional := _reach(start, 2, {})
	var back := _reach(ribbon, 2, {})
	var avoid := _reach(start, 1, _spike_block())
	var min_clearance := 999
	var y_min := 99
	var y_max := -1
	for key in required.keys():
		var cell: Vector2i = key
		min_clearance = mini(min_clearance, _clearance(cell.x, cell.y))
		y_min = mini(y_min, cell.y)
		y_max = maxi(y_max, cell.y)
	var world := _reach(start, 2, {})
	var cliffs := 0
	var width := _grid[0].length()
	for key in world.keys():
		var cell: Vector2i = key
		for nx in [cell.x - 1, cell.x + 1]:
			if nx < 0 or nx >= width:
				cliffs += 1
				continue
			if _grid[cell.y][nx] == "#":
				continue
			var landing := _landing(nx, cell.y)
			if landing < 0 or landing - cell.y > 2:
				cliffs += 1
	var softlocks := 0
	for key in world.keys():
		var cell: Vector2i = key
		if not _reach(cell, 2, {}).has(exit):
			softlocks += 1
	var spike_escape := true
	for spike_variant in _contract["spikes"]:
		var spike: Dictionary = spike_variant
		if not _reach(Vector2i(_ix(spike, "x"), _ix(spike, "y")), 1, {}).has(exit):
			spike_escape = false
	return {
		"exit_reachable": required.has(exit),
		"ribbon_on_required": required.has(ribbon),
		"ribbon_reachable": optional.has(ribbon),
		"ribbon_returns": back.has(start) and back.has(exit),
		"min_clearance": min_clearance,
		"required_count": required.size(),
		"cliff_count": cliffs,
		"softlock_count": softlocks,
		"avoids_spikes": avoid.has(exit),
		"spike_escape": spike_escape,
		"y_min": y_min,
		"y_max": y_max,
	}


func _nodes_in_group(group_name: String) -> Array:
	var found: Array = []
	_collect_group(self, group_name, found)
	return found


func _collect_group(node: Node, group_name: String, found: Array) -> void:
	if node.is_in_group(group_name):
		found.append(node)
	for child in node.get_children():
		_collect_group(child, group_name, found)


func _spike_block() -> Dictionary:
	var blocked := {}
	for spike_variant in _contract["spikes"]:
		var spike: Dictionary = spike_variant
		blocked[Vector2i(_ix(spike, "x"), _ix(spike, "y"))] = true
	return blocked


func _can_stand(x: int, y: int) -> bool:
	if x < 0 or y < 0 or x >= _grid[0].length() or y >= _grid.size() - 1:
		return false
	return _grid[y][x] != "#" and _grid[y + 1][x] == "#"


func _reach(start: Vector2i, step: int, blocked: Dictionary) -> Dictionary:
	var seen := {start: true}
	var queue: Array[Vector2i] = [start]
	var head := 0
	while head < queue.size():
		var cell := queue[head]
		head += 1
		for nx in [cell.x - 1, cell.x + 1]:
			for dy in range(-step, step + 1):
				var ny := cell.y + dy
				var next := Vector2i(nx, ny)
				if seen.has(next) or blocked.has(next) or not _can_stand(nx, ny):
					continue
				seen[next] = true
				queue.append(next)
	return seen


func _clearance(x: int, y: int) -> int:
	for ny in range(y - 1, -1, -1):
		if _grid[ny][x] == "#":
			return (y - ny) * TILE
	return 999


func _landing(x: int, y: int) -> int:
	for ny in range(y, _grid.size() - 1):
		if _can_stand(x, ny):
			return ny
	return -1
