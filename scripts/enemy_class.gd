extends CharacterBody2D

class_name Enemy

# DEFAULT VALUES
@export var health: int = 10
@export var speed: int = 100
@export var damage: int = 2
var dead: bool = false
var edible: bool = false
var taking_damage: bool = false
var is_attacking: bool = false
var is_chasing_player: bool = false

var direction: Vector2
var knockback_force: int = -200
var is_moving: bool = true

var player: CharacterBody2D
var player_in_area: bool = false

func take_damage():
	taking_damage = true
	health -= 1
	print(self, "only has ", health)
	if health <= 0:
		dead = true

func handle_death():
	self.queue_free()
