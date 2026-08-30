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


@export var amplitude_graus: float = 0.8;
@export var periodo_segundos: float = 30.0;
@export_range(0.0, 3.0) var ganho_por_altura: float = 0.3;
@export var distorcao_maxima: Vector2 = Vector2(0.035, 0.045);
@export_range(1.0, 5.0) var distorcao_teto: float = 2.0;
@export var periodo_tremor: float = 0.28;

var _comodos: Array[Comodo] = [];
var _tempo: float = 0.0;
var _tempo_tremor: float = 0.0;
var _impulso: float = 0.0;
var _decaimento_impulso: float = 1.6;


func _ready() -> void:
	mapear_comodos();
	Configuracoes.config_alterada.connect(_ao_mudar_config);

	if _sem_animacao():
		_congelar();


func _physics_process(delta: float) -> void:
	if _sem_animacao():
		return;

	_tempo += delta;

	if _impulso > 0.0:
		_impulso = move_toward(_impulso, 0.0, _decaimento_impulso * delta);
		_tempo_tremor += delta;
	else:
		_tempo_tremor = 0.0;

	var frequencia := TAU / maxf(0.05, periodo_segundos);
	var graus := amplitude_graus * sin(_tempo * frequencia);

	if _impulso > 0.0:
		var frequencia_tremor := TAU / maxf(0.02, periodo_tremor);
		graus += amplitude_graus * _impulso * sin(_tempo_tremor * frequencia_tremor);

	for comodo in _comodos:
		if not is_instance_valid(comodo.no):
			continue;
		var inclinacao := graus * comodo.peso;
		comodo.no.rotation = comodo.rotacao_base + deg_to_rad(inclinacao);
		_distorcer(comodo, inclinacao);


func _distorcer(comodo: Comodo, inclinacao: float) -> void:
	if comodo.sprite == null or not is_instance_valid(comodo.sprite):
		return;

	var fracao := clampf(absf(inclinacao) / maxf(0.01, amplitude_graus), 0.0, distorcao_teto);
	var fator := Vector2.ONE + distorcao_maxima * fracao;

	comodo.sprite.scale = comodo.escala_base * fator;

	var altura := comodo.altura_base * fator.y;
	comodo.sprite.position = Vector2(
		comodo.pos_base.x,
		comodo.pos_base.y + (altura - comodo.altura_base) * 0.5
	);

func soltar_comodo(nome: String) -> Node2D:
	for i in _comodos.size():
		var comodo := _comodos[i];
		if is_instance_valid(comodo.no) and comodo.no.name == nome:
			_restaurar_sprite(comodo);
			_comodos.remove_at(i);
			return comodo.no;
	return null;


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

		var altura_rel := 0.0;
		if not is_equal_approx(y_max, y_min):
			altura_rel = (y_max - no.position.y) / (y_max - y_min);

		comodo.peso = 1.0 + ganho_por_altura * altura_rel;

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
