extends SceneTree

func _init() -> void:
	call_deferred("_run")

func _fail(message: String) -> void:
	printerr("VALIDATION FAILED: %s" % message)
	quit(1)

func _approx(a: float, b: float, tolerance: float = 0.01) -> bool:
	return absf(a - b) <= tolerance

func _run() -> void:
	var scene: Node = load("res://main.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	await process_frame

	var station: Node3D = scene.get("turntable_station") as Node3D
	if station == null:
		_fail("No turntable_station was created.")
		return
	if station.position.distance_to(Vector3(0.0, 0.0, 0.35)) > 0.01:
		_fail("Turntable station is not centered in the main room.")
		return

	var mount: Node3D = scene.get("turntable_model_root") as Node3D
	if mount == null:
		_fail("Rigged turntable model did not load.")
		return
	if not (_approx(mount.scale.x, mount.scale.y) and _approx(mount.scale.y, mount.scale.z)):
		_fail("Turntable model scale is not uniform.")
		return
	if absf(mount.rotation.x) > 0.001 or absf(mount.rotation.z) > 0.001:
		_fail("Turntable mount is tilted.")
		return

	var disc: MeshInstance3D = scene.get("turntable_disc") as MeshInstance3D
	if disc == null or disc.get_parent() != station:
		_fail("Functional vinyl disc is not mounted on the station.")
		return
	if disc.position.y < 1.40 or disc.position.y > 1.46:
		_fail("Functional vinyl disc is not sitting on top of the platter.")
		return

	var fader: StaticBody3D = scene.get("volume_fader") as StaticBody3D
	if fader == null or fader.get_parent() != station:
		_fail("Volume fader is not integrated into the station.")
		return
	scene.set("amp_volume_db", -30.0)
	scene.call("update_amplifier")
	if not _approx(fader.position.x, 0.35, 0.02):
		_fail("Volume fader minimum is not on the front control strip.")
		return
	scene.set("amp_volume_db", 6.0)
	scene.call("update_amplifier")
	if not _approx(fader.position.x, 0.95, 0.02):
		_fail("Volume fader maximum is not on the front control strip.")
		return

	var pivot: Node3D = scene.get("tonearm_pivot") as Node3D
	if pivot == null:
		_fail("TonearmPivot was not found in the rigged model.")
		return
	var start_angle: float = scene.get("tonearm_start_angle")
	var center_angle: float = scene.get("tonearm_center_angle")
	if start_angle >= center_angle:
		pass
	else:
		_fail("Tonearm angles should move from right/rest toward the center.")
		return
	scene.set("tonearm_target_angle", start_angle)
	scene.call("_process", 1.0)
	var after_start: float = pivot.rotation.y
	scene.set("tonearm_target_angle", center_angle)
	scene.call("_process", 1.0)
	if absf(pivot.rotation.y - after_start) < 0.05:
		_fail("Tonearm pivot does not respond to playback target angles.")
		return

	var player: CharacterBody3D = scene.get("player") as CharacterBody3D
	if player == null or player.collision_mask != 1:
		_fail("Player should only collide with world geometry layer 1.")
		return
	var artist_records: Array = scene.get("artist_records")
	for record in artist_records:
		if record.collision_layer != 2 or record.collision_mask != 0:
			_fail("Dropped artist records should be interactable without blocking movement.")
			return
	var vinyl_nodes: Array = scene.get("vinyl_nodes")
	for vinyl in vinyl_nodes:
		if vinyl.collision_layer != 2 or vinyl.collision_mask != 0:
			_fail("Dropped jazz records should be interactable without blocking movement.")
			return

	print("VALIDATION OK: centered level turntable, moving model arm, front controls, and non-blocking floor records.")
	quit(0)
