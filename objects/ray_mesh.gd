@tool
class_name RayMesh extends MeshInstance3D

static var triangleIndex := 0
static var mesh_tri_dict := {}

@export var _material : RayTracingMaterial = RayTracingMaterial.new()

var num_triangles

func _enter_tree() -> void:
	add_to_group("RayMesh")
	mesh_tri_dict.merge({self: triangleIndex})
	num_triangles = mesh.get_faces().size()/3
	triangleIndex += num_triangles
	_material = _material.duplicate()

func _exit_tree() -> void:
	mesh_tri_dict.erase(self)
	triangleIndex -= num_triangles


func parse_data() -> PackedFloat32Array:
	var data = PackedFloat32Array()
	var mesh_array := mesh.surface_get_arrays(0)
	for p in range(3): data.append((global_transform * mesh.get_aabb().position)[p])
	data.append(mesh_tri_dict[self])
	for p in range(3): data.append((global_transform * mesh.get_aabb().end)[p])
	data.append(num_triangles)
	data.append_array(_material.parse_data())
	return data

func parse_tri_data() -> PackedFloat32Array:
	var data = PackedFloat32Array()
	var mesh_array := mesh.surface_get_arrays(0)
	var faces = mesh.get_faces()
	var normals = mesh_array[Mesh.ARRAY_NORMAL]
	var indices = mesh_array[Mesh.ARRAY_INDEX]
	var triangle_normals = []
	for i in range(0, indices.size(), 3):
		triangle_normals.append(normals[indices[i]])
		triangle_normals.append(normals[indices[i+1]])
		triangle_normals.append(normals[indices[i+2]])
	for p in range(num_triangles):
		for u in range(3):
			for v in range(3):
				data.append((global_transform * faces[3*p+u])[v])
			data.append(0)
		for u in range(3):
			for v in range(3):
				data.append(triangle_normals[3*p+u][v])
			data.append(0)
	return data
