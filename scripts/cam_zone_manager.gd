@tool
extends Node2D
class_name CamZoneManager

@export var zones = [Rect2i(0, 0, 640, 320)] # (Array, Rect2)
@export_flags_2d_physics var collision_mask # (int, LAYERS_2D_PHYSICS)

var animate = true
var current_zone_idx = 0



func set_animate(val):
	animate = val

func _draw():
	if not Engine.is_editor_hint():
		return
	
	for zone in zones:
		draw_rect(zone, Color.RED, false, 4)# false) TODOGODOT4 Antialiasing argument is missing

func initizlize_area(region):
	var area = Area2D.new()
	
	var collider = CollisionShape2D.new()
	collider.shape = RectangleShape2D.new()
	collider.shape.size = Vector2(region.size.x, region.size.y)
	area.add_child(collider)
	
	return area

func _ready():
	
	if Engine.is_editor_hint():
		return
	
	for i in range(len(zones)):
		var area = initizlize_area(zones[i])
		area.global_position = zones[i].position + (zones[i].size / 2)
		#area.connect("body_entered",Callable(self,"_on_player_entered_zone").bind(i))
		area.body_entered.connect(_on_player_entered_zone.bind(i))
		area.name = "CamZone_%s" % i
		add_child(area)

func _process(_delta):
	queue_redraw()

func set_cam_bounds_from_rect2(cam, rect):
	cam.limit_left = rect.position.x
	cam.limit_top = rect.position.y
	cam.limit_right = rect.end.x
	cam.limit_bottom = rect.end.y

func ensure_is_inside_rect2(pos, extra_size, rect):
	if pos.x + extra_size.x / 2 > rect.position.x + rect.size.x:
		pos.x = (rect.position.x + rect.size.x) - (extra_size.x / 2)
	if pos.y + extra_size.y / 2 > rect.position.y + rect.size.y:
		pos.y = (rect.position.y + rect.size.y) - (extra_size.y / 2)
	if pos.x - extra_size.x / 2 < rect.position.x:
		pos.x = rect.position.x + (extra_size.x / 2)
	if pos.y - extra_size.y / 2 < rect.position.y:
		pos.y = rect.position.y + (extra_size.y / 2)
	
	return pos

func interpolate_cam_bounds(cam, tween : Tween, _old_cam_bounds, new_cam_bounds, time):
	
# warning-ignore:return_value_discarded
	tween.parallel().tween_property(cam, "limit_left", int(new_cam_bounds.position.x), time).from(
		_old_cam_bounds.position.x
	)
	
# warning-ignore:return_value_discarded
	tween.parallel().tween_property(cam, "limit_top", int(new_cam_bounds.position.y), time).from(
		_old_cam_bounds.position.y
	)
	
# warning-ignore:return_value_discarded
	tween.parallel().tween_property(cam, "limit_right", int(new_cam_bounds.end.x), time).from(
		_old_cam_bounds.end.x
	)
	
# warning-ignore:return_value_discarded
	tween.parallel().tween_property(cam, "limit_bottom", int(new_cam_bounds.end.y), time).from(
		_old_cam_bounds.end.y
	)
	
	
func _on_player_entered_zone(body, zone_idx):
	if body.name != "Mum":
		return
	
	var cam = get_viewport().get_camera_2d()
	var zone = zones[zone_idx]
	
	var player_vel = body.velocity
	
	var screen_size = get_viewport().content_scale_size
	
	get_tree().paused = true
	
	
	var tween = create_tween().set_trans(Tween.TRANS_LINEAR).set_ease(Tween.EASE_IN_OUT).set_parallel(true)
	# Make it so the tween doesn't pause
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	var new_player_position = ensure_is_inside_rect2(body.global_position, body.effective_size * 1.3, zone)
	
	tween.parallel().tween_property(body, "global_position", new_player_position, (0.25 if animate else 0.0))
	
	var new_cam_pos = ensure_is_inside_rect2(cam.global_position, screen_size, zone)
	var old_cam_pos = ensure_is_inside_rect2(cam.global_position, screen_size, zones[current_zone_idx])
	var old_cam_bounds = Rect2(old_cam_pos - (screen_size / 2.0), screen_size)
	var new_cam_bounds = Rect2(new_cam_pos - (screen_size / 2.0), screen_size)
	
	
	#interpolate_cam_bounds(cam, tween, zones[current_zone_idx], zone, (1.0 if animate else 0.0))
	interpolate_cam_bounds(cam, tween, old_cam_bounds, new_cam_bounds, (0.5 if animate else 0.0))
	
	
	await tween.finished
	
	set_cam_bounds_from_rect2(cam, zone)

	current_zone_idx = zone_idx
	body.velocity = player_vel
	get_tree().paused = false
