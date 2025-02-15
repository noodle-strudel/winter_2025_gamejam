extends CharacterBody2D

class_name Enemy

# DEFAULT VALUES
@export var health: int = 10
@export var speed: int = 100
@export var damage: int = 2
var dead: bool = false
var taking_damage: bool = false
var is_attacking: bool = false
var is_chasing_player: bool = false

var direction: Vector2
var knockback_force: int = 100
var is_moving: bool = true

var player: CharacterBody2D
var player_in_area: bool = false
