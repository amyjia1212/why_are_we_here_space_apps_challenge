# planet_look.gd
# The planets outside the ship's windows (UPGRADE_PLAN_V3 D1).
#   PLANET_LOOK.apply(sphere, "earth")
# - If a real NASA map is in the project (game_data.json ship > planet_look >
#   maps, for example res://assets/planets/earth.jpg), it is wrapped around the
#   sphere. These are an agreed exception to the low-poly art rule, for the
#   window only. Earth, Mars, the Moon and Venus have real maps (downloaded
#   2026-11-14; the source pages are in planet_look > sources and REFERENCES.md).
#   Venus's map is Magellan's radar view of the ground, so a see-through cloud
#   layer goes over it.
# - Without a map, a better made-in-code surface is used: Earth gets oceans,
#   land, ice caps and a soft cloud layer; Mars gets dark regions and a white
#   polar cap; the Moon gets grey seas; Venus gets yellow cloud bands.
# - Every planet gets a thin glowing edge (blue for Earth, pale orange for
#   Mars) and spins slowly. The ship's Sun light gives a day and a night side.
extends RefCounted

const RIM_SHADER := "shader_type spatial;
render_mode unshaded, blend_add, cull_back, depth_draw_never;
uniform vec4 rim_color : source_color = vec4(0.4, 0.7, 1.0, 1.0);
uniform float power = 3.0;
void fragment() {
	float rim = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), power);
	ALBEDO = rim_color.rgb * rim;
	ALPHA = rim;
}"


static func apply(node: MeshInstance3D, key: String) -> void:
	var look: Dictionary = Data.game_data["ship"]["planet_look"]
	var mat: StandardMaterial3D = node.material_override
	mat.albedo_color = Color.WHITE
	mat.albedo_texture = load_map(look["maps"].get(key, ""))
	var real_map: bool = mat.albedo_texture != null
	if not real_map:
		mat.albedo_texture = made_texture(key)
	mat.roughness = 1.0
	node.set_meta("spin_speed", deg_to_rad(float(look["spin_degrees_per_second"])))
	# The thin glowing edge: a slightly bigger sphere with a rim shader.
	var radius: float = (node.mesh as SphereMesh).radius
	var shell := SphereMesh.new()
	shell.radius = radius * float(look["rim_size"])
	shell.height = shell.radius * 2.0
	shell.radial_segments = 48
	shell.rings = 24
	var shader := Shader.new()
	shader.code = RIM_SHADER
	var rim := ShaderMaterial.new()
	rim.shader = shader
	rim.set_shader_parameter("rim_color", Color(look["rim_colors"].get(key, "#9fb4d0")))
	var glow := MeshInstance3D.new()
	glow.mesh = shell
	glow.material_override = rim
	glow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.add_child(glow)
	# Earth: a soft cloud layer just above the ground (made in code). Only on
	# the made-in-code Earth: the real NASA map has no cloud layer, and the
	# plan adds clouds only "if the map has one".
	# Venus: the real map is Magellan's RADAR view of the ground, which is hidden
	# under thick clouds; a see-through layer of yellow cloud bands goes over it
	# (planet_look > venus_cloud_veil = how thick it looks).
	var venus_veil: bool = key == "venus" and real_map
	if (key == "earth" and not real_map) or venus_veil:
		var clouds := SphereMesh.new()
		clouds.radius = radius * 1.012
		clouds.height = clouds.radius * 2.0
		clouds.radial_segments = 48
		clouds.rings = 24
		var cloud_mat := StandardMaterial3D.new()
		cloud_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		cloud_mat.albedo_texture = veil_texture(float(look.get("venus_cloud_veil", 0.5))) if venus_veil else cloud_texture()
		var layer := MeshInstance3D.new()
		layer.mesh = clouds
		layer.material_override = cloud_mat
		layer.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		layer.set_meta("spin_speed", deg_to_rad(float(look["spin_degrees_per_second"])) * 0.3)
		node.add_child(layer)


# Turn every planet a little each frame (call from _process).
static func spin_all(nodes: Array, delta: float) -> void:
	for node in nodes:
		if node is Node3D and is_instance_valid(node) and node.has_meta("spin_speed"):
			node.rotation.y += float(node.get_meta("spin_speed")) * delta
			for child in node.get_children():
				if child.has_meta("spin_speed"):
					child.rotation.y += float(child.get_meta("spin_speed")) * delta


static func load_map(path: String) -> Texture2D:
	if path == "" or not ResourceLoader.exists(path):
		return null
	return load(path)


# The made-in-code surfaces (256 x 128, longitude across, latitude down).
static func made_texture(key: String) -> ImageTexture:
	var noise := FastNoiseLite.new()
	noise.seed = {"earth": 3, "mars": 9, "moon": 5, "venus": 7}.get(key, 1)
	noise.frequency = 0.04
	noise.fractal_octaves = 5
	var w: int = 256
	var h: int = 128
	var image := Image.create(w, h, false, Image.FORMAT_RGB8)
	for y in h:
		var lat: float = (y / float(h - 1) - 0.5) * PI
		for x in w:
			var lon: float = x / float(w) * TAU
			var p := Vector3(cos(lat) * cos(lon), sin(lat), cos(lat) * sin(lon)) * 40.0
			var n: float = noise.get_noise_3d(p.x, p.y, p.z)
			var polar: bool = absf(lat) > deg_to_rad(72.0) + n * 0.15
			var color: Color
			match key:
				"earth":
					if polar:
						color = Color(0.93, 0.95, 0.98)
					elif n > 0.06:
						color = Color(0.25, 0.45, 0.2).lerp(Color(0.6, 0.5, 0.32), clampf((n - 0.06) * 4.0, 0.0, 1.0))
					else:
						color = Color(0.05, 0.18, 0.45).lerp(Color(0.1, 0.32, 0.6), clampf(n + 0.6, 0.0, 1.0))
				"mars":
					if absf(lat) > deg_to_rad(78.0) + n * 0.1 and lat < 0.0:
						color = Color(0.95, 0.93, 0.9)   # the north polar cap (top)
					else:
						color = Color(0.72, 0.35, 0.18).lerp(Color(0.45, 0.22, 0.14), clampf(n * 2.0 + 0.4, 0.0, 1.0))
				"moon":
					color = Color(0.62, 0.62, 0.63).lerp(Color(0.35, 0.36, 0.38), clampf(n * 2.5 + 0.3, 0.0, 1.0))
				"venus":
					var band: float = noise.get_noise_3d(p.x * 0.3, p.y * 4.0, p.z * 0.3)
					color = Color(0.85, 0.72, 0.42).lerp(Color(0.95, 0.88, 0.62), clampf(band + 0.5, 0.0, 1.0))
				_:
					color = Color(0.6, 0.6, 0.6).lerp(Color(0.8, 0.8, 0.8), clampf(n + 0.5, 0.0, 1.0))
			image.set_pixel(x, y, color)
	return ImageTexture.create_from_image(image)


# Venus's cloud bands, see-through (alpha = how much of the clouds covers the radar map).
static func veil_texture(alpha: float) -> ImageTexture:
	var bands: Image = made_texture("venus").get_image()
	bands.convert(Image.FORMAT_RGBA8)
	for y in bands.get_height():
		for x in bands.get_width():
			var c: Color = bands.get_pixel(x, y)
			c.a = alpha
			bands.set_pixel(x, y, c)
	return ImageTexture.create_from_image(bands)


static func cloud_texture() -> ImageTexture:
	var noise := FastNoiseLite.new()
	noise.seed = 21
	noise.frequency = 0.06
	noise.fractal_octaves = 4
	var image := Image.create(256, 128, false, Image.FORMAT_RGBA8)
	for y in 128:
		var lat: float = (y / 127.0 - 0.5) * PI
		for x in 256:
			var lon: float = x / 256.0 * TAU
			var p := Vector3(cos(lat) * cos(lon), sin(lat), cos(lat) * sin(lon)) * 40.0
			var n: float = noise.get_noise_3d(p.x, p.y * 1.6, p.z)
			image.set_pixel(x, y, Color(1, 1, 1, clampf((n - 0.05) * 2.2, 0.0, 0.75)))
	return ImageTexture.create_from_image(image)
