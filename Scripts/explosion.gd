extends Node3D

var kill_self : float = 3.0

func _ready():
	$Debris.emitting = true
	$Fire.emitting = true
	$Smoke.emitting = true
	$Sparks.emitting = true

func _process(delta):
	if kill_self >= 0:
		kill_self -= delta
		if kill_self < 0:
			queue_free()
