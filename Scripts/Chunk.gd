extends Node3D

var mesh_instance : MeshInstance3D
var chunk_size : float
var subdivide : int
var noise : Noise
var x : float
var z : float
var height : float

func c_init(inoise : Noise, ix : float, iz : float, ichunk_size : float, isubdivide : int, iheight : float):
	noise = inoise
	x = ix
	z = iz
	chunk_size = ichunk_size
	subdivide = isubdivide
	height = iheight

# Called when the node enters the scene tree for the first time.
func _ready():
	generate_chunk()

func get_height(ix : float, iz : float):
	const rrwidth :float = 16
	const rry : float = 0.0
	var offset : float = abs(ix) - rrwidth
	if offset < 0:
		return rry
	var y = noise.get_noise_2d(ix, iz)
	if offset < rrwidth:
		offset /= rrwidth
		offset = offset * offset
		return y * offset + rry * (1 - offset)
	return y

func generate_chunk():
	var plane_mesh = PlaneMesh.new()
	plane_mesh.size = Vector2(chunk_size, chunk_size)
	plane_mesh.subdivide_depth = subdivide
	plane_mesh.subdivide_width = subdivide
	
	#print("Generate Chunk ", x, " , ", z)
	#TODO: Need material
	
	var surface_tool = SurfaceTool.new()
	surface_tool.create_from(plane_mesh, 0);
	var array_plane = surface_tool.commit();
	
	var data_tool = MeshDataTool.new()
	var error = data_tool.create_from_surface(array_plane, 0)
	if error != 0:
		print("Error: ", error)
	
	for i in range(data_tool.get_vertex_count()):
		var vertex = data_tool.get_vertex(i)
		var dx = vertex.x + x
		var dz = vertex.z + z
		var dy = get_height(dx, dz)
		vertex.y = dy * height
		data_tool.set_vertex(i, vertex)
		var dxn = dx - 0.1
		var dzn = dz - 0.1
		var dyxnz = get_height(dxn, dz)
		var dyxzn = get_height(dx, dzn)
		var a = Vector3(dxn, dyxnz, dz) - Vector3(dx, dz, dy)
		var b = Vector3(dx, dyxzn, dzn) - Vector3(dx, dz, dy)
		var crossProduct = a.cross(b)
		data_tool.set_vertex_normal(i, crossProduct.normalized())
	
	array_plane.clear_surfaces()
	#for s in range(array_plane.get_surface_count()):
	#	array_plane.surface_remove(s)
	
	data_tool.commit_to_surface(array_plane)
	surface_tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	surface_tool.create_from(array_plane, 0)
	surface_tool.generate_normals()
	
	mesh_instance = MeshInstance3D.new()
	mesh_instance.mesh = surface_tool.commit();
	mesh_instance.set_surface_override_material(0, Material.new())
	mesh_instance.create_trimesh_collision()
	mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	add_child(mesh_instance)
	
