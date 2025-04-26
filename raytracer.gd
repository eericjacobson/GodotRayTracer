@tool
extends EditorPlugin

static var camera : Camera3D
static var material : ShaderMaterial
static var canvas : ColorRect
static var config : RayTracerConfig

var rendering : bool
var frame : int:
	set(f):
		if f > 10000: frame = 0
		else: frame = f

const CONFIG_SCENE_UID := "uid://dydqe6hhtetow"
const RAY_TRACING_SHADER_UID := "uid://dmvw6y2xttddm"
const RENDER_SAVE_PATH := "res://render/render.tres"
const RENDER_SCENE_UID := "uid://cjynik6v558fe"

func _process(_delta: float) -> void:
	set_camera_params()
	set_buffers()
	save_render()

#region INITIALIZATION

func _enter_tree() -> void:
	config = load(CONFIG_SCENE_UID).instantiate()
	add_control_to_dock(EditorPlugin.DOCK_SLOT_RIGHT_BL, config)
	set_display()
	set_config()

func set_display():
	camera = EditorInterface.get_editor_viewport_3d(0).get_camera_3d()
	material = ShaderMaterial.new()
	material.shader = load(RAY_TRACING_SHADER_UID)
	canvas = ColorRect.new()
	canvas.material = material
	canvas.set_anchors_preset(Control.PRESET_FULL_RECT)
	camera.add_child(canvas)

#endregion
#region CAMERA UPDATES

func set_camera_params():
	material.set_shader_parameter("viewParams", get_view_params())
	material.set_shader_parameter("localToWorldMatrix", camera.global_transform)

func get_view_params():
	var plane_height = camera.near * tan(deg_to_rad(camera.fov * 0.5)) * 2;
	var plane_width = plane_height * camera.get_camera_projection().get_aspect()
	return Vector3(plane_width, plane_height, camera.near) * 10E5

#endregion
#region OBJECT PARSING

func set_buffers():
	frame += 1
	material.set_shader_parameter("Spheres", get_sphere_data())
	material.set_shader_parameter("NumSpheres", get_tree().get_nodes_in_group("RaySphere").size())
	
	
	material.set_shader_parameter("AllMeshInfo", get_all_mesh_data())
	material.set_shader_parameter("Triangles", get_triangle_data())
	
	material.set_shader_parameter("NumMeshes", get_tree().get_nodes_in_group("RayMesh").size())
	material.set_shader_parameter("Frame", frame)

func get_sphere_data() -> ImageTexture:
	var spheres = get_tree().get_nodes_in_group("RaySphere")
	if !spheres.size(): return ImageTexture.new()
	var sphere_half_bytes = 3
	var sampler = ImageTexture.new()
	var image = Image.new()
	var data : PackedByteArray
	for s : RaySphere in spheres:
		data.append_array(s.parse_data().to_byte_array())
	image = Image.create_from_data(sphere_half_bytes, spheres.size(), false, Image.FORMAT_RGBAF, data)
	sampler = ImageTexture.create_from_image(image)
	return sampler

func get_all_mesh_data() -> ImageTexture:
	var meshes = get_tree().get_nodes_in_group("RayMesh")
	if !meshes.size(): return ImageTexture.new()
	var mesh_half_bytes = 4
	var sampler = ImageTexture.new()
	var image = Image.new()
	var data : PackedByteArray
	for s in meshes:
		data.append_array(s.parse_data().to_byte_array())
	image = Image.create_from_data(mesh_half_bytes, meshes.size(), false, Image.FORMAT_RGBAF, data)
	sampler = ImageTexture.create_from_image(image)
	return sampler

func get_triangle_data() -> ImageTexture:
	var meshes = get_tree().get_nodes_in_group("RayMesh")
	if !meshes.size(): return ImageTexture.new()
	var triangle_half_bytes = 6
	var sampler = ImageTexture.new()
	var image = Image.new()
	var data : PackedByteArray
	for s : RayMesh in meshes:
		data.append_array(s.parse_tri_data().to_byte_array())
	image = Image.create_from_data(triangle_half_bytes, RayMesh.triangleIndex, false, Image.FORMAT_RGBAF, data)
	sampler = ImageTexture.create_from_image(image)
	return sampler

#endregion

func set_config(_args=[]):
	material.set_shader_parameter("MaxBounceCount", config._bounces.value)
	material.set_shader_parameter("NumRaysPerPixel", config._rays.value)
	canvas.visible = config._visible.button_pressed
	set_process(config._visible.button_pressed)

func save_render():
	if EditorInterface.is_playing_scene():
		if rendering:
			return
		rendering = true
	else:
		rendering = false
		return
	var save = RenderSave.new()
	save.camera_transform = camera.global_transform
	save.config = [config._bounces.value, config._rays.value] as Array[int]
	save.spheres = get_sphere_data()
	save.all_mesh_info = get_all_mesh_data()
	save.triangles = get_triangle_data()
	save.view_params = get_view_params()
	ResourceSaver.save(save, RENDER_SAVE_PATH)
