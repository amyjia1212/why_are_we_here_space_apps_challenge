# launch_pad.gd
# Builds the launch pad at dawn (used by the start menu and the launch,
# UPGRADE_PLAN_V2 steps 7 and 16): a concrete pad next to a white tower,
# two tall masts with red lights, the sea, a low sun and soft floating dust.
#     var pad := LaunchPad.build(self, Data.game_data["start_menu"])
# Gives back a Dictionary: { "environment", "sky", "sun", "ground" (a Node3D
# holding everything on the ground, so the launch can hide it in space) }.
class_name LaunchPad
extends RefCounted


static func build(parent: Node3D, settings: Dictionary) -> Dictionary:
	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color(settings["sky_top"])
	sky_material.sky_horizon_color = Color(settings["sky_horizon"])
	sky_material.ground_horizon_color = Color(settings["sky_horizon"]).darkened(0.3)
	sky_material.ground_bottom_color = Color(settings["sea_color"]).darkened(0.5)
	sky_material.sun_angle_max = 20.0
	var sky := Sky.new()
	sky.sky_material = sky_material
	var environment := Environment.new()
	environment.background_mode = Environment.BG_SKY
	environment.sky = sky
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	environment.ambient_light_energy = 0.8
	environment.fog_enabled = true
	environment.fog_light_color = Color(settings["sky_horizon"])
	environment.fog_density = 0.004
	environment.fog_sky_affect = 0.1   # keep the sky's blue top: fog only on the ground and sea
	var world := WorldEnvironment.new()
	world.environment = environment
	parent.add_child(world)

	var sun := DirectionalLight3D.new()
	sun.light_color = Color(settings["sun_color"])
	sun.light_energy = 1.3
	sun.rotation_degrees = Vector3(-12, 120, 0)   # low in the sky: dawn
	parent.add_child(sun)

	var ground := Node3D.new()
	ground.name = "Ground"
	parent.add_child(ground)
	MeshKit.box(ground, Vector3(80, 0.2, 60), Vector3(0, -0.1, 0), Color(settings["ground_color"]))
	MeshKit.box(ground, Vector3(1200, 0.1, 800), Vector3(0, -0.3, -430), Color(settings["sea_color"]))
	MeshKit.box(ground, Vector3(9, 1.0, 9), Vector3(0, 0.5, 0), Color(settings["ground_color"]).lightened(0.25))
	# The white tower next to the rocket, with floors and an arm.
	var tower_color := Color(settings["tower_color"])
	for corner in [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1)]:
		MeshKit.box(ground, Vector3(0.3, 28, 0.3), Vector3(5.0 + corner.x, 14, corner.y), tower_color)
	for level in 9:
		MeshKit.box(ground, Vector3(2.3, 0.2, 2.3), Vector3(5.0, 2.5 + level * 3.0, 0), tower_color)
	MeshKit.box(ground, Vector3(3.2, 0.4, 0.6), Vector3(3.0, 18, 0), tower_color)
	# Two tall lightning masts with red lights on top.
	for spot in [Vector3(-9, 0, -6), Vector3(9, 0, 7)]:
		MeshKit.cylinder(ground, 0.18, 0.3, 34, spot + Vector3(0, 17, 0), tower_color, 8)
		MeshKit.add(ground, SphereMesh.new(), spot + Vector3(0, 34.3, 0), MeshKit.glow(Color(1, 0.2, 0.2))).scale = Vector3.ONE * 0.5

	# Soft floating dust in the low sun.
	var dust := CPUParticles3D.new()
	dust.amount = int(settings["dust_amount"])
	dust.lifetime = 12.0
	dust.preprocess = 12.0
	dust.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	dust.emission_box_extents = Vector3(18, 8, 18)
	dust.direction = Vector3(1, 0.2, 0)
	dust.spread = 30.0
	dust.initial_velocity_min = 0.1
	dust.initial_velocity_max = 0.4
	dust.gravity = Vector3.ZERO
	var speck := QuadMesh.new()
	speck.size = Vector2(0.08, 0.08)
	var speck_material := MeshKit.glow(Color(1, 0.85, 0.6), 1.0)
	speck_material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	speck.material = speck_material
	dust.mesh = speck
	dust.position.y = 8
	ground.add_child(dust)
	return {"environment": environment, "sky": sky_material, "sun": sun, "ground": ground}
