extends CanvasLayer

# Declare member variables here. Examples:
# var a = 2
# var b = "text"

# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.

# Called every frame. 'delta' is the elapsed time since the previous frame.
#func _process(delta):
#	pass


func _on_Gun_on_ammo_change(value, max_value):
	
	var percent = (value * 100) / max_value
	
	$AmmoContainer/VBoxContainer/TextureProgress/Tween.interpolate_property(
		$AmmoContainer/VBoxContainer/TextureProgress, "value",
		$AmmoContainer/VBoxContainer/TextureProgress.value, percent, 0.2, Tween.TRANS_LINEAR, Tween.EASE_IN_OUT
	)
	
	$AmmoContainer/VBoxContainer/TextureProgress/Tween.start()
	
	#$AmmoContainer/VBoxContainer/ProgressBar.value = (value * 100) / max_value
	
	pass # Replace with function body.


func _on_Player_on_drop_object(object):
	
	$AmmoContainer.visible = false
	
	if object.is_in_group("weapon"):
		object.disconnect("on_ammo_change", self, "_on_Gun_on_ammo_change")
	


func _on_Player_on_take_object(object):
	
	if object.is_in_group("weapon"):
		object.connect("on_ammo_change", self, "_on_Gun_on_ammo_change")
		$AmmoContainer.visible = true
		
		_on_Gun_on_ammo_change(object.ammo, object.max_ammo)
	


func _on_Player_on_health_change(value, max_value):
	
	var percent = (value * 100) / max_value
	
	$HealthContainer/VBoxContainer/TextureProgress/Tween.interpolate_property(
		$HealthContainer/VBoxContainer/TextureProgress, "value",
		$HealthContainer/VBoxContainer/TextureProgress.value, percent, 0.2, Tween.TRANS_LINEAR, Tween.EASE_IN_OUT
	)
	
	$HealthContainer/VBoxContainer/TextureProgress/Tween.start()
	
	#$HealthContainer/VBoxContainer/ProgressBar.value = percent
	
	pass # Replace with function body.
