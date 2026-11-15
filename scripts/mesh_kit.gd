# mesh_kit.gd
# Small helpers that build simple low-poly 3D shapes in code (no model files).
# Used by the rocket, the spacecraft, the start menu, the rooms and the launch.
#     MeshKit.box(parent, size, position, color)
#     MeshKit.cylinder(parent, top_radius, bottom_radius, height, position, color)
#     MeshKit.lathe(parent, profile, position, color)   a shape spun around Y,
#         like a vase on a potter's wheel (nose cones, engine bells)
class_name MeshKit
extends RefCounted


static func material(color: Color, metallic: float = 0.0, roughness: float = 0.7) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.metallic = metallic
	m.roughness = roughness
	if color.a < 1.0:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return m


static func glow(color: Color, energy: float = 2.0) -> StandardMaterial3D:
	var m := material(color)
	m.emission_enabled = true
	m.emission = color
	m.emission_energy_multiplier = energy
	return m


static func add(parent: Node3D, mesh: Mesh, pos: Vector3, mat: Material) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.material_override = mat
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(node)
	node.position = pos
	return node


static func box(parent: Node3D, size: Vector3, pos: Vector3, color: Color) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	return add(parent, mesh, pos, material(color))


static func cylinder(parent: Node3D, top: float, bottom: float, height: float, pos: Vector3, color: Color, segments: int = 20) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = top
	mesh.bottom_radius = bottom
	mesh.height = height
	mesh.radial_segments = segments
	mesh.rings = 1
	return add(parent, mesh, pos, material(color))


static func sphere(parent: Node3D, radius: float, pos: Vector3, color: Color, segments: int = 16) -> MeshInstance3D:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = segments
	mesh.rings = segments / 2
	return add(parent, mesh, pos, material(color))


# A shape spun around the Y axis. profile = points (radius, height) from the
# bottom up. from_angle / to_angle in radians: 0..TAU is a full shape, 0..PI
# is one half (the two halves of a nose cone that splits open).
static func lathe(parent: Node3D, profile: Array, pos: Vector3, color: Color, from_angle: float = 0.0, to_angle: float = TAU, segments: int = 20) -> MeshInstance3D:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	tool.set_smooth_group(0)
	for s in segments:
		var a0: float = lerpf(from_angle, to_angle, float(s) / segments)
		var a1: float = lerpf(from_angle, to_angle, float(s + 1) / segments)
		for i in profile.size() - 1:
			var p: Vector2 = profile[i]
			var q: Vector2 = profile[i + 1]
			var v00 := Vector3(cos(a0) * p.x, p.y, sin(a0) * p.x)
			var v01 := Vector3(cos(a1) * p.x, p.y, sin(a1) * p.x)
			var v10 := Vector3(cos(a0) * q.x, q.y, sin(a0) * q.x)
			var v11 := Vector3(cos(a1) * q.x, q.y, sin(a1) * q.x)
			tool.add_vertex(v00)
			tool.add_vertex(v10)
			tool.add_vertex(v11)
			tool.add_vertex(v00)
			tool.add_vertex(v11)
			tool.add_vertex(v01)
	tool.generate_normals()
	var mat := material(color)
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED   # half shells must show both sides
	return add(parent, tool.commit(), pos, mat)


# A text sign that always faces the camera.
static func label(parent: Node3D, text: String, pos: Vector3, pixel_size: float = 0.01, color: Color = Color.WHITE) -> Label3D:
	var l := Label3D.new()
	l.text = text
	l.position = pos
	l.pixel_size = pixel_size
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.modulate = color
	l.outline_size = 12
	l.font_size = 48
	l.no_depth_test = false
	parent.add_child(l)
	return l


# A made-in-code planet surface: light and dark patches (Moon seas, Mars dust),
# or long cloud bands (bands = true, for Venus). Small (128 x 64) for the browser.
# Sampled on a ball, so there is no seam where the picture wraps around.
static func planet_texture(base: Color, bands: bool) -> ImageTexture:
	var noise := FastNoiseLite.new()
	noise.seed = 7
	noise.frequency = 0.05
	noise.fractal_octaves = 4
	var image := Image.create(128, 64, false, Image.FORMAT_RGB8)
	for y in 64:
		for x in 128:
			var lon: float = x / 128.0 * TAU
			var lat: float = (y / 63.0 - 0.5) * PI
			var p := Vector3(cos(lat) * cos(lon), sin(lat), cos(lat) * sin(lon)) * 30.0
			var n: float = noise.get_noise_3d(p.x * (0.3 if bands else 1.0), p.y * (4.0 if bands else 1.0), p.z * (0.3 if bands else 1.0))
			var shade: float = clampf(0.5 + n * 0.8, 0.0, 1.0)
			image.set_pixel(x, y, base.darkened(0.45).lerp(base.lightened(0.15), shade))
	return ImageTexture.create_from_image(image)


static func vec3(a: Array) -> Vector3:
	return Vector3(a[0], a[1], a[2])
