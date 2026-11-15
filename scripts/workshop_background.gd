# workshop_background.gd
# The 3D scene behind every build minigame (TASKS.md step 12): a gray-box
# workshop where the toy-like staff from the intro get the rocket ready.
# It is only a picture: nothing here changes the score.
#
# Everything is built in code from data/minigames.json ("workshop"):
#   - a floor, a back wall, a light and a camera
#   - the rocket. How finished it looks depends on the minigame (set_job):
#       assembly = only the bottom stage stands, the top waits on the floor
#       hammer   = the whole rocket, with a scaffold tower next to it
#       fuel     = the whole rocket, with a fuel tank and a hose
#   - the workers. Each one walks along its path, stops at every point and
#     works there (swings an arm), then walks on. "carry" = holds a crate,
#     "lift" = stands on a platform that rides up and down with them.
extends Node3D

var settings: Dictionary          # minigames.json "workshop"
var job: String = "assembly"      # which minigame is playing
var rocket_root: Node3D
var workers: Array = []           # one Dictionary per worker (see add_worker)
var time: float = 0.0
var radio_clock: float = 0.0       # counts up to radio_every_seconds


func _ready() -> void:
	settings = Data.minigames["workshop"]
	build_room()
	add_camera()
	rocket_root = Node3D.new()
	add_child(rocket_root)
	build_rocket()
	for worker_settings in settings["workers"]:
		add_worker(worker_settings)


# Called by the minigame frame: "assembly", "hammer" or "fuel".
func set_job(new_job: String) -> void:
	job = new_job
	if rocket_root != null:
		build_rocket()


func _process(delta: float) -> void:
	time += delta
	radio_clock += delta
	if radio_clock >= settings["radio_every_seconds"]:
		radio_clock = 0.0
		Sfx.play("radio")   # the workshop radio beeps now and then
	for worker in workers:
		move_worker(worker, delta)


# ---------- the room ----------

func build_room() -> void:
	var env := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(settings["sky_color"])
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(settings["ambient_color"])
	environment.ambient_light_energy = settings["ambient_energy"]
	env.environment = environment
	add_child(env)

	var sun := DirectionalLight3D.new()
	sun.light_energy = settings["sun_energy"]
	sun.rotation_degrees = Vector3(-50, -30, 0)
	sun.shadow_enabled = false   # no shadows: faster in the browser
	add_child(sun)

	var floor_size: Array = settings["floor_size"]
	add_box(self, Vector3(floor_size[0], 0.2, floor_size[1]), Vector3(0, -0.1, 0), settings["floor_color"])
	var wall: Array = settings["wall"]
	add_box(self, Vector3(floor_size[0], wall[0], 0.3), Vector3(0, wall[0] / 2.0, wall[1]), settings["wall_color"])
	# An orange stripe along the wall, like a hangar.
	add_box(self, Vector3(floor_size[0], 0.25, 0.32), Vector3(0, wall[0] * 0.35, wall[1]), settings["stripe_color"])


func add_camera() -> void:
	var camera := Camera3D.new()
	camera.fov = settings["camera_fov"]
	add_child(camera)
	camera.position = array_to_vector(settings["camera_position"])
	camera.look_at(array_to_vector(settings["camera_look_at"]), Vector3.UP)
	camera.current = true


# ---------- the rocket ----------

func build_rocket() -> void:
	for child in rocket_root.get_children():
		child.queue_free()
	var r: Dictionary = settings["rocket"]
	rocket_root.position = array_to_vector(r["position"])
	var radius: float = r["radius"]
	var stage_h: float = r["stage_height"]
	var stages: int = int(r["stages_shown"][job])

	for i in stages:
		add_cylinder(rocket_root, radius, radius, stage_h, Vector3(0, stage_h * (i + 0.5), 0), r["body_color"])
		add_cylinder(rocket_root, radius * 1.02, radius * 1.02, 0.25, Vector3(0, stage_h * i + 0.4, 0), r["stripe_color"])
	# Four fins at the bottom.
	for k in 4:
		var fin := add_box(rocket_root, Vector3(0.12, 1.0, radius * 0.9), Vector3.ZERO, r["fin_color"])
		var angle: float = k * PI / 2.0
		fin.position = Vector3(sin(angle) * radius * 1.2, 0.5, cos(angle) * radius * 1.2)
		fin.rotation.y = angle

	var nose_top := add_cylinder(rocket_root, 0.0, radius, r["nose_height"], Vector3.ZERO, r["nose_color"])
	if stages >= 2:
		nose_top.position = Vector3(0, stage_h * stages + r["nose_height"] / 2.0, 0)
	else:
		# Assembly: the top stage and the nose wait on the floor next to the rocket.
		var waiting: Array = r["waiting_parts_offset"]
		var top := add_cylinder(rocket_root, radius, radius, stage_h, Vector3.ZERO, r["body_color"])
		top.rotation.z = PI / 2.0
		top.position = Vector3(waiting[0], radius, waiting[1])
		nose_top.rotation.z = PI / 2.0
		nose_top.position = Vector3(waiting[0] + stage_h / 2.0 + r["nose_height"] / 2.0, radius, waiting[1])

	if job == "hammer":
		build_scaffold(radius, stage_h * stages)
	if job == "fuel":
		build_fuel_tank(radius)


func build_scaffold(radius: float, height: float) -> void:
	var color: String = settings["rocket"]["scaffold_color"]
	var x: float = -(radius + 0.9)
	for corner in [Vector2(-0.5, -0.5), Vector2(0.5, -0.5), Vector2(-0.5, 0.5), Vector2(0.5, 0.5)]:
		add_box(rocket_root, Vector3(0.1, height, 0.1), Vector3(x + corner.x, height / 2.0, corner.y), color)
	var floors: int = int(height / 1.5)
	for i in range(1, floors + 1):
		add_box(rocket_root, Vector3(1.2, 0.08, 1.2), Vector3(x, i * 1.5, 0), color)


func build_fuel_tank(radius: float) -> void:
	var tank: Dictionary = settings["fuel_tank"]
	var pos: Vector3 = array_to_vector(tank["offset"])
	add_cylinder(rocket_root, tank["radius"], tank["radius"], tank["height"], pos + Vector3(0, tank["height"] / 2.0, 0), tank["color"])
	# The hose: a thin bar from the tank to the rocket's side.
	var start := pos + Vector3(0, 0.5, 0)
	var end := Vector3(signf(pos.x) * radius, 1.2, 0)
	var hose := add_box(rocket_root, Vector3(start.distance_to(end), 0.12, 0.12), (start + end) / 2.0, tank["hose_color"])
	hose.rotation.z = atan2(end.y - start.y, end.x - start.x)


# ---------- parts snapped on by Assembly (UPGRADE_PLAN_V2 step 18) ----------

var snapped_root: Node3D


func clear_snapped_parts() -> void:
	if is_instance_valid(snapped_root):
		snapped_root.queue_free()
	snapped_root = Node3D.new()
	rocket_root.add_child(snapped_root)


# One finished word = one part on the rocket. shape = fin, tank, rod, panel,
# dish or box. index spreads the parts around and up the rocket.
func snap_part(shape: String, index: int, color: String) -> void:
	if not is_instance_valid(snapped_root):
		clear_snapped_parts()
	var r: Dictionary = settings["rocket"]
	var radius: float = r["radius"]
	var angle: float = deg_to_rad(index * 137.0)   # spread evenly, like seeds in a sunflower
	var height: float = 0.6 + fmod(index * 0.55, r["stage_height"] - 0.9)
	var out := Vector3(sin(angle), 0, cos(angle))
	var holder := Node3D.new()
	snapped_root.add_child(holder)
	holder.position = out * radius + Vector3(0, height, 0)
	holder.rotation.y = angle
	match shape:
		"fin":
			add_box(holder, Vector3(0.1, 0.8, 0.6), Vector3(0, 0, 0.3), color)
		"tank":
			add_cylinder(holder, 0.22, 0.22, 0.8, Vector3(0, 0, 0.25), color)
		"rod":
			add_cylinder(holder, 0.04, 0.04, 0.9, Vector3(0, 0.3, 0.12), color)
		"panel":
			add_box(holder, Vector3(1.1, 0.5, 0.06), Vector3(0, 0, 0.12), color)
		"dish":
			var dish := add_cylinder(holder, 0.35, 0.05, 0.2, Vector3(0, 0, 0.25), color)
			dish.rotation.x = PI / 2.0
		_:
			add_box(holder, Vector3(0.35, 0.3, 0.3), Vector3(0, 0, 0.15), color)
	# Pop in: start big and settle, so the player sees it land.
	holder.scale = Vector3.ONE * 1.8
	var pop := holder.create_tween()
	pop.tween_property(holder, "scale", Vector3.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


# ---------- the workers ----------

func add_worker(worker_settings: Dictionary) -> void:
	var holder := Node3D.new()        # moves along the path
	add_child(holder)
	var person: Node3D = load(worker_settings["scene"]).instantiate()
	holder.add_child(person)
	var path: Array = []
	for point in worker_settings["path"]:
		path.append(array_to_vector(point))
	holder.position = path[0]
	var worker: Dictionary = {
		"holder": holder,
		"person": person,
		"path": path,
		"target": 1 % path.size(),
		"speed": float(worker_settings["walk_speed"]),
		"work_seconds": float(worker_settings["work_seconds"]),
		"work_left": float(worker_settings["work_seconds"]),
		"phase": randf() * TAU,
		"work_face_degrees": float(worker_settings["work_face_degrees"]),
		"work_sound": worker_settings.get("work_sound", ""),
	}
	person.rotation.y = deg_to_rad(worker["work_face_degrees"])
	if worker_settings.get("carry", false):
		var crate := add_box(person, Vector3(0.35, 0.3, 0.3), Vector3(0, 0.75, -0.35), settings["crate_color"])
		worker["crate"] = crate
	if worker_settings.get("lift", false):
		add_box(holder, Vector3(1.0, 0.1, 1.0), Vector3(0, -0.05, 0), settings["rocket"]["scaffold_color"])
	workers.append(worker)


# Walk to the next point, then work there for a while, then walk on.
func move_worker(worker: Dictionary, delta: float) -> void:
	var holder: Node3D = worker["holder"]
	var person: Node3D = worker["person"]
	var arm: Node3D = person.get("arm_r_node")
	var target: Vector3 = worker["path"][worker["target"]]
	var to_target: Vector3 = target - holder.position

	if worker["work_left"] > 0.0:
		# Working: swing the right arm like a hammer or a wrench.
		worker["work_left"] -= delta
		if arm != null:
			arm.rotation.x = 0.9 + sin(time * 9.0 + worker["phase"]) * 0.6
		if worker["work_left"] <= 0.0 and arm != null:
			arm.rotation.x = 0.0
		return

	if to_target.length() < 0.05:
		holder.position = target
		worker["target"] = (worker["target"] + 1) % worker["path"].size()
		worker["work_left"] = worker["work_seconds"]
		Sfx.play(worker["work_sound"])   # for example a drill (unknown or empty = no sound)
		person.rotation.z = 0.0
		person.rotation.y = deg_to_rad(worker["work_face_degrees"])
		return

	var step: Vector3 = to_target.normalized() * worker["speed"] * delta
	if step.length() > to_target.length():
		step = to_target
	holder.position += step
	var flat := Vector3(to_target.x, 0, to_target.z)
	if flat.length() > 0.01:
		# The person faces -Z, so turn them toward where they walk.
		person.rotation.y = atan2(-flat.x, -flat.z)
		person.rotation.z = sin(time * 10.0 + worker["phase"]) * 0.06   # a little waddle
	else:
		person.rotation.z = 0.0


# ---------- small helpers ----------

func add_box(parent: Node3D, box_size: Vector3, pos: Vector3, color: String) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = box_size
	return add_mesh(parent, mesh, pos, color)


func add_cylinder(parent: Node3D, top: float, bottom: float, height: float, pos: Vector3, color: String) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = top
	mesh.bottom_radius = bottom
	mesh.height = height
	mesh.radial_segments = 24
	return add_mesh(parent, mesh, pos, color)


func add_mesh(parent: Node3D, mesh: Mesh, pos: Vector3, color: String) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.mesh = mesh
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(color)
	node.material_override = material
	parent.add_child(node)
	node.position = pos
	return node


func array_to_vector(a: Array) -> Vector3:
	return Vector3(a[0], a[1], a[2])
