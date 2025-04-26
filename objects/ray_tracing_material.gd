@tool
class_name RayTracingMaterial extends Resource

signal updated

@export var color : Color:
	set(c):
		color = c
		updated.emit()
@export var emission_color : Color = Color.WHITE:
	set(c):
		emission_color = c
		updated.emit()
@export var emission_strength : float


func parse_data() -> PackedFloat32Array:
	var data = PackedFloat32Array()
	for c in range(4): data.append(color[c])
	for c in range(3): data.append(emission_color[c])
	data.append(emission_strength)
	return data
