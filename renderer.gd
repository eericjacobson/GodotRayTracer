extends Node

static var render_scene : RenderScene

var num_rendered_frames : int = 0
var frame : int:
	set(f):
		if f > 10000: frame = 0
		else: frame = f

func _ready() -> void:
	var save = load(RayTracer.RENDER_SAVE_PATH)
	load_save(save)

func _process(_delta: float) -> void:
	update_frames()

func set_display(save : RenderSave):
	var camera = Camera3D.new()
	camera.global_transform = save.camera_transform
	render_scene = load(RayTracer.RENDER_SCENE_UID).instantiate()
	render_scene.accumulator_viewport.size = DisplayServer.window_get_size()
	render_scene.ray_tracer_viewport.size = DisplayServer.window_get_size()
	add_child(camera)
	camera.get_viewport().call_deferred("add_child", render_scene)

func load_save(save : RenderSave):
	set_display(save)
	render_scene.ray_tracer_canvas.material.set_shader_parameter("viewParams", save.view_params)
	render_scene.ray_tracer_canvas.material.set_shader_parameter("localToWorldMatrix", save.camera_transform)
	render_scene.ray_tracer_canvas.material.set_shader_parameter("MaxBounceCount", save.config[0])
	render_scene.ray_tracer_canvas.material.set_shader_parameter("NumRaysPerPixel", save.config[1])
	render_scene.ray_tracer_canvas.material.set_shader_parameter("Spheres", save.spheres)
	render_scene.ray_tracer_canvas.material.set_shader_parameter("NumSpheres", save.spheres.get_height())
	render_scene.ray_tracer_canvas.material.set_shader_parameter("Triangles", save.triangles)
	render_scene.ray_tracer_canvas.material.set_shader_parameter("AllMeshInfo", save.all_mesh_info)
	render_scene.ray_tracer_canvas.material.set_shader_parameter("NumMeshes", save.all_mesh_info.get_height())
	

func update_frames():
	num_rendered_frames += 1
	frame += 1
	render_scene.ray_tracer_canvas.material.set_shader_parameter("Frame", frame)
	render_scene.accumulator_canvas.material.set_shader_parameter("NumRenderedFrames", num_rendered_frames)
