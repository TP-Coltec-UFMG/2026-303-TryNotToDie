extends Button

@export var background : Sprite2D;
@export var Containers : VBoxContainer;
@export var Personagem : AnimatedSprite2D;
@export var principal : Sprite2D;

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass;

# Called every frame. 'delta' is the elapsed time since the previous frame.
#func _process(delta: float) -> void:
	#pass

func _on_pressed() -> void:
	get_tree().change_scene_to_file("res://cenas/game.tscn");
