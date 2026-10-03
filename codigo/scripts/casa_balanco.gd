class_name CasaBalanco
extends Node2D

class Comodo:
	var no: Node2D;
	var sprite: Node2D;
	var rotacao_base: float;
	var peso: float;
	var escala_base: Vector2;
	var pos_base: Vector2;
	var altura_base: float;


@export var periodo_tremor: float = 0.28;

var _comodos: Array[Comodo] = [];
var _tempo: float = 0.0;
var _tempo_tremor: float = 0.0;
var _impulso: float = 0.0;


func _ready() -> void:
	mapear_comodos();
	Configuracoes.config_alterada.connect(_ao_mudar_config);

	if _sem_animacao():
		_congelar();


func _physics_process(delta: float) -> void:
	if _sem_animacao():
		return;

	_tempo += delta;


func mapear_comodos() -> void:
	_comodos.clear();

	var candidatos: Array[Node2D] = [];
	for filho in get_children():
		if filho is Node2D:
			candidatos.append(filho);

	if candidatos.is_empty():
		set_physics_process(false);
		return;

	set_physics_process(true);

	var y_min: float = candidatos[0].position.y;
	var y_max: float = candidatos[0].position.y;
	for no in candidatos:
		y_min = minf(y_min, no.position.y);
		y_max = maxf(y_max, no.position.y);

	for no in candidatos:
		var comodo := Comodo.new();
		comodo.no = no;
		comodo.rotacao_base = no.rotation;

		var sprite := _sprite_de(no);
		comodo.sprite = sprite;
		if sprite != null:
			comodo.escala_base = sprite.scale;
			comodo.pos_base = sprite.position;
			comodo.altura_base = _altura_de(sprite);

		_comodos.append(comodo);


func _sprite_de(no: Node2D) -> Node2D:
	for filho in no.get_children():
		if filho is Sprite2D or filho is AnimatedSprite2D:
			return filho;
	return null;


func _altura_de(sprite: Node2D) -> float:
	var sp := sprite as Sprite2D;
	if sp == null or sp.texture == null:
		return 0.0;
	var h: float = sp.region_rect.size.y if sp.region_enabled else sp.texture.get_size().y;
	return h * sp.scale.y;


func _restaurar_sprite(comodo: Comodo) -> void:
	if comodo.sprite == null or not is_instance_valid(comodo.sprite):
		return;
	comodo.sprite.scale = comodo.escala_base;
	comodo.sprite.position = comodo.pos_base;


func _congelar() -> void:
	for comodo in _comodos:
		if not is_instance_valid(comodo.no):
			continue;
		comodo.no.rotation = comodo.rotacao_base;
		_restaurar_sprite(comodo);
	_impulso = 0.0;
	_tempo_tremor = 0.0;


func _sem_animacao() -> bool:
	return Configuracoes.config_ativa(Configuracoes.REMOVER_ANIMACAO);


func _ao_mudar_config(chave: String, _valor: bool) -> void:
	if chave != Configuracoes.REMOVER_ANIMACAO:
		return;
	if Configuracoes.config_ativa(Configuracoes.REMOVER_ANIMACAO):
		_congelar();
