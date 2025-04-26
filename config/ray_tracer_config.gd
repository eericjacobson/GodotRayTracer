@tool
class_name RayTracerConfig extends Control

@export var _visible : CheckButton
@export var _bounces : SpinBox
@export var _rays : SpinBox

func _enter_tree() -> void:
	await _visible.ready
	await _bounces.ready
	await _rays.ready
	_visible.toggled.connect(RayTracer.set_config)
	_bounces.value_changed.connect(RayTracer.set_config)
	_rays.value_changed.connect(RayTracer.set_config)
