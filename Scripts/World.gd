extends Node3D

@export var noise : Noise
@export var chunk_scene : PackedScene
@export var train_car_scene : PackedScene
@export var chunk_material : Material
@export var train_speed_miles_per_hour : float = 50
@export var box_car_spacing_feet : float = 60
@export var box_car_count : int = 4

const units_per_meter : float = 10
const meters_per_mile : float = 1609.34
const meters_per_foot : float = 0.3048

const chunk_size : int = 1024
const chunk_amount : int = 2
const chunk_radius : int = int(chunk_amount * 0.5);
const chunk_subdivide : int = 64
const chunk_height : float = 64

var train_cars = []
var existing_chunks = {}
#var building_chunks = {}
#var thread : Thread

func _ready():
	randomize()
	noise.seed = randi()
	$Camera3D.position.y = 45.0
	
	for i in range(0, box_car_count):
		var train_car = train_car_scene.instantiate()
		train_car.find_child("CSGBox3D").scale *= units_per_meter
		train_car.find_child("Model").scale *= units_per_meter
		train_cars.append(train_car)
		add_child(train_car)
		var box_car_spacing_meters : float = box_car_spacing_feet * meters_per_foot
		train_car.position = Vector3($Camera3D.position.x, 0, $Camera3D.position.z - i * box_car_spacing_meters * units_per_meter)
		
	for z in range(-1, 1):
		add_chunk(-1, z)
		add_chunk(0, z)
		add_chunk(1, z)
	
	#thread = Thread.new()

func _process(_delta: float):
	update_chunks()
	clean_up_chunks()
	reset_chunks()
	
	var meters_per_second = meters_per_mile * train_speed_miles_per_hour / 3600.0
	$Camera3D.position.z -= meters_per_second * _delta * units_per_meter
	#$Camera3D.rotation_degrees.y += _delta
	var box_car_spacing_meters : float = box_car_spacing_feet * meters_per_foot
	for i in range(0, box_car_count):
		train_cars[i].position = Vector3($Camera3D.position.x, 0, $Camera3D.position.z - i * box_car_spacing_meters * units_per_meter)
	
func update_chunks():
	var pt = $Camera3D.position
	var px :int = int(pt.x / chunk_size)
	var pz :int = int(pt.z / chunk_size)
	for x in range(px - chunk_radius, px + chunk_radius):
		for z in range(pz - 4 * chunk_amount, pz):
			add_chunk(x, z)

func clean_up_chunks():
	var pt = $Camera3D.position
	var pz :int = int(pt.z / chunk_size)
	var fadeZ = pz + chunk_amount
	var all_keys = existing_chunks.keys()
	for key in all_keys:
		if key.y >= fadeZ:
			existing_chunks.erase(key)

func reset_chunks():
	pass
	
func add_chunk(x : int, z : int):
	var key = Vector2i(x, z)
	if existing_chunks.has(key): # || building_chunks.has(key):
		return
	
	load_chunk(key)
	#if not thread.is_alive():
	#	var callable = Callable(self, "load_chunk").bind(thread, x, z)
	#	thread.start(callable)
	#	building_chunks[key] = 1

func load_chunk(key: Vector2i):
	var chunk : Node3D = chunk_scene.instantiate()
	chunk.c_init(noise, key, chunk_size, chunk_subdivide, chunk_height, chunk_material)
	chunk.position = Vector3(key.x * chunk_size, 0, key.y * chunk_size)
	add_child(chunk)
	existing_chunks[key] = chunk

func get_chunk(key : Vector2i):
	if existing_chunks.has(key):
		return existing_chunks.get(key)
	
	return null
