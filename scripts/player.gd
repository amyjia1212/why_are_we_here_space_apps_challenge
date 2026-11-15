# player.gd
# Third-person walking (since 2026-11-12, TASKS.md step 8): WASD to move,
# mouse to look around. The camera floats behind and above the body.
# The player is a CharacterBody3D, a body that walks and bumps into things.
# Its "Head" holds a SpringArm with the camera on the end: the body turns
# left and right, the Head tilts the camera up and down, and the SpringArm
# pulls the camera closer if a rock is in the way.
extends CharacterBody3D

# @export makes these show up in the Inspector, so you can tune them
# without opening the script. (They are controls, not mission numbers.)
@export var walk_speed: float = 4.0
@export var mouse_sensitivity: float = 0.003
@export var jump_speed: float = 4.5   # upward speed when you jump (about 1 m high)
@export var look_up_degrees: float = 30.0     # how far the camera can tilt up
@export var look_down_degrees: float = 60.0   # how far the camera can tilt down
var gravity_scale: float = 1.0   # set by the arrival screen (the Moon has weak gravity)
var frozen: bool = false         # true = the player can look but not walk (cutscene moments)

@onready var head: Node3D = $Head
@onready var spring_arm: SpringArm3D = %SpringArm

# How strong gravity is, from Project Settings.
var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")


func _ready() -> void:
	# A "group" is a name tag. The parts' reach zones check for this tag,
	# so they know it's the player walking in (not a wall or a part).
	add_to_group("player")
	# The keys (move_forward, jump, run...) are set up by the Controls autoload
	# from data/game_data.json "keybinds" (UPGRADE_PLAN_V2 step 8).
	spring_arm.add_excluded_object(get_rid())   # the camera must not bump into our own body
	# Hide the mouse and lock it to the window, so moving it turns the view.
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


# First person (UPGRADE_PLAN_V2 DEFAULT for the Choice Rooms and the ship):
# the camera sits in the head and your own body is hidden. Off = third
# person, the camera behind the character (the planet, step 24).
var first_person: bool = false

func set_first_person(on: bool) -> void:
	first_person = on
	spring_arm.spring_length = 0.0 if on else 4.5
	spring_arm.position = Vector3(0, 0.05, 0) if on else Vector3.ZERO
	var avatar: Node3D = get_node_or_null("Avatar")
	if avatar != null:
		avatar.visible = not on
	$Body.visible = not on and avatar == null
	$Visor.visible = not on and avatar == null


# From the "You're hired" moment on, the player IS that character
# (UPGRADE_PLAN_V2 step 14): the plain capsule hides and the character's toy
# model walks instead. "" = back to the plain capsule.
func set_avatar(character_id: String) -> void:
	var old: Node = get_node_or_null("Avatar")
	if old != null:
		old.queue_free()
	var has_avatar: bool = character_id != "" and Data.characters.has(character_id)
	if old != null:
		remove_child(old)   # gone now, so set_first_person doesn't find it
	if has_avatar:
		var avatar: Node3D = load(Data.characters[character_id]["scene"]).instantiate()
		avatar.name = "Avatar"
		add_child(avatar)
	set_first_person(first_person)   # hides or shows the body for the camera mode


# Runs for every mouse move, click and key press.
func _unhandled_input(event: InputEvent) -> void:
	# Mouse moved while captured: turn the body (left/right) and head (up/down).
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		rotate_y(-event.relative.x * mouse_sensitivity)
		head.rotate_x(-event.relative.y * mouse_sensitivity)
		# Stop the camera from flipping over or going under the ground.
		head.rotation.x = clamp(head.rotation.x, deg_to_rad(-look_down_degrees), deg_to_rad(look_up_degrees))

	# Esc frees the mouse. Clicking in the window grabs it again.
	if event.is_action_pressed("ui_cancel"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if event is InputEventMouseButton and event.pressed:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


# Runs 60 times a second, for movement and physics.
func _physics_process(delta: float) -> void:
	# Fall if we're not standing on something.
	if not is_on_floor():
		velocity.y -= gravity * gravity_scale * delta

	# Frozen (for example during the "You're hired" moment): no walking.
	if frozen:
		velocity.x = 0.0
		velocity.z = 0.0
		move_and_slide()
		return

	# Jump: only when standing on something (no jumping in mid-air).
	if is_on_floor() and Input.is_action_just_pressed("jump"):
		velocity.y = jump_speed
		AudioManager.play_sfx("jump")

	# Which way do the keys point? (x = left/right, y = forward/back)
	var input := Input.get_vector("move_left", "move_right", "move_forward", "move_back")

	# Turn that into a direction in the world, based on where we're facing.
	var direction := (transform.basis * Vector3(input.x, 0, input.y)).normalized()

	# Shift runs (game_data.json "keybinds" > run_multiplier).
	var speed: float = walk_speed
	if Input.is_action_pressed("run"):
		speed *= float(Data.game_data["keybinds"]["run_multiplier"])
	velocity.x = direction.x * speed
	velocity.z = direction.z * speed

	# Move, and slide along walls instead of getting stuck.
	move_and_slide()
	sway_suit(input != Vector2.ZERO)
	footsteps(input != Vector2.ZERO and is_on_floor(), speed)


# A soft step sound while walking (faster when running).
var step_clock: float = 0.0

func footsteps(walking: bool, speed: float) -> void:
	if not walking:
		step_clock = 0.0
		return
	step_clock -= get_physics_process_delta_time() * speed / walk_speed
	if step_clock <= 0.0:
		step_clock = 0.42
		AudioManager.play_sfx("footstep")


# The suited character (added by the arrival screen) rocks a little while walking.
var sway_time: float = 0.0

func sway_suit(walking: bool) -> void:
	var suit: Node3D = get_node_or_null("Suit")
	if suit == null:
		return
	if walking:
		sway_time += get_physics_process_delta_time()
		suit.rotation.z = sin(sway_time * 9.0) * float(Data.game_data["suit"]["walk_sway"])
	else:
		suit.rotation.z = lerpf(suit.rotation.z, 0.0, 0.2)
