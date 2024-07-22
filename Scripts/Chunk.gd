extends Node3D

var mesh_instance : MeshInstance3D
var chunk_size : float
var subdivide : int
var noise : Noise
var x : float
var z : float
var height : float
var material : Material

func c_init(inoise : Noise, key : Vector2i, ichunk_size : float, isubdivide : int, iheight : float, imaterial : Material):
	noise = inoise
	x = key.x * ichunk_size
	z = key.y * ichunk_size
	chunk_size = ichunk_size
	subdivide = isubdivide
	height = iheight
	material = imaterial
	name = str("ground_mesh_(", key.x, ",", key.y, ")")

# Called when the node enters the scene tree for the first time.
func _ready():
	generate_chunk()

func get_height_rr(_ix : float, _iz : float):
	return 0
	
func get_height_valley(ix : float, iz : float):
	return noise.get_noise_2d(ix, iz) / 2.0
		
func get_height_hill(ix : float, iz : float):
	const hill_scale : float = 32.0
	return (noise.get_noise_2d(ix / hill_scale, iz / hill_scale) + 0.25) * 64.0

func get_height(ix : float, iz : float):
	var x_offset :float = abs(ix)
	const valley_width : float = 512.0
	if x_offset < valley_width:
		var weight : float = x_offset / valley_width
		weight = sqrt(weight)
		return lerpf(get_height_rr(ix, iz), get_height_valley(ix, iz), weight)
	else:
		const hill_width = 3036.0
		var x_offset_valley = x_offset - valley_width
		if x_offset_valley < hill_width:
			var weight : float = x_offset_valley / hill_width
			weight = weight * weight
			return lerpf(get_height_valley(ix, iz), get_height_hill(ix, iz), weight)
		else:
			return get_height_hill(ix, iz)

func get_height_old(ix : float, iz : float):
	var x_offset = abs(ix)
	
	const rr_width : float = 32
	const rr_height : float = 0.0
	
	var rr_weight : float = 1.0 - ((x_offset / rr_width) * (x_offset / rr_width))
	if rr_weight < 0:
		rr_weight = 0

	const valley_width : float = 512
	var valley_weight : float = 1
	if x_offset < valley_width:
		valley_weight = x_offset / valley_width
		valley_weight = sqrt(valley_weight)
	var valley_height : float = 0
	if valley_weight > 0:
		valley_height = noise.get_noise_2d(ix, iz) / 2.0
	else:
		valley_weight = 0
	
	var hill_width : float = 2048
	var hill_offset = x_offset - valley_width
	if hill_offset < 0:
		hill_offset = 0
	var hill_weight : float = (hill_offset / hill_width)
	var hill_height : float = 0
	if hill_weight > 0:
		const hill_scale : float = 32.0
		hill_height = (noise.get_noise_2d(ix / hill_scale, iz / hill_scale) + 0.25) * 64.0
		if hill_weight > 1:
			hill_weight = 1
	else:
		hill_weight = 0
	
	return rr_weight * rr_height + valley_weight * valley_height + hill_weight * hill_height / (rr_weight + valley_weight + hill_weight)
	#var offset : float = abs(ix) - rrwidth
	#if offset < 0:
	#	return rry
	#var y = noise.get_noise_2d(ix, iz)
	#if offset < rrwidth:
	#	offset /= rrwidth
	#	offset = 1 - offset
	#	offset = offset * offset
	#	return rry * offset + y * (1 - offset)
	#if offset > 256:
	#	y = y * pow(2, ((offset - 256.0) / 256.0))
	#return y

func generate_chunk():
	var plane_mesh = PlaneMesh.new()
	plane_mesh.size = Vector2(chunk_size, chunk_size)
	plane_mesh.subdivide_depth = subdivide
	plane_mesh.subdivide_width = subdivide
	
	var surface_tool = SurfaceTool.new()
	surface_tool.create_from(plane_mesh, 0);
	var array_plane = surface_tool.commit();
	
	var data_tool = MeshDataTool.new()
	var error = data_tool.create_from_surface(array_plane, 0)
	if error != 0:
		print("Error: ", error)
	
	var lowz = float(int(z) - int(chunk_size / 2.0))
	
	for i in range(data_tool.get_vertex_count()):
		var vertex = data_tool.get_vertex(i)
		var dx = vertex.x + x
		var dz = vertex.z + z
		
		var ab = abs(dz - lowz)
		if ab < 0.1 && ab > 0.0:
			dz = lowz
		
		var dy = get_height(dx, dz)
		vertex.y = dy * height
		data_tool.set_vertex(i, vertex)
		
		#data_tool.set_vertex_color(i, Color.RED)
		
		#var dxn = dx - 0.1
		#var dzn = dz - 0.1
		#var dyxnz = get_height(dxn, dz)
		#var dyxzn = get_height(dx, dzn)
		#var a = Vector3(dxn, dyxnz, dz) - Vector3(dx, dz, dy)
		#var b = Vector3(dx, dyxzn, dzn) - Vector3(dx, dz, dy)
		#var crossProduct = a.cross(b)
		#data_tool.set_vertex_normal(i, crossProduct.normalized())
	
	array_plane.clear_surfaces()
	#for s in range(array_plane.get_surface_count()):
	#	array_plane.surface_remove(s)
	
	data_tool.commit_to_surface(array_plane)
	surface_tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	surface_tool.create_from(array_plane, 0)
	surface_tool.generate_normals()
	
	mesh_instance = MeshInstance3D.new()
	mesh_instance.mesh = surface_tool.commit();
	mesh_instance.set_surface_override_material(0, material)
	mesh_instance.create_trimesh_collision()
	var staticBody3d : StaticBody3D = StaticBody3D.new()
	var cs : CollisionShape3D = CollisionShape3D.new()
	cs.shape = mesh_instance.mesh.create_trimesh_shape()
	staticBody3d.add_child(cs)
	mesh_instance.add_child(staticBody3d)
	#add_child(staticBody3d)
	mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	add_child(mesh_instance)
	
