@tool
class_name RaySphere extends CSGSphere3D

@export var _position : Vector3:
	set(p):
		_position = p
		if is_inside_tree(): global_position = p
	get:
		if _position != global_position:
			_position = global_position
		return global_position
@export var _radius : float = 0.5:
	set(r):
		_radius = r
		radius = r
@export var _material : RayTracingMaterial = RayTracingMaterial.new():
	set(m):
		_material = m
		_material.updated.connect(func(): material.albedo_color = _material.color)
		_material.updated.emit()


func _enter_tree() -> void:
	add_to_group("RaySphere")
	material = StandardMaterial3D.new()
	_material.updated.connect(func(): material.albedo_color = _material.color)


func parse_data() -> PackedFloat32Array:
	var data = PackedFloat32Array()
	for p in range(3): data.append(_position[p])
	data.append(_radius)
	data.append_array(_material.parse_data())
	return data
