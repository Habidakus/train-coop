extends Node3D

@export var noise : Noise
@export var chunk_scene : PackedScene
@export var train_car_scene : PackedScene
@export var enemy_scene : PackedScene
@export var chunk_material : Material
@export var train_speed_miles_per_hour : float = 50
@export var box_car_spacing_feet : float = 60
@export var box_car_count : int = 4
@export var enemy_count : int = 50

const units_per_meter : float = 10
const meters_per_mile : float = 1609.34
const meters_per_foot : float = 0.3048

const chunk_size : int = 2048
const chunk_amount : int = 4
const chunk_radius : int = int(chunk_amount * 0.5);
const chunk_subdivide : int = 96
const chunk_height : float = 64

var enemies = []
var train_cars = []
var existing_chunks = {}
#var building_chunks = {}
#var thread : Thread

func _ready():
	randomize()
	noise.seed = randi()
	$Camera3D.position.y = 45.0
	$Camera3D.rotation_degrees.y = 60
	
	for i in range(0, enemy_count):
		var enemy = enemy_scene.instantiate()
		enemy.find_child("Model").scale *= units_per_meter
		var x : float = randf() * 4096.0 - 2048.0
		if abs(x) < 48:
			if x < 0:
				x -= (48 + randf() * 128)
			else:
				x += (48 + randf() * 128)
		enemy.position = Vector3(x, 2, $Camera3D.position.z - randf() * chunk_size)
		enemies.append(enemy)
		add_child(enemy)
		enemy.look_at($Camera3D.position)
	
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
	
	if $DirectionalLight3D is DirectionalLight3D:
		($DirectionalLight3D as DirectionalLight3D).rotation.x -= _delta / 300.0
		($DirectionalLight3D as DirectionalLight3D).rotation.y += _delta / 300.0
	
	var meters_per_second = meters_per_mile * train_speed_miles_per_hour / 3600.0
	$Camera3D.rotation.y -= _delta / 10.0
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
	
	for enemy in enemies:
		if enemy.position.z > $Camera3D.position.z + chunk_size:
			enemy.position.z = $Camera3D.position.z - (chunk_size + 2.0 * randf() * chunk_size)
			enemy.position.y = 2 + chunk_height * chunk.get_height(enemy.position.x, enemy.position.z)

func get_chunk(key : Vector2i):
	if existing_chunks.has(key):
		return existing_chunks.get(key)
	
	return null
