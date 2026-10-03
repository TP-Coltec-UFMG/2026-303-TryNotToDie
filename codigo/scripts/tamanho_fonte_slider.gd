extends HSlider


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	var tema = get_tree().root.theme;
	
	if tema == null:
		tema = Theme.new();
		get_tree().root.theme = tema;
		
	tema.default_font_size = int(value);


# Called every frame. 'delta' is the elapsed time since the previous frame.
#func _process(delta: float) -> void:
	#pass
