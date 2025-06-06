extends CanvasLayer

@onready var anim = $Control/AnimationPlayer
@export var hax = true
var changing_scene = false

func _input(event: InputEvent) -> void:
	if changing_scene or not hax:
		return
	if event.is_action_pressed("1"):
		change_scene("res://scenes/level_1.tscn")
	elif event.is_action_pressed("2"):
		change_scene("res://scenes/level_2.tscn")
	elif event.is_action_pressed("reload"):
		reload()

func change_scene(path : String):
	changing_scene = true
	get_tree().paused = true
	anim.play("fade_in")
	await anim.animation_finished
	get_tree().call_deferred("change_scene_to_file", path)
	# To make it look a little better
	await get_tree().create_timer(0.1).timeout
	anim.play("fade_out")
	await anim.animation_finished
	get_tree().paused = false
	changing_scene = false
	
func reload():
	change_scene(get_tree().current_scene.scene_file_path)
