extends Node3D

const VINYL_COUNT := 5
var selected_vinyl := -1
var placed: Array[bool] = [false, false, false, false, false]
var vinyl_nodes: Array[Node3D] = []
var slot_nodes: Array[Node3D] = []
var cafe_lights: Array[OmniLight3D] = []
var turntable_disc: MeshInstance3D
var progress_label: Label
var instruction_label: Label
var status_label: Label
var audio_player: AudioStreamPlayer3D
var audio_playback: AudioStreamGeneratorPlayback
var return_sound_player: AudioStreamPlayer3D
var return_sound_playback: AudioStreamGeneratorPlayback
var return_sound_time := 0.0
var audio_phase := 0.0
var audio_time := 0.0
var record_spinning := false
var player: CharacterBody3D
var player_camera: Camera3D
var flashlight: SpotLight3D
var artist_record: StaticBody3D
var artist_records: Array[StaticBody3D] = []
var artist_slots: Array[StaticBody3D] = []
var artist_selected := false
var artist_holding := false
var artist_on_turntable := false
var hand_inspect_back := false
var hand_bob_time := 0.0
var active_artist_id := -1
var turntable_artist_id := -1
var artist_titles: Array[String] = ["Hoy es diferente", "Abyss 404"]
var artist_names: Array[String] = ["Abraham HDZ", "9 MONARCA"]
var artist_genres: Array[String] = ["Regional mexicano", "Independiente"]
var artist_audio_paths: Array[String] = ["res://assets/audio/hoy_es_diferente.mp3", "res://assets/audio/promesa_perdida.mp3"]
var artist_cover_paths: Array[String] = ["res://assets/covers/hoy_es_diferente.png", "res://assets/covers/promesa_perdida.jpeg"]
var artist_shelf_positions: Array[Vector3] = [Vector3(-4.55, 1.55, -1.18), Vector3(-4.55, 1.55, 0.55)]
var amp_volume_db := -6.0
var rpm_mode := 1
var rpm_drag_position := 0.5
var amp_display: Label3D
var volume_fader: StaticBody3D
var rpm_fader: StaticBody3D
var active_fader := ""
var tonearm_pivot: Node3D
var tonearm_target_angle := PI
var turntable_label: MeshInstance3D
var turntable_art_material: StandardMaterial3D
var spectrum_analyzer: AudioEffectSpectrumAnalyzerInstance
var music_bus_index := -1
var led_columns: Array = []
var tonearm_start_angle := 2.52
var tonearm_center_angle := 2.16
var tonearm_rest_angle := PI
var look_pitch := 0.0
const WALK_SPEED := 4.0
const MOUSE_SENSITIVITY := 0.0022

func _ready() -> void:
	build_world()
	build_ui()
	update_progress()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _process(delta: float) -> void:
	if record_spinning:
		turntable_disc.rotate_y(delta * TAU * get_playback_multiplier())
		fill_jazz_audio()
		update_tonearm_from_song()
	update_led_spectrum()
	update_carried_record(delta)
	fill_return_sound()
	if tonearm_pivot != null:
		tonearm_pivot.rotation.y = lerp_angle(tonearm_pivot.rotation.y, tonearm_target_angle, min(1.0, delta * 2.4))

func _physics_process(delta: float) -> void:
	if player == null:
		return
	var input_2d := Vector2.ZERO
	if Input.is_physical_key_pressed(KEY_A): input_2d.x -= 1.0
	if Input.is_physical_key_pressed(KEY_D): input_2d.x += 1.0
	if Input.is_physical_key_pressed(KEY_W): input_2d.y -= 1.0
	if Input.is_physical_key_pressed(KEY_S): input_2d.y += 1.0
	input_2d = input_2d.normalized()
	var direction := (player.transform.basis * Vector3(input_2d.x, 0, input_2d.y)).normalized()
	player.velocity.x = direction.x * WALK_SPEED
	player.velocity.z = direction.z * WALK_SPEED
	if not player.is_on_floor():
		player.velocity.y -= 18.0 * delta
	else:
		player.velocity.y = 0.0
	player.move_and_slide()

func build_world() -> void:
	var world_env := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("17110f")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("5b4639")
	env.ambient_light_energy = 0.22
	world_env.environment = env
	add_child(world_env)

	player = CharacterBody3D.new()
	player.name = "Player"
	player.position = Vector3(0, 1.0, 4.2)
	var player_collision := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.35
	capsule.height = 1.8
	player_collision.shape = capsule
	player.add_child(player_collision)
	player_camera = Camera3D.new()
	player_camera.position = Vector3(0, 1.35, 0)
	player_camera.current = true
	player.add_child(player_camera)
	flashlight = SpotLight3D.new()
	flashlight.name = "Flashlight"
	flashlight.light_color = Color("fff1cf")
	flashlight.light_energy = 5.5
	flashlight.spot_range = 13.0
	flashlight.spot_angle = 28.0
	flashlight.shadow_enabled = true
	player_camera.add_child(flashlight)
	add_child(player)

	make_box("Floor", Vector3(12, 0.2, 10), Vector3(0, -0.1, 0), Color("241b18"))
	make_box("BackWall", Vector3(12, 6, 0.2), Vector3(0, 3, -4.4), Color("31231f"))
	make_box("LeftWall", Vector3(0.2, 6, 9), Vector3(-5.9, 3, 0), Color("291e1b"))
	make_collision_box(Vector3(12, 0.2, 10), Vector3(0, -0.1, 0))
	make_collision_box(Vector3(12, 6, 0.2), Vector3(0, 3, -4.4))
	make_collision_box(Vector3(0.2, 6, 9), Vector3(-5.9, 3, 0))
	make_collision_box(Vector3(0.2, 6, 9), Vector3(5.9, 3, 0))
	make_collision_box(Vector3(12, 6, 0.2), Vector3(0, 3, 5.0))

	# Jazz shelving unit.
	make_box("ShelfBack", Vector3(5.8, 3.7, 0.25), Vector3(0, 2.15, -3.95), Color("3b2418"))
	make_box("ShelfTop", Vector3(6.2, 0.22, 0.75), Vector3(0, 4.05, -3.55), Color("6b3f25"))
	make_box("ShelfBottom", Vector3(6.2, 0.22, 0.75), Vector3(0, 0.25, -3.55), Color("6b3f25"))
	for x in [-3.0, 3.0]:
		make_box("ShelfSide", Vector3(0.22, 4, 0.75), Vector3(x, 2.1, -3.55), Color("6b3f25"))

	for i in VINYL_COUNT:
		var x := -2.25 + i * 1.125
		var slot := make_interactive_box("JazzSlot%d" % i, Vector3(0.82, 1.15, 0.16), Vector3(x, 1.15, -3.31), Color("211917"), "slot", i)
		slot_nodes.append(slot)

	# Table with the unsorted records.
	make_box("TableTop", Vector3(5.5, 0.25, 2.0), Vector3(0, 1.05, 1.6), Color("51311f"))
	for x in [-2.25, 2.25]:
		make_box("TableLeg", Vector3(0.25, 1.1, 0.25), Vector3(x, 0.5, 1.6), Color("392216"))

	var colors := [Color("7b3045"), Color("304f72"), Color("86682e"), Color("446247"), Color("684072")]
	var titles := ["Midnight Blue", "Rain on 52nd", "Amber Notes", "Green Room", "Last Set"]
	for i in VINYL_COUNT:
		var x := -2.0 + i
		var vinyl := make_interactive_box(titles[i], Vector3(0.82, 0.82, 0.10), Vector3(x, 1.62, 1.55), colors[i], "vinyl", i)
		vinyl.rotation = Vector3(deg_to_rad(-12), 0.0, 0.0)
		vinyl_nodes.append(vinyl)

	# Lanzamientos de la sección de artistas independientes.
	for artist_id in artist_titles.size():
		var display := create_artist_display(
			artist_id,
			artist_titles[artist_id],
			artist_names[artist_id],
			artist_genres[artist_id],
			artist_cover_paths[artist_id],
			artist_shelf_positions[artist_id]
		)
		artist_records.append(display)
	artist_record = artist_records[0]

	# Turntable table and player.
	make_box("TurntableStand", Vector3(2.8, 0.9, 2.1), Vector3(4.15, 0.45, 1.2), Color("34231d"))
	# Amplificador con faders arrastrables, como una pequeña mezcladora.
	make_box("Amplifier", Vector3(2.35, 0.72, 0.18), Vector3(4.15, 0.48, 2.30), Color("181715"))
	# Volumen a la derecha, integrado en la superficie de la tornamesa.
	make_box("VolumeTrack", Vector3(0.055, 0.025, 0.72), Vector3(4.91, 1.205, 1.43), Color("3e4146"))
	volume_fader = make_interactive_box("VolumeFader", Vector3(0.22, 0.055, 0.13), Vector3(4.91, 1.245, 1.46), Color("d7d9da"), "fader_volume", 0)
	# RPM a la izquierda mediante tres botones pequeños.
	make_interactive_box("RPM45", Vector3(0.18, 0.045, 0.12), Vector3(3.08, 1.225, 0.64), Color("82705c"), "rpm_45", 0)
	make_interactive_box("RPM33", Vector3(0.18, 0.045, 0.12), Vector3(3.08, 1.225, 0.84), Color("d5b16d"), "rpm_33", 0)
	make_interactive_box("RPM78", Vector3(0.18, 0.045, 0.12), Vector3(3.08, 1.225, 1.04), Color("82705c"), "rpm_78", 0)
	var amp_controls := Label3D.new()
	amp_controls.text = "RPM\n45   33⅓   78                         VOLUMEN"
	amp_controls.position = Vector3(4.12, 1.29, 0.45)
	amp_controls.font_size = 18
	amp_controls.modulate = Color("e7c691")
	amp_controls.outline_size = 4
	add_child(amp_controls)
	amp_display = Label3D.new()
	amp_display.position = Vector3(4.15, 0.88, 2.41)
	amp_display.font_size = 23
	amp_display.modulate = Color("8fe69b")
	amp_display.outline_size = 4
	add_child(amp_display)
	var player_body := make_interactive_box("Turntable", Vector3(2.55, 0.27, 1.75), Vector3(4.15, 1.05, 1.2), Color("111317"), "turntable", 0)
	# Plato metálico inspirado en tornamesas de DJ.
	var platter := MeshInstance3D.new()
	var platter_mesh := CylinderMesh.new()
	platter_mesh.top_radius = 0.77
	platter_mesh.bottom_radius = 0.77
	platter_mesh.height = 0.10
	platter_mesh.radial_segments = 96
	platter.mesh = platter_mesh
	platter.position = Vector3(3.95, 1.20, 1.18)
	var platter_material := material(Color("9b9da1"))
	platter_material.metallic = 0.9
	platter_material.roughness = 0.24
	platter.material_override = platter_material
	add_child(platter)
	# Botones cuadrados y luz de encendido en el chasis.
	make_box("StartStop", Vector3(0.15, 0.025, 0.15), Vector3(3.12, 1.225, 1.62), Color("d8d9d7"))
	make_box("CueButton", Vector3(0.11, 0.025, 0.08), Vector3(3.35, 1.225, 1.62), Color("a12e2e"))
	var power_led := OmniLight3D.new()
	power_led.position = Vector3(3.45, 1.25, 1.83)
	power_led.light_color = Color("ff3c31")
	power_led.light_energy = 0.7
	power_led.omni_range = 0.45
	add_child(power_led)
	turntable_disc = MeshInstance3D.new()
	var disc_mesh := CylinderMesh.new()
	disc_mesh.top_radius = 0.68
	disc_mesh.bottom_radius = 0.68
	disc_mesh.height = 0.035
	disc_mesh.radial_segments = 96
	turntable_disc.mesh = disc_mesh
	turntable_disc.position = Vector3(3.95, 1.27, 1.18)
	var vinyl_material := material(Color("09090c"))
	vinyl_material.metallic = 0.72
	vinyl_material.roughness = 0.28
	turntable_disc.material_override = vinyl_material
	turntable_disc.visible = false
	add_child(turntable_disc)
	# Surcos concéntricos que giran junto con el vinilo.
	for groove_radius in [0.31, 0.37, 0.43, 0.49, 0.55, 0.61]:
		var groove := MeshInstance3D.new()
		var ring := TorusMesh.new()
		ring.inner_radius = groove_radius - 0.006
		ring.outer_radius = groove_radius + 0.006
		ring.rings = 48
		ring.ring_segments = 6
		groove.mesh = ring
		groove.position.y = 0.022
		groove.material_override = material(Color("34343a"))
		turntable_disc.add_child(groove)
	# Etiqueta circular central con la portada del lanzamiento.
	turntable_label = MeshInstance3D.new()
	var label_mesh := CylinderMesh.new()
	label_mesh.top_radius = 0.245
	label_mesh.bottom_radius = 0.245
	label_mesh.height = 0.042
	label_mesh.radial_segments = 72
	turntable_label.mesh = label_mesh
	turntable_label.position.y = 0.022
	var label_material := StandardMaterial3D.new()
	label_material.albedo_color = Color("d99b45")
	label_material.roughness = 0.6
	turntable_label.material_override = label_material
	turntable_disc.add_child(turntable_label)
	# Portada completa, más pequeña y sin recorte circular.
	var label_art := MeshInstance3D.new()
	var label_art_mesh := QuadMesh.new()
	label_art_mesh.size = Vector2(0.36, 0.36)
	label_art.mesh = label_art_mesh
	label_art.position = Vector3(0, 0.046, 0)
	label_art.rotation = Vector3(-PI * 0.5, 0, 0)
	var label_art_material := StandardMaterial3D.new()
	label_art_material.albedo_texture = load("res://assets/covers/hoy_es_diferente.png")
	label_art_material.roughness = 0.58
	label_art.material_override = label_art_material
	turntable_art_material = label_art_material
	turntable_disc.add_child(label_art)
	# Brazo con pivote: descansa a la derecha y entra suavemente al borde.
	var arm_base := MeshInstance3D.new()
	var arm_base_mesh := CylinderMesh.new()
	arm_base_mesh.top_radius = 0.22
	arm_base_mesh.bottom_radius = 0.24
	arm_base_mesh.height = 0.16
	arm_base_mesh.radial_segments = 48
	arm_base.mesh = arm_base_mesh
	arm_base.position = Vector3(5.08, 1.25, 0.52)
	arm_base.material_override = material(Color("24262a"))
	add_child(arm_base)
	tonearm_pivot = Node3D.new()
	tonearm_pivot.position = Vector3(5.08, 1.36, 0.52)
	tonearm_pivot.rotation.y = tonearm_rest_angle
	add_child(tonearm_pivot)
	var tonearm := MeshInstance3D.new()
	var arm_mesh := BoxMesh.new()
	arm_mesh.size = Vector3(0.075, 0.075, 1.10)
	tonearm.mesh = arm_mesh
	tonearm.position = Vector3(0, 0, -0.52)
	tonearm.material_override = material(Color("c4aa75"))
	tonearm_pivot.add_child(tonearm)
	var needle := MeshInstance3D.new()
	var needle_mesh := BoxMesh.new()
	needle_mesh.size = Vector3(0.14, 0.10, 0.16)
	needle.mesh = needle_mesh
	needle.position = Vector3(0, -0.025, -1.07)
	needle.material_override = material(Color("272321"))
	tonearm_pivot.add_child(needle)
	var counterweight := MeshInstance3D.new()
	var weight_mesh := CylinderMesh.new()
	weight_mesh.top_radius = 0.12
	weight_mesh.bottom_radius = 0.12
	weight_mesh.height = 0.20
	weight_mesh.radial_segments = 32
	counterweight.mesh = weight_mesh
	counterweight.rotation = Vector3(PI * 0.5, 0, 0)
	counterweight.position = Vector3(0, 0, 0.10)
	counterweight.material_override = material(Color("34363b"))
	tonearm_pivot.add_child(counterweight)

	audio_player = AudioStreamPlayer3D.new()
	audio_player.position = player_body.position
	audio_player.max_distance = 18.0
	var generator := AudioStreamGenerator.new()
	generator.mix_rate = 44100.0
	generator.buffer_length = 0.35
	audio_player.stream = generator
	add_child(audio_player)
	return_sound_player = AudioStreamPlayer3D.new()
	return_sound_player.max_distance = 9.0
	var return_generator := AudioStreamGenerator.new()
	return_generator.mix_rate = 44100.0
	return_generator.buffer_length = 0.18
	return_sound_player.stream = return_generator
	add_child(return_sound_player)
	setup_music_analyzer()
	audio_player.finished.connect(_on_audio_finished)
	build_led_spectrum()
	update_amplifier()

	# Restorable café lighting.
	var light_positions := [Vector3(-4, 3.7, 1.2), Vector3(-1.4, 3.7, 1.2), Vector3(1.4, 3.7, 1.2), Vector3(4, 3.7, 1.2), Vector3(0, 4.4, -2.5)]
	for pos in light_positions:
		var light := OmniLight3D.new()
		light.position = pos
		light.light_color = Color("ffb866")
		light.light_energy = 0.0
		light.omni_range = 5.0
		add_child(light)
		cafe_lights.append(light)

func build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var panel := ColorRect.new()
	panel.color = Color(0.04, 0.025, 0.02, 0.86)
	panel.position = Vector2(24, 22)
	panel.size = Vector2(420, 142)
	layer.add_child(panel)

	var title := Label.new()
	title.text = "SECCIÓN DE JAZZ"
	title.position = Vector2(22, 14)
	title.add_theme_font_size_override("font_size", 24)
	panel.add_child(title)

	progress_label = Label.new()
	progress_label.position = Vector2(22, 50)
	progress_label.add_theme_font_size_override("font_size", 20)
	panel.add_child(progress_label)

	status_label = Label.new()
	status_label.position = Vector2(22, 82)
	status_label.add_theme_color_override("font_color", Color("e6b96c"))
	panel.add_child(status_label)

	instruction_label = Label.new()
	instruction_label.text = "WASD: caminar | E/clic: ordenar jazz y controles | Q: discos | R: inspeccionar | F: linterna | Esc: cursor"
	instruction_label.position = Vector2(24, 670)
	instruction_label.add_theme_font_size_override("font_size", 16)
	layer.add_child(instruction_label)
	var crosshair := Label.new()
	crosshair.text = "+"
	crosshair.set_anchors_preset(Control.PRESET_CENTER)
	crosshair.position = Vector2(-7, -14)
	crosshair.add_theme_font_size_override("font_size", 24)
	layer.add_child(crosshair)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		if active_fader != "":
			drag_fader(-event.relative.y)
		else:
			player.rotate_y(-event.relative.x * MOUSE_SENSITIVITY)
			look_pitch = clamp(look_pitch - event.relative.y * MOUSE_SENSITIVITY, -1.35, 1.35)
			player_camera.rotation.x = look_pitch
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_ESCAPE:
			active_fader = ""
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		elif event.physical_keycode == KEY_E:
			interact_from_center()
		elif event.physical_keycode == KEY_F:
			flashlight.visible = not flashlight.visible
			status_label.text = "Linterna encendida." if flashlight.visible else "Linterna apagada."
		elif event.physical_keycode == KEY_Q:
			toggle_artist_record()
		elif event.physical_keycode == KEY_R:
			toggle_hand_inspection()
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
				Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
				return
			var center := get_viewport().get_visible_rect().size * 0.5
			var origin := player_camera.project_ray_origin(center)
			var end := origin + player_camera.project_ray_normal(center) * 4.0
			var query := PhysicsRayQueryParameters3D.create(origin, end)
			query.exclude = [player.get_rid()]
			var hit := get_world_3d().direct_space_state.intersect_ray(query)
			if hit and hit.collider.has_meta("kind"):
				var kind: String = hit.collider.get_meta("kind")
				if kind == "fader_volume":
					active_fader = kind
					status_label.text = "Arrastra verticalmente y suelta para ajustar."
				else:
					handle_click(hit.collider)
		else:
			active_fader = ""

func interact_from_center() -> void:
	var center := get_viewport().get_visible_rect().size * 0.5
	var origin := player_camera.project_ray_origin(center)
	var end := origin + player_camera.project_ray_normal(center) * 4.0
	var query := PhysicsRayQueryParameters3D.create(origin, end)
	query.exclude = [player.get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit and hit.collider.has_meta("kind"):
		handle_click(hit.collider)
	else:
		status_label.text = "Acércate y apunta a un objeto interactivo."

func handle_click(object: Object) -> void:
	var kind: String = object.get_meta("kind")
	var index: int = object.get_meta("index")
	if kind == "vinyl" and not placed[index]:
		artist_selected = false
		selected_vinyl = index
		status_label.text = "Seleccionado: %s" % vinyl_nodes[index].name
	elif kind == "artist_record":
		selected_vinyl = -1
		if artist_on_turntable:
			status_label.text = "Primero quita de la tornamesa: %s. Pulsa Q mirando la tornamesa." % artist_titles[turntable_artist_id]
		elif artist_holding:
			status_label.text = "Ya llevas un disco. Devuélvelo a su estante antes de tomar otro."
		else:
			status_label.text = "%s — pulsa Q para tomar el disco." % artist_titles[index]
	elif kind == "artist_slot":
		if artist_holding:
			status_label.text = "Pulsa Q mirando este estante para devolver el disco."
		else:
			status_label.text = "Espacio de %s." % artist_names[index]
	elif kind == "slot":
		place_selected(index)
	elif kind == "turntable":
		if artist_holding:
			status_label.text = "Pulsa Q mirando la tornamesa para poner el disco."
		elif artist_on_turntable:
			status_label.text = "Ya hay un disco en la tornamesa. Pulsa Q mirando la tornamesa para retirarlo."
		else:
			play_selected_record()
	elif kind == "rpm_45":
		rpm_mode = 0
		rpm_drag_position = 0.0
		update_amplifier()
		status_label.text = "45 RPM · lenta"
	elif kind == "rpm_33":
		rpm_mode = 1
		rpm_drag_position = 0.5
		update_amplifier()
		status_label.text = "33⅓ RPM · normal"
	elif kind == "rpm_78":
		rpm_mode = 2
		rpm_drag_position = 1.0
		update_amplifier()
		status_label.text = "78 RPM · rápida"
	elif kind == "fader_volume":
		status_label.text = "Mantén clic izquierdo y arrastra verticalmente."




func setup_music_analyzer() -> void:
	music_bus_index = AudioServer.get_bus_index("Music")
	if music_bus_index == -1:
		AudioServer.add_bus()
		music_bus_index = AudioServer.get_bus_count() - 1
		AudioServer.set_bus_name(music_bus_index, "Music")
	audio_player.bus = "Music"
	var analyzer_effect := AudioEffectSpectrumAnalyzer.new()
	analyzer_effect.buffer_length = 2.0
	analyzer_effect.fft_size = AudioEffectSpectrumAnalyzer.FFT_SIZE_1024
	AudioServer.add_bus_effect(music_bus_index, analyzer_effect, 0)
	spectrum_analyzer = AudioServer.get_bus_effect_instance(music_bus_index, 0)

func build_led_spectrum() -> void:
	# Diez bandas por ocho niveles, colocadas en el frontal del amplificador.
	var frequencies := 10
	var levels := 8
	for column in frequencies:
		var column_leds: Array[MeshInstance3D] = []
		for row in levels:
			var led := MeshInstance3D.new()
			var led_mesh := BoxMesh.new()
			led_mesh.size = Vector3(0.055, 0.025, 0.025)
			led.mesh = led_mesh
			led.position = Vector3(3.88 + column * 0.065, 0.31 + row * 0.052, 2.495)
			var led_color := Color("ff3b30") if row < 2 else (Color("d8ff3e") if row < 4 else (Color("19d9ff") if row < 7 else Color("d94cff")))
			var led_material := StandardMaterial3D.new()
			led_material.albedo_color = led_color
			led_material.emission_enabled = true
			led_material.emission = led_color
			led_material.emission_energy_multiplier = 2.6
			led.material_override = led_material
			led.visible = false
			add_child(led)
			column_leds.append(led)
		led_columns.append(column_leds)

func update_led_spectrum() -> void:
	if spectrum_analyzer == null and music_bus_index >= 0:
		spectrum_analyzer = AudioServer.get_bus_effect_instance(music_bus_index, 0)
	for column in led_columns.size():
		var active_levels: int = 0
		if audio_player != null and audio_player.playing and spectrum_analyzer != null:
			var low_frequency: float = lerpf(55.0, 9000.0, float(column) / float(led_columns.size()))
			var high_frequency: float = lerpf(55.0, 9000.0, float(column + 1) / float(led_columns.size()))
			var magnitude: float = spectrum_analyzer.get_magnitude_for_frequency_range(low_frequency, high_frequency).length()
			var decibels: float = linear_to_db(maxf(magnitude, 0.0001))
			active_levels = int(clamp(remap(decibels, -58.0, -8.0, 0.0, 8.0), 0.0, 8.0))
		for row in led_columns[column].size():
			led_columns[column][row].visible = row < active_levels

func update_tonearm_from_song() -> void:
	if not artist_on_turntable or not audio_player.playing:
		return
	if audio_player.stream == null:
		return
	var duration: float = audio_player.stream.get_length()
	if duration <= 0.0:
		return
	var progress: float = clampf(audio_player.get_playback_position() / duration, 0.0, 1.0)
	# El brazo barre de derecha a izquierda y termina junto al centro.
	tonearm_target_angle = lerp(tonearm_start_angle, tonearm_center_angle, progress)

func _on_audio_finished() -> void:
	if artist_on_turntable:
		record_spinning = false
		tonearm_target_angle = tonearm_center_angle
		status_label.text = "La canción terminó. El brazo llegó al centro."
		await get_tree().create_timer(0.55).timeout
		if artist_on_turntable and not audio_player.playing:
			tonearm_target_angle = tonearm_rest_angle
			status_label.text = "El brazo regresó a su soporte."

func drag_fader(vertical_delta: float) -> void:
	if active_fader == "fader_volume":
		amp_volume_db = clamp(amp_volume_db + vertical_delta * 0.16, -30.0, 6.0)

	update_amplifier()

func get_playback_multiplier() -> float:
	match rpm_mode:
		0:
			return 0.85
		2:
			return 1.35
		_:
			return 1.0

func get_rpm_label() -> String:
	match rpm_mode:
		0:
			return "45 RPM · LENTA"
		2:
			return "78 RPM · RÁPIDA"
		_:
			return "33⅓ RPM · NORMAL"

func update_amplifier() -> void:
	if audio_player != null:
		audio_player.volume_db = amp_volume_db
		audio_player.pitch_scale = get_playback_multiplier()
	if volume_fader != null:
		var volume_t: float = inverse_lerp(-30.0, 6.0, amp_volume_db)
		volume_fader.position.z = lerp(1.75, 1.10, volume_t)
	if amp_display != null:
		amp_display.text = "%+.0f dB      %s" % [amp_volume_db, get_rpm_label()]

func toggle_artist_record() -> void:
	var hit := get_center_hit()
	if artist_holding:
		if hit and hit.collider.has_meta("kind"):
			var held_kind: String = hit.collider.get_meta("kind")
			var held_index: int = int(hit.collider.get_meta("index"))
			if held_kind == "turntable":
				if artist_on_turntable:
					status_label.text = "La tornamesa está ocupada. Retira primero el disco actual."
				else:
					put_artist_on_turntable()
				return
			if held_kind == "artist_slot":
				place_artist_on_shelf(held_index)
				return
		status_label.text = "Llevas un disco. Mira la tornamesa para ponerlo o su estante para devolverlo."
		return
	if artist_on_turntable:
		if hit and hit.collider.has_meta("kind") and hit.collider.get_meta("kind") == "turntable":
			active_artist_id = turntable_artist_id
			artist_record = artist_records[active_artist_id]
			take_artist_record(true)
		else:
			status_label.text = "Primero quita de la tornamesa: %s. Pulsa Q mirando la tornamesa." % artist_titles[turntable_artist_id]
		return
	if hit and hit.collider.has_meta("kind") and hit.collider.get_meta("kind") == "artist_record":
		active_artist_id = int(hit.collider.get_meta("index"))
		artist_record = artist_records[active_artist_id]
		take_artist_record(false)
	else:
		status_label.text = "Apunta a una funda de artista y pulsa Q."

func get_center_hit() -> Dictionary:
	var center := get_viewport().get_visible_rect().size * 0.5
	var origin := player_camera.project_ray_origin(center)
	var end := origin + player_camera.project_ray_normal(center) * 4.0
	var query := PhysicsRayQueryParameters3D.create(origin, end)
	query.exclude = [player.get_rid()]
	return get_world_3d().direct_space_state.intersect_ray(query)

func take_artist_record(from_turntable: bool) -> void:
	if from_turntable:
		audio_player.stop()
		turntable_disc.visible = false
		record_spinning = false
		tonearm_target_angle = tonearm_rest_angle
		artist_on_turntable = false
		turntable_artist_id = -1
	artist_holding = true
	artist_selected = true
	hand_inspect_back = false
	hand_bob_time = 0.0
	selected_vinyl = -1
	artist_record.visible = true
	artist_record.collision_layer = 0
	artist_record.collision_mask = 0
	artist_record.reparent(player_camera)
	artist_record.position = Vector3(0.34, -0.24, -0.82)
	artist_record.rotation = Vector3(deg_to_rad(-8.0), deg_to_rad(-13.0), deg_to_rad(-5.0))
	artist_record.scale = Vector3.ONE * 0.56
	status_label.text = "Llevas: %s — %s. Pulsa R para mirar la contraportada." % [artist_titles[active_artist_id], artist_names[active_artist_id]]

func put_artist_on_turntable() -> void:
	if artist_on_turntable:
		status_label.text = "No puedes poner un disco sobre otro. Retira el actual con Q."
		return
	artist_holding = false
	hand_inspect_back = false
	artist_on_turntable = true
	turntable_artist_id = active_artist_id
	artist_selected = true
	artist_record.reparent(self)
	artist_record.visible = false
	artist_record.scale = Vector3.ONE
	update_turntable_art(active_artist_id)
	play_selected_record()

func place_artist_on_shelf(slot_id: int) -> void:
	if slot_id != active_artist_id:
		status_label.text = "Esa funda pertenece a %s." % artist_names[slot_id]
		return
	artist_holding = false
	artist_selected = false
	hand_inspect_back = false
	var start_transform: Transform3D = artist_record.global_transform
	artist_record.reparent(self)
	artist_record.global_transform = start_transform
	artist_record.visible = true
	artist_record.collision_layer = 0
	artist_record.collision_mask = 0
	var tween: Tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(artist_record, "position", artist_shelf_positions[active_artist_id], 0.38).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(artist_record, "rotation", Vector3.ZERO, 0.38).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(artist_record, "scale", Vector3.ONE, 0.38).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.finished.connect(_on_artist_returned_to_shelf.bind(artist_record, active_artist_id))
	play_return_sound(artist_shelf_positions[active_artist_id])
	status_label.text = "Devolviendo %s a su estante..." % artist_titles[active_artist_id]

func update_carried_record(delta: float) -> void:
	if not artist_holding or artist_record == null or artist_record.get_parent() != player_camera:
		return
	hand_bob_time += delta
	var bob: float = sin(hand_bob_time * 3.2) * 0.018
	var target_position: Vector3 = Vector3(0.34, -0.24 + bob, -0.82)
	var target_yaw: float = deg_to_rad(167.0) if hand_inspect_back else deg_to_rad(-13.0)
	var target_roll: float = deg_to_rad(4.0) if hand_inspect_back else deg_to_rad(-5.0)
	artist_record.position = artist_record.position.lerp(target_position, min(1.0, delta * 8.0))
	artist_record.rotation.x = lerp_angle(artist_record.rotation.x, deg_to_rad(-8.0), min(1.0, delta * 7.0))
	artist_record.rotation.y = lerp_angle(artist_record.rotation.y, target_yaw, min(1.0, delta * 7.0))
	artist_record.rotation.z = lerp_angle(artist_record.rotation.z, target_roll, min(1.0, delta * 7.0))
	artist_record.scale = artist_record.scale.lerp(Vector3.ONE * 0.56, min(1.0, delta * 8.0))

func toggle_hand_inspection() -> void:
	if not artist_holding:
		status_label.text = "Toma un disco con Q para inspeccionarlo."
		return
	hand_inspect_back = not hand_inspect_back
	if hand_inspect_back:
		status_label.text = "Contraportada: %s · %s · %s" % [artist_titles[active_artist_id], artist_names[active_artist_id], artist_genres[active_artist_id]]
	else:
		status_label.text = "Portada: %s — %s" % [artist_titles[active_artist_id], artist_names[active_artist_id]]

func _on_artist_returned_to_shelf(record: StaticBody3D, returned_artist_id: int) -> void:
	if record == null:
		return
	record.position = artist_shelf_positions[returned_artist_id]
	record.rotation = Vector3.ZERO
	record.scale = Vector3.ONE
	record.collision_layer = 1
	record.collision_mask = 1
	status_label.text = "%s volvió a su estante. Ya puedes tomar otro disco." % artist_titles[returned_artist_id]

func play_return_sound(position: Vector3) -> void:
	if return_sound_player == null:
		return
	return_sound_player.position = position
	return_sound_player.stop()
	return_sound_player.play()
	return_sound_playback = return_sound_player.get_stream_playback()
	return_sound_time = 0.0

func fill_return_sound() -> void:
	if return_sound_playback == null:
		return
	var frames: int = return_sound_playback.get_frames_available()
	var sample_rate: float = 44100.0
	for _i in frames:
		if return_sound_time > 0.16:
			return_sound_playback = null
			return
		var envelope: float = maxf(0.0, 1.0 - return_sound_time / 0.16)
		var tone: float = sin(TAU * 230.0 * return_sound_time) * 0.035 * envelope
		var click: float = sin(TAU * 1480.0 * return_sound_time) * 0.025 * exp(-return_sound_time * 42.0)
		var mixed: float = tone + click
		return_sound_playback.push_frame(Vector2(mixed, mixed))
		return_sound_time += 1.0 / sample_rate

func update_turntable_art(artist_id: int) -> void:
	if turntable_art_material != null:
		turntable_art_material.albedo_texture = load(artist_cover_paths[artist_id])


func place_selected(slot_index: int) -> void:
	if selected_vinyl < 0:
		status_label.text = "Primero selecciona un vinilo."
		return
	if placed[slot_index]:
		status_label.text = "Ese espacio ya está ocupado."
		return
	# En este prototipo cada portada corresponde al espacio con el mismo orden.
	if selected_vinyl != slot_index:
		status_label.text = "No encaja: revisa el orden de las portadas."
		return
	placed[selected_vinyl] = true
	var record := vinyl_nodes[selected_vinyl]
	record.position = slot_nodes[slot_index].position + Vector3(0, 0, 0.12)
	record.rotation = Vector3.ZERO
	status_label.text = "%s restauró parte de la cafetería." % record.name
	selected_vinyl = -1
	update_progress()

func update_progress() -> void:
	var completed := placed.count(true)
	var percent := completed * 100 / VINYL_COUNT
	progress_label.text = "%d / %d vinilos — %d%%" % [completed, VINYL_COUNT, percent]
	for i in cafe_lights.size():
		var target := 2.4 if i < completed else 0.0
		var tween: Tween = create_tween()
		tween.tween_property(cafe_lights[i], "light_energy", target, 0.8)
	if completed == VINYL_COUNT:
		status_label.text = "¡Jazz completo! La cafetería vuelve a respirar."

func play_selected_record() -> void:
	if artist_selected and active_artist_id >= 0:
		tonearm_target_angle = tonearm_start_angle
		turntable_disc.visible = true
		record_spinning = true
		audio_playback = null
		audio_player.stop()
		audio_player.stream = load(artist_audio_paths[active_artist_id])
		update_turntable_art(active_artist_id)
		audio_player.play()
		status_label.text = "Reproduciendo: %s — %s" % [artist_titles[active_artist_id], artist_names[active_artist_id]]
		return
	if selected_vinyl < 0:
		status_label.text = "Selecciona un vinilo y vuelve a tocar la tornamesa."
		return
	tonearm_target_angle = tonearm_start_angle
	turntable_disc.visible = true
	record_spinning = true
	audio_phase = float(selected_vinyl) * 0.7
	audio_time = 0.0
	var generator := AudioStreamGenerator.new()
	generator.mix_rate = 44100.0
	generator.buffer_length = 0.35
	audio_player.stream = generator
	audio_player.play()
	audio_playback = audio_player.get_stream_playback()
	status_label.text = "Reproduciendo: %s (demo generada)" % vinyl_nodes[selected_vinyl].name

func fill_jazz_audio() -> void:
	if audio_playback == null:
		return
	var frames := audio_playback.get_frames_available()
	var sample_rate := 44100.0
	var chords := [[220.0, 261.63, 329.63], [196.0, 246.94, 293.66], [174.61, 220.0, 261.63], [196.0, 233.08, 293.66]]
	for _i in frames:
		var chord: Array = chords[int(audio_time / 1.5) % chords.size()]
		var sample := 0.0
		for frequency in chord:
			sample += sin(TAU * float(frequency) * audio_time + audio_phase) * 0.055
		var bass := sin(TAU * float(chord[0]) * 0.5 * audio_time) * 0.07
		var pulse := exp(-fmod(audio_time, 0.75) * 18.0) * sin(TAU * 880.0 * audio_time) * 0.025
		var mixed := sample + bass + pulse
		audio_playback.push_frame(Vector2(mixed, mixed))
		audio_time += 1.0 / sample_rate


func create_artist_display(artist_id: int, song_title: String, artist_name: String, genre: String, cover_path: String, shelf_position: Vector3) -> StaticBody3D:
	make_box("ArtistPedestal%d" % artist_id, Vector3(1.8, 1.05, 1.15), shelf_position + Vector3(0, -1.03, -0.07), Color("2b1d18"))
	var slot := make_interactive_box("ArtistSlot%d" % artist_id, Vector3(1.35, 1.35, 0.08), shelf_position + Vector3(0, 0, -0.07), Color("1c1512"), "artist_slot", artist_id)
	artist_slots.append(slot)
	var record := make_interactive_box("%s — %s" % [song_title, artist_name], Vector3(1.15, 1.15, 0.10), shelf_position, Color("17110f"), "artist_record", artist_id)
	var front := MeshInstance3D.new()
	var front_quad := QuadMesh.new()
	front_quad.size = Vector2(1.15, 1.15)
	front.mesh = front_quad
	front.position = Vector3(0, 0, 0.056)
	var front_material := StandardMaterial3D.new()
	front_material.albedo_texture = load(cover_path)
	front_material.roughness = 0.62
	front.material_override = front_material
	record.add_child(front)
	var back := MeshInstance3D.new()
	var back_quad := QuadMesh.new()
	back_quad.size = Vector2(1.15, 1.15)
	back.mesh = back_quad
	back.position = Vector3(0, 0, -0.056)
	back.rotation = Vector3(0.0, PI, 0.0)
	back.material_override = material(Color("d49a52"))
	record.add_child(back)
	var back_text := Label3D.new()
	back_text.text = "%s\n\n%s\n\n%s" % [song_title.to_upper(), artist_name.to_upper(), genre.to_upper()]
	back_text.position = Vector3(0, 0, -0.062)
	back_text.rotation = Vector3(0.0, PI, 0.0)
	back_text.font_size = 34
	back_text.modulate = Color("25150d")
	back_text.outline_modulate = Color("e6b56c")
	back_text.outline_size = 3
	back_text.double_sided = false
	record.add_child(back_text)
	var display_label := Label3D.new()
	display_label.text = "ARTISTAS INDEPENDIENTES\n%s\n%s" % [artist_name, song_title]
	display_label.position = shelf_position + Vector3(0, 1.0, -0.02)
	display_label.font_size = 27
	display_label.modulate = Color("f1c27d")
	display_label.outline_size = 6
	add_child(display_label)
	return record

func make_box(label: String, size: Vector3, pos: Vector3, color: Color) -> MeshInstance3D:
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = label
	var box := BoxMesh.new()
	box.size = size
	mesh_instance.mesh = box
	mesh_instance.position = pos
	mesh_instance.material_override = material(color)
	add_child(mesh_instance)
	return mesh_instance

func make_interactive_box(label: String, size: Vector3, pos: Vector3, color: Color, kind: String, index: int) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = label
	body.position = pos
	body.set_meta("kind", kind)
	body.set_meta("index", index)
	var visual := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	visual.mesh = box
	visual.material_override = material(color)
	body.add_child(visual)
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	body.add_child(collision)
	add_child(body)
	return body

func make_collision_box(size: Vector3, pos: Vector3) -> void:
	var body := StaticBody3D.new()
	body.position = pos
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	body.add_child(collision)
	add_child(body)

func material(color: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.72
	return mat
