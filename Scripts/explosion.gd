extends Node3D

var kill_self : float = 3.0

func _ready():
	print("Explosion created at ", global_position)
	$Debris.emitting = true
	$Fire.emitting = true
	$Smoke.emitting = true
	$Sparks.emitting = true
	pass # Replace with function body.

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	if kill_self >= 0:
		kill_self -= delta
		if kill_self < 0:
			print("Explosion freed at ", global_position)
			queue_free() 

func _on_smoke_finished():
	print("smoke finished at ", global_position)
