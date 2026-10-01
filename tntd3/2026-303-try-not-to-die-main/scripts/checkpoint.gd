class_name Checkpoint
extends Marker2D

signal alcancado;

@export var area: Area2D;

var _usado: bool = false;


func _ready() -> void:
	if area == null:
		area = get_node_or_null("Area2D") as Area2D;
	if area != null:
		area.body_entered.connect(_ao_entrar);


func _ao_entrar(corpo: Node2D) -> void:
	if _usado or not corpo.is_in_group("jogador"):
		return;
	_usado = true;
	Fases.marcar_ponto(String(name));
	alcancado.emit();
