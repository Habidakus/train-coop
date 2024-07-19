extends Node3D

signal hit

# Called when the node enters the scene tree for the first time.
func _ready():
	hit.connect(on_hit)
	name = "tank"

func on_hit() -> void:
	print(name, " hit by bullet")
	self.position.y -= 60

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta):
	pass
