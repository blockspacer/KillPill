extends KinematicBody

class_name Pill

var PillExplosion = preload("res://effects/explosions/PillExplosion.tscn")

var CatchableObject = preload("res://tools/CatchableObject.tscn")

const ACCEL= 4
const DEACCEL= 8
const GRAVITY := -9.8

signal on_health_change(value, max_value)
signal on_drop_object(object)
signal on_take_object(object)
signal on_hold_object(object)
signal on_death

export var team : String = "Team_0"

export var move_speed = 5.0
export var max_health = 100
export var immortal := false

export var ia = false

export(String, "Blue", "Red", "Yellow") var color setget set_color

var health = max_health

var dead = false

var velocity = Vector3()

var look_dir = Vector3()

var ennemies := []

var target_pos = null

func has_object() -> bool:
	return $BodyRightHand/RightHand.get_child_count() > 0

func get_object():
	if has_object():
		return $BodyRightHand/RightHand.get_child(0)
	return null

func is_holding() -> bool:
	return $HoldPosition.get_child_count() > 0

#
# See weakref
#
# https://godotengine.org/qa/3645/previously-freed-instance-error
#
func take_object(object_container) -> bool:
	if not has_object() and object_container != null and object_container.has_object():
		var object = object_container.take_object()
		$BodyRightHand/RightHand.add_child(object)
		object.owned = true
		$PickUpSound.play()
		emit_signal("on_take_object", object)
		return true
	return false

func drop_object():
	if has_object():
		var object = $BodyRightHand/RightHand.get_child(0)
		$BodyRightHand/RightHand.remove_child(object)
		
		var catchable_object = CatchableObject.instance()
		catchable_object.set_object(object)
		
		var root = get_tree().get_root().get_node("Game")
		root.find_node("Objects").add_child(catchable_object)
		
		catchable_object.global_transform.origin = global_transform.origin
		
		var dir = $BodyRightHand/RightHand.global_transform.basis.z + Vector3.UP
		
		catchable_object.apply_central_impulse(dir.normalized() * 4 + velocity)
		
		object.owned = false
		emit_signal("on_drop_object", object)


func hold_object(object) -> bool:
	
	if not is_holding() and object.is_in_group("catchable"):
		
		if object.hold(self):
			object.get_parent().remove_child(object)
			object.transform.origin = Vector3()
			object.transform.basis = Basis()
			$HoldPosition.add_child(object)
			
			$BodyRightHand/RightHand.visible = false
			$AnimationTree.set("parameters/HoldObject/blend_amount", 1.0)
			
			emit_signal("on_hold_object", object)
			
			return true
	
	return false

func get_holded():
	if is_holding():
		return $HoldPosition.get_child(0)
	return null

func release_hold() -> bool:
	
	if is_holding():
		
		var object = $HoldPosition.get_child(0)
		
		$HoldPosition.remove_child(object)
		
		var root = get_tree().get_root().get_node("Game")
		root.get_node("Objects").add_child(object)
		
		var dir = ($HoldPosition.global_transform.basis.z + Vector3.UP).normalized()
		object.global_transform.origin = global_transform.origin + dir
		object.release()
		
		object.apply_central_impulse(dir * 4 + velocity)
		
		$BodyRightHand/RightHand.visible = true
		$AnimationTree.set("parameters/HoldObject/blend_amount", 0.0)
		return true
	
	return false


func shoot() -> bool:
	
	if not is_holding():
		var right_hand = $BodyRightHand/RightHand
		if right_hand.get_child_count() > 0:
			
			_aiming_target()
			
			var weapon = right_hand.get_child(0)
			return weapon.shoot()
	else:
		print("[%s] Cannot shoot. He is holding box !" % get_name() )
	return false

func punch() -> bool:
	
	if not is_holding():
		
		$AnimationTree.set("parameters/Punch/active", true)
		
		var result = $CatchArea.get_overlapping_bodies()
		
		var nearest_object = null
		var nearest_distance = null
		
		for object in result:
			if object.has_method("damage") and object != self:
				
				var distance = (object.global_transform.origin - self.global_transform.origin).length()
				
				if nearest_distance == null or distance < nearest_distance:
					nearest_distance = distance
					nearest_object = object
		
		if nearest_object != null:
			nearest_object.damage($BodyLeftHand.global_transform.origin, null, {"damage": 1})
			return true
		

	return false


func catch_front() -> bool:
	
	for area in $CatchArea.get_overlapping_areas():
		if area.is_in_group("catchable"):
			if take_object(area):
				return true
	
	for object in $CatchArea.get_overlapping_bodies():
		if not is_holding() and object.is_in_group("catchable"):
			if hold_object(object):
				return true
	
	return false
	

"""
Action to build and drop box on constructor
"""
func use_front() -> bool:
	
	var areas = $CatchArea.get_overlapping_areas()
	
	if is_holding():
		
		var object = $HoldPosition.get_child(0)
		
		if not areas.empty():
			var area = areas[0]
			
			return constructor_put_box(area, object)
			
	
	for area in areas:
		if constructor_build(area):
			return true
	
	return false

func constructor_build(constructor) -> bool:
	if constructor.is_in_group("constructor") and constructor.team == team:
		constructor.build()
		return true
	return false

func constructor_put_box(constructor, box) -> bool:
	
	if constructor.is_in_group("constructor") and constructor.team == team:
		$HoldPosition.remove_child(box)
		var added = constructor.add_object($CatchArea, box)
		if added:
			$BodyRightHand/RightHand.visible = true
			$AnimationTree.set("parameters/HoldObject/blend_amount", 0.0)
			return true
		else:
			$HoldPosition.add_child(box)
	return false


func heal(value) -> bool:
	
	if health >= max_health:
		return false
	
	health += value
	
	if health > max_health:
		health = max_health
	
	emit_signal("on_health_change", health, max_health)
	
	return true

func damage(position, normal, bullet):
	
	if immortal:
		return
	
	health -= bullet.damage
	emit_signal("on_health_change", health, max_health)
	
	$AnimationTree.set("parameters/Hit/active", true)
	
	if health <= 0:
		dead = true
		
		release_hold()
		drop_object()
		
		var explosion = PillExplosion.instance()
		get_parent().add_child(explosion)
		explosion.global_transform.origin = self.global_transform.origin
		explosion.color = color
		queue_free()
		emit_signal("on_death")
	

func set_color(value):
	
	color = value
	
	match color:
		"Blue":
			var material = load("res://characters/Buddy/BodyBlue.material")
			$Body/Body.set_surface_material(0, material)
		
		"Red":
			var material = load("res://characters/Buddy/BodyRed.material")
			$Body/Body.set_surface_material(0, material)
		"Yellow":
			var material = load("res://characters/Buddy/BodyYellow.material")
			$Body/Body.set_surface_material(0, material)


func _control(delta) -> Vector3:
	return Vector3()

func _aiming_target():
	var right_hand = $BodyRightHand/RightHand
	
	if not is_holding() and right_hand.get_child_count() > 0 and target_pos != null:
		
		var target_transform = Transform(Basis(), target_pos)
		target_transform.origin.y = right_hand.global_transform.origin.y
		
		right_hand.global_transform.basis = target_transform.looking_at($BodyRightHand.global_transform.origin, Vector3.UP).basis
	elif target_pos == null:
		right_hand.transform.basis = Basis()

func _next_target_pos(target: Pill, t=1.0):
	return target.global_transform.origin + (target.velocity * 2.0) * t 

func _next_shoot_rayon(t):
	var gun = $BodyRightHand/RightHand.get_child(0)
	return gun.bullet_speed * t

func _next_shoot_pos(target: Pill):
	
	var min_delta = null
	var shoot_pos = null
	
	for i in range(20):
		var t: float = i * 0.2
		
		var next_target_pos = _next_target_pos(target, t)
		var length = (global_transform.origin - next_target_pos).length()
		var shoot_length = _next_shoot_rayon(t)
		var delta = abs(length - shoot_length)
		
		#print("[t=%f, length=%f, shoot_length=%f, delta=%f] " % [t, length, shoot_length, abs(length - shoot_length)])
		
		if min_delta == null or delta < min_delta:
			min_delta = delta
			shoot_pos = next_target_pos
	
	#print("shoot_pos: ", shoot_pos, ", target: ", target.global_transform.origin)
	return shoot_pos

# Called when the node enters the scene tree for the first time.
func _ready():
	
	health = max_health
	
	set_color(color)
	
	emit_signal("on_health_change", health, max_health)
	


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	
	
	#
	# Gun direction update to target_pos
	#
	
	_aiming_target()
	
	
	#
	# Move
	#
	var dir = Vector3()
	if not dead:
		dir = _control(delta)
	
	velocity.y += delta * GRAVITY
	
	var hvel = velocity
	hvel.y = 0
	
	var target = dir * move_speed
	
	var accel
	if dir.dot(hvel) > 0:
		accel = ACCEL
	else:
		accel = DEACCEL
	
	hvel = hvel.linear_interpolate(target, accel * delta)
	
	velocity.x = hvel.x
	velocity.z = hvel.z
	
	
	
	velocity = self.move_and_slide( velocity, Vector3.UP )
	
	var state_machines = $AnimationTree["parameters/Move/playback"]
	
	if velocity.length() > 0.1:
		var angle = atan2(velocity.x, velocity.z)
		var rot = get_rotation()
		rot.y = angle;
		set_rotation(rot)
		
		if state_machines.is_playing():
			state_machines.travel("walk-cycle")
		else:
			state_machines.start("walk-cycle")
	else:
		if state_machines.is_playing():
			state_machines.travel("idle")
		else:
			state_machines.start("idle")
	
	if look_dir != Vector3():
		var look_pos = global_transform.origin - look_dir
		var rotTransform = global_transform.looking_at(look_pos, Vector3.UP)
		global_transform = Transform(rotTransform.basis, global_transform.origin)
		
		pass
	
	pass


func _on_EnnemyDetection_body_entered(character):
	
	if not ennemies.has(character) and character.team != self.team:
		ennemies.append(character)
	

func _on_EnnemyDetection_body_exited(character):
	
	var index = ennemies.find( character )
	if index != -1:
		ennemies.remove(index)
	
