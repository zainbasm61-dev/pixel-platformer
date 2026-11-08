extends SceneTree
## Headless contract check for the gardens inspection scene.

func _initialize() -> void:
	var packed = load("res://levels/babylon/gardens_level.tscn")
	if packed == null:
		print("SCENE_CHECK_FAIL could not load gardens_level.tscn")
		quit(1)
		return
	var node = packed.instantiate()
	root.add_child(node)
	var errors: Array = node.validate_contract()
	var report: Dictionary = node.route_report()
	print("ROUTE ", report)
	var report_ok := bool(report["exit_reachable"]) and not bool(report["ribbon_on_required"]) and bool(report["ribbon_reachable"]) and bool(report["ribbon_returns"]) and int(report["min_clearance"]) >= 32 and int(report["cliff_count"]) == 0 and int(report["softlock_count"]) == 0 and bool(report["avoids_spikes"]) and bool(report["spike_escape"])
	if errors.is_empty() and report_ok:
		print("SCENE_CHECK_OK signs=4 ribbon=1")
		quit(0)
		return
	for err in errors:
		print("SCENE_CHECK_FAIL ", err)
	if not report_ok:
		print("SCENE_CHECK_FAIL route report")
	quit(1)
