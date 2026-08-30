class_name Planta
extends Area2D

enum Tipo { VINHA, MUTANTE };

signal cortada;
signal pegou_o_jogador;

@export var tipo: Tipo = Tipo.VINHA;
@export var sprite_planta: Node2D;
@export var item_necessario: String = "facao";

@export_group("Corte")
@export var resistencia: float = 190.0;
@export var margem_arrasto: float = 34.0;

@export_group("Perseguicao")
@export var velocidade: float = 150.0;
@export var alcance: float = 640.0;

@export_group("Vida")
@export var balanco_graus: float = 5.0;
@export var periodo_balanco: float = 1.3;
@export var duracao_morte: float = 0.35;

var _cortada: bool = false;
var _matou: bool = false;
var _progresso: float = 0.0;
var _arrastando: bool = false;
var _tem_anterior: bool = false;
var _anterior: Vector2 = Vector2.ZERO;
var _tempo: float = 0.0;
var _jogador: Node2D = null;
var _cor_base: Color = Color.WHITE;
var _escala_base: Vector2 = Vector2.ONE;


func _ready() -> void:
	body_entered.connect(_ao_encostar);

	if sprite_planta != null and is_instance_valid(sprite_planta):
		_cor_base = sprite_planta.modulate;
		_escala_base = sprite_planta.scale;

	_tempo = randf() * TAU;


func _physics_process(delta: float) -> void:
	if _cortada:
		return;

	if _jogador == null or not is_instance_valid(_jogador):
		_jogador = get_tree().get_first_node_in_group("jogador") as Node2D;

	_tempo += delta;

	if tipo == Tipo.MUTANTE and _jogador != null and not _sem_animacao():
		var distancia := global_position.x - _jogador.global_position.x;
		if absf(distancia) < alcance:
			global_position.x -= signf(distancia) * velocidade * delta;

	_balancar();


func _input(event: InputEvent) -> void:
	if _cortada:
		return;

	if item_necessario != "" and not Progresso.tem(item_necessario):
		return;

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed and _sobre_a_planta(get_global_mouse_position()):
			_arrastando = true;
			_tem_anterior = false;
		else:
			_soltar();
		return;

	if event is InputEventMouseMotion:
		if not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
			_soltar();
			return;

		var onde := get_global_mouse_position();
		if not _sobre_a_planta(onde):
			_tem_anterior = false;
			return;

		_arrastando = true;
		if _tem_anterior:
			_avancar(onde.distance_to(_anterior));
		_anterior = onde;
		_tem_anterior = true;


func progresso_atual() -> float:
	return _progresso / maxf(1.0, resistencia);


func cortar_agora() -> void:
	_cortar();


func foi_cortada() -> bool:
	return _cortada;


func _avancar(distancia: float) -> void:
	_progresso = minf(resistencia, _progresso + distancia);
	_pintar();
	if _progresso >= resistencia:
		_cortar();


func _soltar() -> void:
	_arrastando = false;
	_tem_anterior = false;


func _sobre_a_planta(ponto: Vector2) -> bool:
	return _retangulo().has_point(ponto);


func _retangulo() -> Rect2:
	var forma: CollisionShape2D = null;
	for filho in get_children():
		if filho is CollisionShape2D:
			forma = filho;
			break;

	if forma == null or not (forma.shape is RectangleShape2D):
		return Rect2(global_position - Vector2(50.0, 50.0), Vector2(100.0, 100.0));

	var tamanho: Vector2 = (forma.shape as RectangleShape2D).size * forma.global_scale;
	return Rect2(forma.global_position - tamanho * 0.5, tamanho).grow(margem_arrasto);


func _balancar() -> void:
	if sprite_planta == null or not is_instance_valid(sprite_planta):
		return;
	if _sem_animacao():
		sprite_planta.rotation = 0.0;
		return;
	var frequencia := TAU / maxf(0.05, periodo_balanco);
	sprite_planta.rotation = deg_to_rad(balanco_graus * sin(_tempo * frequencia));


func _pintar() -> void:
	if sprite_planta == null or not is_instance_valid(sprite_planta):
		return;
	var f := progresso_atual();
	sprite_planta.modulate = _cor_base.lerp(Color(1.0, 1.0, 0.85), f * 0.8);
	sprite_planta.scale = _escala_base * (1.0 + 0.12 * f);


func _cortar() -> void:
	if _cortada:
		return;

	_cortada = true;
	_soltar();
	set_physics_process(false);
	set_deferred("monitoring", false);

	for filho in get_children():
		if filho is CollisionShape2D:
			filho.set_deferred("disabled", true);

	cortada.emit();

	if sprite_planta == null or not is_instance_valid(sprite_planta) or _sem_animacao():
		queue_free();
		return;

	var tween := create_tween();
	tween.set_parallel();
	tween.tween_property(sprite_planta, "scale", _escala_base * Vector2(1.5, 0.2), duracao_morte)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN);
	tween.tween_property(sprite_planta, "rotation_degrees", 70.0, duracao_morte);
	tween.tween_property(sprite_planta, "modulate:a", 0.0, duracao_morte);
	await tween.finished;

	queue_free();


func _ao_encostar(corpo: Node2D) -> void:
	if _cortada or _matou or not corpo.is_in_group("jogador"):
		return;
	if corpo.has_method("esta_morrendo") and corpo.call("esta_morrendo"):
		return;

	_matou = true;
	set_physics_process(false);
	pegou_o_jogador.emit();

	if corpo.has_method("morrer"):
		await corpo.call("morrer");
	else:
		await get_tree().create_timer(0.8).timeout;

	Fases.voltar_ao_ponto();


func _sem_animacao() -> bool:
	return Configuracoes.config_ativa(Configuracoes.REMOVER_ANIMACAO);
