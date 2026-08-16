extends Camera2D

@export var max_shake : float = 90.0;
@export var shake_fade : float = 10.0;

var _shake_strength : float = 0.0;

func chacoalhar() -> void:
	_shake_strength = max_shake;
	pass;

func _ready():
	make_current();
	position.x += get_viewport_rect().size.x / 2;
	position.y += get_viewport_rect().size.y / 2;

func _process(delta) -> void:
	if _shake_strength > 0:
		_shake_strength = lerp(_shake_strength, 0.0, shake_fade * delta);
		offset = Vector2(randf_range(-_shake_strength, _shake_strength), randf_range(-_shake_strength, _shake_strength));
