extends Node3D

@export var noise : Noise
@export var chunk_scene: PackedScene

const chunk_size : int = 1024
const chunk_amount : int = 4
const chunk_radius : int = int(chunk_amount * 0.5);
const chunk_subdivide : int = 64
const chunk_height : float = 64

var created_chunks = {}
#var building_chunks = {}
#var thread : Thread

func _ready():
	randomize()
	noise.seed = randi()
	
	#thread = Thread.new()

func _process(_delta: float):
	update_chunks()
	clean_up_chunks()
	reset_chunks()
	$Camera3D.position.y = 25.0
	$Camera3D.position.z -= 50.0 * _delta
	#$Camera3D.rotation_degrees.y += _delta
	
func update_chunks():
	var pt = $Camera3D.position
	var px :int = int(pt.x / chunk_size)
	var pz :int = int(pt.z / chunk_size)
	for x in range(px - chunk_radius, px + chunk_radius):
		for z in range(pz - chunk_amount, pz):
			add_chunk(x, z)

func clean_up_chunks():
	pass

func reset_chunks():
	pass
	
func add_chunk(x : int, z : int):
	var key = str(x) + "," + str(z)
	if created_chunks.has(key): # || building_chunks.has(key):
		return
	
	load_chunk(key, x, z)
	#if not thread.is_alive():
	#	var callable = Callable(self, "load_chunk").bind(thread, x, z)
	#	thread.start(callable)
	#	building_chunks[key] = 1

func load_chunk(key: String, x : int, z : int):
	var chunk : Node3D = chunk_scene.instantiate()
	chunk.c_init(noise, x * chunk_size, z * chunk_size, chunk_size, chunk_subdivide, chunk_height)
	chunk.position = Vector3(x * chunk_size, 0, z * chunk_size)
	add_child(chunk)
	created_chunks[key] = chunk

func get_chunk(x : int, z : int):
	var key = str(x) + "," + str(z)
	if created_chunks.has(key):
		return created_chunks.get(key)
	
	return null
