extends SceneTree

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var scene: Node = load("res://main.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	await process_frame
	scene.set("intro_active", false)
	for child in scene.get_children():
		if child is CanvasLayer:
			child.visible = false

	var station: Node3D = scene.get("turntable_station") as Node3D
	var disc: MeshInstance3D = scene.get("turntable_disc") as MeshInstance3D
	if disc != null:
		disc.visible = true
		scene.call("update_turntable_art", 1)
	var pivot: Node3D = scene.get("tonearm_pivot") as Node3D
	if pivot != null:
		pivot.rotation.y = scene.get("tonearm_start_angle")

	var key := OmniLight3D.new()
	key.position = Vector3(1.8, 3.2, 2.7)
	key.light_color = Color("fff2d0")
	key.light_energy = 6.0
	key.omni_range = 6.0
	scene.add_child(key)
	var fill := OmniLight3D.new()
	fill.position = Vector3(-2.4, 2.2, -1.4)
	fill.light_color = Color("9ad8ff")
	fill.light_energy = 2.0
	fill.omni_range = 5.0
	scene.add_child(fill)

	var camera: Camera3D = scene.get("player_camera") as Camera3D
	if camera != null and station != null:
		camera.current = true
		camera.global_position = station.global_position + Vector3(2.8, 2.05, 3.15)
		camera.look_at(station.global_position + Vector3(0.0, 1.08, 0.30), Vector3.UP)

	await process_frame
	await RenderingServer.frame_post_draw
	var output_dir := ProjectSettings.globalize_path("res://work")
	DirAccess.make_dir_recursive_absolute(output_dir)
	var image := root.get_viewport().get_texture().get_image()
	var output_path := output_dir.path_join("turntable_preview.png")
	image.save_png(output_path)
	print("PREVIEW: %s" % output_path)
	quit(0)
