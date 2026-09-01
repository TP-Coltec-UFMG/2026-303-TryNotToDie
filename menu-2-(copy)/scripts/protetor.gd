class_name Protetor
extends Node2D

signal aplicado;
signal recusado(motivo: String);

@export var jogador: Node2D;
@export var item_necessario: String = "protetor_solar";
@export var raio_do_clique: float = 140.0;

@export_group("Tempos")
@export var duracao_protecao: float = 1.3;
@export var recarga: float = 2.4;

@export_group("Aparencia")
@export var cor_protegido: Color = Color(1.0, 0.94, 0.55, 1.0);
@export var texto_hud: String = "Clique nele para passar protetor";

var _restante: float = 0.0;
var _espera: float = 0.0;
var _camada: CanvasLayer = null;
var _barra: ProgressBar = null;
var _rotulo: Label = null;
var _alvo: CanvasItem = null;


func _ready() -> void:
	add_to_group("protetor");

	if jogador == null:
		jogador = get_tree().get_first_node_in_group("jogador") as Node2D;
	if jogador != null:
		_alvo = jogador.get_node_or_null("Sprite") as CanvasItem;
		if _alvo == null:
			_alvo = jogador as CanvasItem;

	_montar_hud();
	_atualizar_hud();


func _process(delta: float) -> void:
	if _restante > 0.0:
		_restante = maxf(0.0, _restante - delta);
		if _restante == 0.0:
			_pintar(false);

	if _espera > 0.0:
		_espera = maxf(0.0, _espera - delta);

	_atualizar_hud();


func _input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton and event.pressed \
			and event.button_index == MOUSE_BUTTON_LEFT):
		return;
	if jogador == null or not is_instance_valid(jogador):
		return;
	if jogador.has_method("esta_morrendo") and jogador.call("esta_morrendo"):
		return;

	if get_global_mouse_position().distance_to(jogador.global_position) > raio_do_clique:
		return;

	get_viewport().set_input_as_handled();
	aplicar();


func aplicar() -> bool:
	if item_necessario != "" and not Progresso.tem(item_necessario):
		recusado.emit("sem_item");
		return false;

	if _espera > 0.0:
		recusado.emit("recarregando");
		return false;

	_restante = duracao_protecao;
	_espera = recarga;
	_pintar(true);
	_atualizar_hud();
	aplicado.emit();
	return true;


func esta_protegido() -> bool:
	return _restante > 0.0;


func pronto() -> bool:
	return _espera <= 0.0;


func _pintar(ligado: bool) -> void:
	if _alvo == null or not is_instance_valid(_alvo):
		return;
	if ligado and not _sem_animacao():
		_alvo.modulate = cor_protegido;
	else:
		_alvo.modulate = Color.WHITE;


func _montar_hud() -> void:
	_camada = CanvasLayer.new();
	_camada.layer = 80;
	add_child(_camada);

	var caixa := VBoxContainer.new();
	caixa.set_anchors_preset(Control.PRESET_CENTER_BOTTOM);
	caixa.grow_horizontal = Control.GROW_DIRECTION_BOTH;
	caixa.grow_vertical = Control.GROW_DIRECTION_BEGIN;
	caixa.offset_top = -110.0;
	caixa.custom_minimum_size = Vector2(420.0, 0.0);
	caixa.add_theme_constant_override("separation", 8);
	caixa.mouse_filter = Control.MOUSE_FILTER_IGNORE;
	_camada.add_child(caixa);

	_rotulo = Label.new();
	_rotulo.mouse_filter = Control.MOUSE_FILTER_IGNORE;
	_rotulo.text = texto_hud;
	_rotulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER;
	_rotulo.add_theme_color_override("font_outline_color", Color(0, 0, 0));
	_rotulo.add_theme_constant_override("outline_size", 8);
	caixa.add_child(_rotulo);

	_barra = ProgressBar.new();
	_barra.mouse_filter = Control.MOUSE_FILTER_IGNORE;
	_barra.custom_minimum_size = Vector2(0.0, 22.0);
	_barra.min_value = 0.0;
	_barra.max_value = 100.0;
	_barra.value = 100.0;
	_barra.show_percentage = false;
	caixa.add_child(_barra);


func _atualizar_hud() -> void:
	if _barra == null or not is_instance_valid(_barra):
		return;

	if _restante > 0.0:
		_barra.value = _restante / maxf(0.01, duracao_protecao) * 100.0;
		_rotulo.text = "PROTEGIDO";
		return;

	if _espera > 0.0:
		_barra.value = (1.0 - _espera / maxf(0.01, recarga)) * 100.0;
		_rotulo.text = "passando protetor...";
		return;

	_barra.value = 100.0;
	_rotulo.text = texto_hud;


func _sem_animacao() -> bool:
	return Configuracoes.config_ativa(Configuracoes.REMOVER_ANIMACAO);
