extends Node2D

@onready var health_icon = preload("res://scenes/health_icon.tscn")
@onready var health_container = $UI/HealthContainer
@onready var player_health = $Mum.health

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	for point in player_health:
		var health_icon_node = health_icon.instantiate()
		health_container.add_child(health_icon_node)


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass


func _on_mum_player_take_damage(damage) -> void:
	if damage >= player_health:
		for child in health_container:
			child.queue_free()
	else:
		var health_icons = health_container.get_children()
		for i in range(0, damage):
			health_icons.back().queue_free()

func _on_reset_timer_timeout() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()


func _on_mum_player_defeated() -> void:
	$ResetTimer.start()
	get_tree().paused = true
