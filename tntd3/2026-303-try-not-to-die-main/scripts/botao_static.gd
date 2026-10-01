extends Button

var color : bool = true;

func change_color():
	var cor_atual = Color.GREEN if color else Color.WHITE;
	
	set("theme_override_colors/font_color", cor_atual);
	set("theme_override_colors/font_focus_color", cor_atual);
	set("theme_override_colors/font_hover_color", cor_atual);

	color = not color;

func _on_pressed() -> void:
	change_color();
