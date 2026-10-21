extends Node3D

# La Última Abeja — prototipo educativo en Godot 4.
# Todo el arte de este prototipo se crea con mallas primitivas propias.

const FLOWERS_LEVEL_1 := 5
const FLOWERS_LEVEL_2 := 8
const WORLD_LIMIT := 18.0
const FLY_SPEED := 7.0
const ENERGY_DRAIN := 3.0
const POLLEN_ENERGY := 18.0

var level := 1
var score := 0
var energy := 100.0
var pollinated := 0
var target_flowers := FLOWERS_LEVEL_1
var playing := false
var ended := false
var bee: Node3D
var camera: Camera3D
var flowers: Array[Node3D] = []
var hazards: Array[Node3D] = []
var hive: Node3D
var hud_label: Label
var message_label: Label
var start_button: Button
var restart_button: Button
var next_button: Button
var menu_panel: ColorRect
var time_alive := 0.0
var bee_wings: Array[Node3D] = []
var bee_flight_time: float = 0.0
var flower_animation_time: float = 0.0
var animated_flowers: Array[Node3D] = []
var bee_target_tilt: float = 0.0
var hazard_animation_time: float = 0.0
var energy_bar: ProgressBar
var energy_value_label: Label
var pause_panel: ColorRect
var is_paused: bool = false
var best_score: int = 0
const SAVE_PATH: String = "user://bee_save.cfg"
var level_select_panel: ColorRect
var level_2_unlocked: bool = false
var farm_button: Button

func _ready() -> void:
	_load_game_data()
	_setup_environment()
	_build_world()
	_build_ui()
	_show_menu()

func _build_world() -> void:
	# Ambiente e iluminación
	var env := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_SKY
	environment.sky = Sky.new()
	env.environment = environment
	add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55, -25, 0)
	sun.light_energy = 1.2
	add_child(sun)
	camera = Camera3D.new()
	camera.position = Vector3(0, 13, 19)
	camera.rotation_degrees = Vector3(-32, 0, 0)
	camera.current = true
	add_child(camera)

func _make_material(color: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.9
	return mat

func _make_box(parent: Node, name: String, pos: Vector3, size: Vector3, color: Color) -> MeshInstance3D:
	var mesh_node := MeshInstance3D.new()
	mesh_node.name = name
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh_node.mesh = mesh
	mesh_node.position = pos
	mesh_node.material_override = _make_material(color)
	parent.add_child(mesh_node)
	return mesh_node

func _make_sphere(parent: Node, name: String, pos: Vector3, radius: float, color: Color) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.name = name
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	node.mesh = mesh
	node.position = pos
	node.material_override = _make_material(color)
	parent.add_child(node)
	return node

func _make_cylinder(parent: Node, name: String, pos: Vector3, radius: float, height: float, color: Color) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.name = name
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	node.mesh = mesh
	node.position = pos
	node.material_override = _make_material(color)
	parent.add_child(node)
	return node

func _clear_level_objects() -> void:
	animated_flowers.clear()
	for node in get_tree().get_nodes_in_group("level_object"):
		node.queue_free()
	flowers.clear()
	hazards.clear()


func _create_bee() -> void:
	bee = Node3D.new()
	bee.name = "Bee"
	bee.position = Vector3(0, 2.0, -12)
	add_child(bee)

	# Cuerpo amarillo
	_make_sphere(
		bee, "Body",
		Vector3.ZERO,
		0.62,
		Color("#FFC928")
	)

	# Cabeza
	_make_sphere(
		bee, "Head",
		Vector3(0, 0.12, -0.58),
		0.34,
		Color("#FFD83D")
	)

	# Franjas negras sobre el cuerpo
	for i in range(3):
		var stripe_z: float = -0.30 + float(i) * 0.28
		var stripe := _make_cylinder(
			bee,
			"Stripe_%d" % i,
			Vector3(0, 0, stripe_z),
			0.49,
			0.12,
			Color("#29252B")
		)
		stripe.rotation_degrees.x = 90
		
		bee_wings.clear()

	# Ojos blancos y pupilas negras
	for side in [-1.0, 1.0]:
		_make_sphere(
			bee, "Eye",
			Vector3(side * 0.19, 0.23, -0.83),
			0.105,
			Color.WHITE
		)
		_make_sphere(
			bee, "Pupil",
			Vector3(side * 0.20, 0.23, -0.92),
			0.047,
			Color("#20202A")
		)

		# Antenas
		_make_cylinder(
			bee, "Antenna",
			Vector3(side * 0.13, 0.47, -0.70),
			0.025,
			0.25,
			Color("#29252B")
		)
		_make_sphere(
			bee, "AntennaTip",
			Vector3(side * 0.13, 0.61, -0.70),
			0.055,
			Color("#29252B")
		)

				# Alas translúcidas azul claro
		var wing := _make_sphere(
			bee,
			"Wing",
			Vector3(side * 0.42, 0.42, 0.08),
			0.34,
			Color("#BDEBFF")
		)
		wing.scale = Vector3(0.75, 0.10, 1.30)
		bee_wings.append(wing)
		

func _animate_bee(delta: float) -> void:
	if not is_instance_valid(bee):
		return

	bee_flight_time += delta

	# Movimiento suave hacia arriba y abajo
	bee.position.y += sin(bee_flight_time * 5.0) * 0.002

	# Aleteo de las alas
	for i in range(bee_wings.size()):
		var wing: Node3D = bee_wings[i]
		if is_instance_valid(wing):
			var side := -1.0 if i == 0 else 1.0
			wing.rotation.z = side * sin(bee_flight_time * 25.0) * 0.35


func _build_level() -> void:
	_clear_level_objects()
	# Ground
	var ground_color := Color(0.35, 0.68, 0.28) if level == 1 else Color(0.72, 0.62, 0.28)
	var ground := _make_box(self, "Ground", Vector3(0, -0.45, 0), Vector3(38, 0.8, 38), ground_color)
	ground.add_to_group("level_object")
	# Decorative garden/crop rows
	for i in range(12):
		var x := -15.0 + float(i) * 2.7
		var plant_color := Color(0.14, 0.46, 0.18) if level == 1 else Color(0.28, 0.5, 0.12)
		var plant := _make_sphere(self, "Bush_%d" % i, Vector3(x, 0.15, -5.0), 0.9, plant_color)
		plant.scale = Vector3(1.2, 0.7, 1.1)
		plant.add_to_group("level_object")
		
	
	print("DEBUG: entrando al bloque de pinos. Nivel: ", level)

	# Pinos 3D del nivel 1
	if level == 1:
		var pine_positions: Array[Vector3] = [
			Vector3(-16, 0, -12),
			Vector3(-16, 0, 1),
			Vector3(-15, 0, 14),
			Vector3(16, 0, -13),
			Vector3(16, 0, 2),
			Vector3(15, 0, 15)
		]

		var pine_scales: Array[float] = [
			1.4, 1.1, 1.5, 1.3, 1.0, 1.4
		]

		for i in range(pine_positions.size()):
			_add_nature_model(
				"res://assets/nature/glTF/Pine_4.gltf",
				"NaturePine_%d" % i,
				pine_positions[i],
				pine_scales[i]
			)

		
	# Arboles redondeados estilo cartoon
	var tree_positions: Array[Vector3] = [
		Vector3(-16, 0, -12),
		Vector3(-16, 0, 1),
		Vector3(-15, 0, 14),
		Vector3(16, 0, -13),
		Vector3(16, 0, 2),
		Vector3(15, 0, 15)
	]

	for i in range(tree_positions.size()):
		var tree := Node3D.new()
		tree.name = "FantasyTree_%d" % i
		tree.position = tree_positions[i]
		add_child(tree)
		tree.add_to_group("level_object")

		# Tronco
		_make_cylinder(
			tree, "Trunk",
			Vector3(0, 1.0, 0),
			0.32, 2.0,
			Color("#98603D")
		)

		# Copas grandes y suaves
		var leaf_color := Color("#4EAA68") if level == 1 else Color("#65964A")

		_make_sphere(
			tree, "Crown",
			Vector3(0, 2.35, 0),
			1.15, leaf_color
		)

		_make_sphere(
			tree, "CrownLeft",
			Vector3(-0.65, 2.05, 0.1),
			0.78, leaf_color
		)

		_make_sphere(
			tree, "CrownRight",
			Vector3(0.65, 2.1, 0.05),
			0.82, leaf_color
		)

		# Frutos o flores decorativas
		if i % 2 == 0:
			_make_sphere(
				tree, "Fruit",
				Vector3(0.15, 2.45, -0.82),
				0.16,
				Color("#FFD477")
			)

	# Colinas suaves en los bordes del escenario
	for i in range(4):
		var hill := Node3D.new()
		hill.name = "FantasyHill_%d" % i
		hill.position = Vector3(
			-13.0 + float(i) * 8.5,
			-0.15,
			-17.0
		)
		add_child(hill)
		hill.add_to_group("level_object")

		var hill_color := Color("#8BCB83") if level == 1 else Color("#C5B875")

		var mound := _make_sphere(
			hill, "Mound",
			Vector3(0, 0, 0),
			2.5,
			hill_color
		)
		mound.scale = Vector3(1.8, 0.65, 0.8)


	# Colmena de fantasia estilo cartoon
	hive = Node3D.new()
	hive.name = "Hive"
	hive.position = Vector3(0, 1.2, 13)
	add_child(hive)
	hive.add_to_group("level_object")

	# Cuerpo principal de la colmena
	_make_sphere(
		hive, "HiveBody",
		Vector3.ZERO,
		1.0,
		Color("#C98543")
	)

	# Franjas doradas de miel
	_make_sphere(
		hive, "HoneyStripeTop",
		Vector3(0, 0.28, 0),
		0.91,
		Color("#FFD166")
	)

	_make_sphere(
		hive, "HoneyStripeBottom",
		Vector3(0, -0.35, 0),
		0.82,
		Color("#EBA642")
	)

	# Entrada oscura
	_make_sphere(
		hive, "Entrance",
		Vector3(0, -0.12, -0.87),
		0.25,
		Color("#38251D")
	)

	# Pequeño letrero decorativo
	_make_box(
		hive, "HiveSign",
		Vector3(0, 0.85, -0.65),
		Vector3(0.65, 0.22, 0.08),
		Color("#FFE5A0")
	)

	# Brillo decorativo dorado
	_make_sphere(
		hive, "MagicGlow",
		Vector3(0, 1.25, 0),
		0.13,
		Color("#FFF1A8")
	)
	# Flowers arranged in the flight area
	target_flowers = FLOWERS_LEVEL_1 if level == 1 else FLOWERS_LEVEL_2
	for i in range(target_flowers):
		var flower := Node3D.new()
		flower.name = "Flower_%d" % i
		flower.position = Vector3(-12.0 + float(i) * (24.0 / float(maxi(target_flowers - 1, 1))), 0.5, -7.0 + float(i % 3) * 3.0)
		add_child(flower)
		flower.add_to_group("level_object")
		flowers.append(flower)
		animated_flowers.append(flower)
		_make_cylinder(flower, "Stem", Vector3(0, 0.35, 0), 0.07, 0.7, Color(0.12, 0.48, 0.12))
		_make_sphere(flower, "Center", Vector3(0, 0.78, 0), 0.18, Color(1.0, 0.72, 0.05))
		var petal_color: Color = [Color(1.0, 0.35, 0.55), Color(0.75, 0.42, 1.0), Color(1.0, 0.8, 0.2)][i % 3]
		for p in range(5):
			var angle := TAU * float(p) / 5.0
			var petal := _make_sphere(flower, "Petal_%d" % p, Vector3(cos(angle) * 0.28, 0.78, sin(angle) * 0.28), 0.17, petal_color)
			petal.scale = Vector3(1.0, 0.45, 0.8)
	
	# Pesticide danger markers in level 2, fewer and clearly visible in level 1
	var hazard_count := 2 if level == 1 else 5
	for i in range(hazard_count):
		var hazard := Node3D.new()
		hazard.name = "Pesticide_%d" % i
		hazard.position = Vector3(-10.0 + float(i) * (20.0 / float(maxi(hazard_count - 1, 1))), 1.0, 2.0 if i % 2 == 0 else -3.0)
		add_child(hazard)
		hazard.add_to_group("level_object")
		_make_sphere(hazard, "WarningCloud", Vector3.ZERO, 0.75, Color(0.3, 0.8, 0.25, 0.65))
		_make_cylinder(hazard, "SprayCan", Vector3(0, -0.8, 0), 0.28, 0.7, Color(0.65, 0.75, 0.78))
		hazards.append(hazard)
	_create_bee()
	pollinated = 0
	energy = 100.0
	ended = false
	_update_hud()

func _build_ui() -> void:
	var canvas := CanvasLayer.new()
	canvas.name = "HUD"
	add_child(canvas)
	var panel := PanelContainer.new()
	panel.position = Vector2(18, 16)
	panel.custom_minimum_size = Vector2(360, 94)
	canvas.add_child(panel)
	hud_label = Label.new()
	hud_label.add_theme_font_size_override("font_size", 19)
	panel.add_child(hud_label)
	
	energy_bar = ProgressBar.new()
	energy_bar.name = "EnergyBar"
	energy_bar.min_value = 0
	energy_bar.max_value = 100
	energy_bar.value = 100
	energy_bar.show_percentage = false
	energy_bar.custom_minimum_size = Vector2(300, 18)
	panel.add_child(energy_bar)
	energy_value_label = Label.new()
	energy_value_label.text = "Energía: 100%"
	energy_value_label.add_theme_font_size_override("font_size", 15)
	panel.add_child(energy_value_label)
	message_label = Label.new()
	message_label.position = Vector2(20, 120)
	message_label.add_theme_font_size_override("font_size", 23)
	message_label.add_theme_color_override("font_color", Color(0.12, 0.1, 0.06))
	message_label.text = ""
	canvas.add_child(message_label)
	menu_panel = ColorRect.new()
	menu_panel.color = Color(0.04, 0.1, 0.08, 0.88)
	menu_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	menu_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.add_child(menu_panel)
	var title := Label.new()
	title.text = "LA ÚLTIMA ABEJA "
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.position = Vector2(0, 150)
	title.size = Vector2(1280, 70)
	title.add_theme_font_size_override("font_size", 42)
	title.add_theme_color_override("font_color", Color(1.0, 0.83, 0.2))
	menu_panel.add_child(title)
	var subtitle := Label.new()
	subtitle.text = "Poliniza flores, cuida tu energía y vuelve a la colmena."
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.position = Vector2(0, 230)
	subtitle.size = Vector2(1280, 40)
	subtitle.add_theme_font_size_override("font_size", 22)
	menu_panel.add_child(subtitle)
	var controls := Label.new()
	controls.text = "CONTROLES\nWASD: volar   |   ESPACIO: subir   |   CTRL DERECHO: bajar\nAcércate a las flores para polinizarlas. Evita las nubes verdes."
	controls.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	controls.position = Vector2(0, 290)
	controls.size = Vector2(1280, 110)
	controls.add_theme_font_size_override("font_size", 19)
	menu_panel.add_child(controls)
	start_button = Button.new()
	start_button.text = "JUGAR"
	_build_level_select()
	_build_pause_menu()
	start_button.position = Vector2(520, 430)
	start_button.size = Vector2(240, 58)
	start_button.add_theme_font_size_override("font_size", 24)
	menu_panel.add_child(start_button)
	start_button.pressed.connect(_start_game)

func _show_menu() -> void:
	playing = false
	menu_panel.visible = true
	message_label.text = ""

func _start_game() -> void:
	menu_panel.visible = false
	level_select_panel.visible = true
	playing = false
	
func _update_hud() -> void:
	if is_instance_valid(hud_label):
		hud_label.text = "Nivel: %d   Puntos: %d   Récord: %d\nFlores: %d/%d\nEnergía: %d%%" % [
	level,
	score,
	best_score,
	pollinated,
	target_flowers,
	int(maxf(energy, 0.0))
]
	
	if is_instance_valid(energy_bar):
		energy_bar.value = clampf(energy, 0.0, 100.0)

		if energy > 60.0:
			energy_bar.modulate = Color("#A8F078")
		elif energy > 30.0:
			energy_bar.modulate = Color("#FFD166")
		else:
			energy_bar.modulate = Color("#FF6B6B")

	if is_instance_valid(energy_value_label):
		energy_value_label.text = "Energía: %d%%" % int(maxf(energy, 0.0))


func _process(delta: float) -> void:
	if playing:
		_animate_bee(delta)
		_animate_flowers(delta)
		_animate_hazards(delta)

	if not playing or ended:
		return

	time_alive += delta
	energy -= ENERGY_DRAIN * delta

	var direction := Vector3.ZERO

	if Input.is_action_pressed("move_forward"):
		direction.z -= 1.0
	if Input.is_action_pressed("move_back"):
		direction.z += 1.0
	if Input.is_action_pressed("move_left"):
		direction.x -= 1.0
	if Input.is_action_pressed("move_right"):
		direction.x += 1.0
	if Input.is_action_pressed("move_up"):
		direction.y += 1.0
	if Input.is_action_pressed("move_down"):
		direction.y -= 1.0


	if direction.length() > 0.0:
		bee.position += direction.normalized() * FLY_SPEED * delta

	# Inclinar la abeja al girar
	var target_tilt: float = -direction.x * 0.25
	bee.rotation.z = lerpf(
		bee.rotation.z,
		target_tilt,
		minf(delta * 4.0, 1.0)
	)

	# Limites del escenario
	bee.position.x = clampf(bee.position.x, -17.0, 17.0)
	bee.position.z = clampf(bee.position.z, -17.0, 17.0)
	bee.position.y = clampf(bee.position.y, 0.8, 7.0)

	# Camara que sigue a la abeja
	camera.position = camera.position.lerp(
		bee.position + Vector3(0, 11, 14),
		delta * 2.0
	)

	camera.look_at(bee.position + Vector3(0, 0.3, 0), Vector3.UP)

	_check_flowers()
	_check_hazards(delta)

	if bee.global_position.distance_to(hive.global_position) < 1.8 and pollinated >= target_flowers:
		_win_level()

	if energy <= 0.0:
		_finish_game(false)

	_update_hud()



func _check_flowers() -> void:
	for flower in flowers:
		if not is_instance_valid(flower):
			continue

		if not flower.visible:
			continue

		var pollen_position: Vector3 = flower.global_position + Vector3(0, 0.7, 0)

		if bee.global_position.distance_to(pollen_position) < 1.25:
			_create_pollen_effect(pollen_position)
			_show_floating_points(pollen_position)

			flower.visible = false
			pollinated += 1
			score += 10
			_update_best_score()
			energy = minf(100.0, energy + POLLEN_ENERGY)

			message_label.text = "¡Flor polinizada! +10 puntos y energía recuperada."
			_update_hud()



func _create_pollen_effect(world_position: Vector3) -> void:
	var particles := GPUParticles3D.new()
	particles.name = "PollenEffect"
	particles.amount = 35
	particles.lifetime = 1.2
	particles.one_shot = true
	particles.explosiveness = 1.0
	particles.emitting = true

	# Las particulas se colocan en la posicion global de la flor
	add_child(particles)
	particles.global_position = world_position

	# Movimiento de los destellos
	var process_material := ParticleProcessMaterial.new()
	process_material.direction = Vector3(0, 1, 0)
	process_material.spread = 180.0
	process_material.initial_velocity_min = 1.0
	process_material.initial_velocity_max = 2.5
	process_material.gravity = Vector3(0, 0.5, 0)
	process_material.scale_min = 0.8
	process_material.scale_max = 1.5
	process_material.color = Color("#FFD76A")
	particles.process_material = process_material

	# Forma visible para las particulas
	var particle_mesh := SphereMesh.new()
	particle_mesh.radius = 0.10
	particle_mesh.height = 0.20

	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color("#FFD76A")
	material.emission_enabled = true
	material.emission = Color("#FFD76A")
	material.emission_energy_multiplier = 2.0
	particle_mesh.material = material

	particles.draw_pass_1 = particle_mesh

	# Eliminar el efecto cuando termine
	get_tree().create_timer(2.0).timeout.connect(
		func():
			if is_instance_valid(particles):
				particles.queue_free()
	)

		

func _setup_environment() -> void:
	var world := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_SKY

	var sky := Sky.new()
	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color("#5798D5")
	sky_material.sky_horizon_color = Color("#D4E9F8")
	sky_material.ground_bottom_color = Color("#647C55")
	sky_material.ground_horizon_color = Color("#C5D9B2")
	sky.sky_material = sky_material

	environment.sky = sky
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("#D9E8FF")
	environment.ambient_light_energy = 0.8
	world.environment = environment
	add_child(world)

	var sunlight := DirectionalLight3D.new()
	sunlight.name = "Sunlight"
	sunlight.rotation_degrees = Vector3(-45, -30, 0)
	sunlight.light_energy = 1.2
	add_child(sunlight)


func _check_hazards(delta: float) -> void:
	for hazard in hazards:
		if not is_instance_valid(hazard) or not hazard.visible:
			continue

		if bee.global_position.distance_to(hazard.global_position) < 1.5:
			energy = maxf(0.0, energy - 20.0 * delta)
			message_label.text = "☣ ¡Pesticidas! ¡Aléjate!"
			message_label.add_theme_color_override(
			"font_color",
	 Color("#8EDB45")
)


func _win_level() -> void:
	if ended:
		return

	if level == 1:
		level_2_unlocked = true
		farm_button.disabled = false
		level = 2
		_build_level()
		message_label.text = "¡Nivel 1 completado! Explora el campo de cultivo."
	else:
		_finish_game(true)


func _finish_game(victory: bool) -> void:
	ended = true
	playing = false
	menu_panel.visible = true

	var title_label := menu_panel.get_child(0) as Label
	if victory:
		title_label.text = "¡SALVASTE A LAS ABEJAS!"
		message_label.text = "¡Felicidades! Puntuación final: %d" % score
	else:
		title_label.text = "¡INTÉNTALO DE NUEVO!"
		message_label.text = "Te quedaste sin energía. Puntuación: %d" % score

	start_button.text = "JUGAR DE NUEVO"


func _animate_flowers(delta: float) -> void:
	flower_animation_time += delta

	for i in range(animated_flowers.size()):
		var flower: Node3D = animated_flowers[i]

		if not is_instance_valid(flower) or not flower.visible:
			continue

		flower.rotation.z = sin(
			flower_animation_time * 2.5 + float(i)
		) * 0.10
		

func _show_floating_points(world_position: Vector3) -> void:
	var label := Label3D.new()
	label.name = "FloatingPoints"
	label.text = "+10"
	label.font_size = 64
	label.pixel_size = 0.01
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.modulate = Color("#FFD76A")
	label.outline_size = 8
	label.outline_modulate = Color("#8A4B12")

	add_child(label)
	label.global_position = world_position + Vector3(0, 0.5, 0)

	var tween := create_tween()
	tween.set_parallel(true)

	tween.tween_property(
		label,
		"position:y",
		label.position.y + 1.5,
		1.0
	).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

	tween.tween_property(
		label,
		"modulate:a",
		0.0,
		1.0
	).set_delay(0.25)

	tween.chain().tween_callback(label.queue_free)
	

func _animate_hazards(delta: float) -> void:
	hazard_animation_time += delta

	for i in range(hazards.size()):
		var hazard: Node3D = hazards[i]

		if not is_instance_valid(hazard):
			continue

		var cloud := hazard.get_node_or_null("WarningCloud") as Node3D
		if cloud:
			cloud.scale = Vector3.ONE * (
				1.0 + sin(hazard_animation_time * 3.0 + float(i)) * 0.08
			)

		hazard.position.y = 1.0 + sin(
			hazard_animation_time * 1.5 + float(i)
		) * 0.12


func _build_pause_menu() -> void:
	pause_panel = ColorRect.new()
	pause_panel.name = "PausePanel"
	pause_panel.color = Color(0.03, 0.08, 0.06, 0.88)
	pause_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	pause_panel.visible = false
	pause_panel.process_mode = Node.PROCESS_MODE_ALWAYS
	$HUD.add_child(pause_panel)

	var title := Label.new()
	title.text = "JUEGO EN PAUSA"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.position = Vector2(0, 150)
	title.size = Vector2(1280, 70)
	title.add_theme_font_size_override("font_size", 42)
	title.add_theme_color_override("font_color", Color("#FFD76A"))
	pause_panel.add_child(title)

	var continue_button := Button.new()
	continue_button.text = "CONTINUAR"
	continue_button.position = Vector2(520, 270)
	continue_button.size = Vector2(240, 55)
	pause_panel.add_child(continue_button)
	continue_button.pressed.connect(_resume_game)

	var restart_button := Button.new()
	restart_button.text = "REINICIAR NIVEL"
	restart_button.position = Vector2(520, 340)
	restart_button.size = Vector2(240, 55)
	pause_panel.add_child(restart_button)
	restart_button.pressed.connect(_restart_level)

	var menu_button := Button.new()
	menu_button.text = "MENÚ PRINCIPAL"
	menu_button.position = Vector2(520, 410)
	menu_button.size = Vector2(240, 55)
	pause_panel.add_child(menu_button)
	menu_button.pressed.connect(_return_to_menu)
	

func _resume_game() -> void:
	is_paused = false
	get_tree().paused = false
	pause_panel.visible = false
	playing = true


func _restart_level() -> void:
	get_tree().paused = false
	is_paused = false
	ended = false
	score = 0
	time_alive = 0.0
	_build_level()
	pause_panel.visible = false
	menu_panel.visible = false
	playing = true


func _return_to_menu() -> void:
	get_tree().paused = false
	is_paused = false
	playing = false
	ended = false
	pause_panel.visible = false
	menu_panel.visible = true
	

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			if is_paused:
				_resume_game()
			elif playing and not ended:
				is_paused = true
				playing = false
				pause_panel.visible = true
				get_tree().paused = true
				

func _load_game_data() -> void:
	var config := ConfigFile.new()
	var error := config.load(SAVE_PATH)

	if error == OK:
		best_score = int(config.get_value("records", "best_score", 0))
	else:
		best_score = 0


func _save_game_data() -> void:
	var config := ConfigFile.new()
	config.set_value("records", "best_score", best_score)

	var error := config.save(SAVE_PATH)
	if error != OK:
		push_warning("No se pudo guardar el récord de puntuación.")


func _update_best_score() -> void:
	if score > best_score:
		best_score = score
		_save_game_data()
		

func _build_level_select() -> void:
	level_select_panel = ColorRect.new()
	level_select_panel.name = "LevelSelectPanel"
	level_select_panel.color = Color(0.04, 0.12, 0.09, 0.96)
	level_select_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	level_select_panel.visible = false
	level_select_panel.process_mode = Node.PROCESS_MODE_ALWAYS
	$HUD.add_child(level_select_panel)

	var title := Label.new()
	title.text = "ELIGE TU AVENTURA"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.position = Vector2(0, 100)
	title.size = Vector2(1280, 70)
	title.add_theme_font_size_override("font_size", 38)
	title.add_theme_color_override("font_color", Color("#FFD76A"))
	level_select_panel.add_child(title)

	var garden_button := Button.new()
	garden_button.text = "NIVEL 1\nJardín urbano"
	garden_button.position = Vector2(280, 250)
	garden_button.size = Vector2(300, 130)
	garden_button.add_theme_font_size_override("font_size", 24)
	level_select_panel.add_child(garden_button)
	garden_button.pressed.connect(func(): _select_level(1))

	farm_button = Button.new()
	farm_button.text = "NIVEL 2\nCampo de cultivo"
	farm_button.position = Vector2(700, 250)
	farm_button.size = Vector2(300, 130)
	farm_button.add_theme_font_size_override("font_size", 24)
	level_select_panel.add_child(farm_button)

	farm_button.disabled = not level_2_unlocked
	farm_button.pressed.connect(_select_level.bind(2))

	var back_button := Button.new()
	back_button.text = "VOLVER"
	back_button.position = Vector2(520, 460)
	back_button.size = Vector2(240, 55)
	level_select_panel.add_child(back_button)
	back_button.pressed.connect(func():
		level_select_panel.visible = false
		menu_panel.visible = true
	)


func _select_level(selected_level: int) -> void:
	if selected_level == 2 and not level_2_unlocked:
		return

	level = selected_level
	score = 0
	time_alive = 0.0
	ended = false
	playing = false

	_build_level()

	level_select_panel.visible = false
	menu_panel.visible = false
	playing = true
	

func _add_pine_tree(tree_position: Vector3, tree_scale: float = 1.0) -> void:
	var scene_path := "res://assets/nature/glTF/Pine_4.glTF"

	if not ResourceLoader.exists(scene_path):
		push_warning("No se encontró el modelo: " + scene_path)
		return

	var tree_scene := load(scene_path) as PackedScene

	if tree_scene == null:
		push_warning("No se pudo cargar Pine_4.glTF")
		return

	var tree := tree_scene.instantiate() as Node3D

	if tree == null:
		return

	tree.position = tree_position
	tree.scale = Vector3.ONE * tree_scale
	tree.name = "DecorativePine"
	add_child(tree)


func _add_nature_model(
	model_path: String,
	model_name: String,
	model_position: Vector3,
	model_scale: float = 1.0
) -> Node3D:
	if not ResourceLoader.exists(model_path):
		push_warning("No se encontró el modelo: " + model_path)
		return null

	var packed_scene := load(model_path) as PackedScene
	if packed_scene == null:
		push_warning("No se pudo cargar: " + model_path)
		return null

	var model := packed_scene.instantiate() as Node3D
	if model == null:
		push_warning("El modelo no tiene un nodo raíz Node3D: " + model_path)
		return null

	model.name = model_name
	model.position = model_position
	model.scale = Vector3.ONE * model_scale
	add_child(model)
	model.add_to_group("level_object")
	print("Pino cargado: ", model_name)
	return model
