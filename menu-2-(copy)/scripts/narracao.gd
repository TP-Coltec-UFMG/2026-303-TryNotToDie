class_name Narracao
extends CanvasLayer

signal terminou;

@export_multiline var linhas: Array[String] = [];
@export var id_evento: String = "intro";
@export var lembrar: bool = true;
@export var segundos_por_linha: float = 5.0;
@export var iniciar_sozinho: bool = true;
@export var congelar_jogador: bool = true;

var _indice: int = -1;
var _rodando: bool = false;
var _rotulo: Label;
var _fundo: ColorRect;
var _dica: Label;
var _tempo_restante: float = 0.0;
var _jogador: Node2D = null;


func _ready() -> void:
	layer = 90;
	visible = false;
	_montar_ui();

	if lembrar and Fases.evento_visto(id_evento):
		return;
	if iniciar_sozinho and not linhas.is_empty():
		await get_tree().process_frame;
		tocar();


func tocar() -> void:
	if _rodando or linhas.is_empty():
		return;

	_rodando = true;
	visible = true;
	_indice = -1;

	if lembrar:
		Fases.marcar_evento(id_evento);

	if congelar_jogador:
		_jogador = get_tree().get_first_node_in_group("jogador") as Node2D;
		_travar(true);

	_avancar();


func _process(delta: float) -> void:
	if not _rodando:
		return;
	_tempo_restante -= delta;
	if _tempo_restante <= 0.0:
		_avancar();


func _input(event: InputEvent) -> void:
	if not _rodando:
		return;

	var seguiu := false;
	if event is InputEventMouseButton and event.pressed \
			and event.button_index == MOUSE_BUTTON_LEFT:
		seguiu = true;
	elif event is InputEventKey and event.pressed and not event.echo:
		seguiu = true;

	if seguiu:
		get_viewport().set_input_as_handled();
		_avancar();


func _avancar() -> void:
	_indice += 1;

	if _indice >= linhas.size():
		_encerrar();
		return;

	_rotulo.text = linhas[_indice];
	_tempo_restante = segundos_por_linha;
	_dica.text = "clique ou qualquer tecla" if _indice < linhas.size() - 1 else "clique para comecar";

	if Configuracoes.config_ativa(Configuracoes.REMOVER_ANIMACAO):
		_rotulo.modulate.a = 1.0;
		return;

	_rotulo.modulate.a = 0.0;
	create_tween().tween_property(_rotulo, "modulate:a", 1.0, 0.35);


func _encerrar() -> void:
	_rodando = false;
	visible = false;
	set_process(false);

	if congelar_jogador:
		_travar(false);

	terminou.emit();


func _travar(travar: bool) -> void:
	if _jogador == null:
		return;
	if travar and _jogador.has_method("cancelar_destino"):
		_jogador.call("cancelar_destino");

	var corpo := _jogador as CharacterBody2D;
	if corpo != null and travar:
		corpo.velocity = Vector2.ZERO;

	_jogador.set_physics_process(not travar);
	_jogador.set_process_unhandled_input(not travar);


func _montar_ui() -> void:
	_fundo = ColorRect.new();
	_fundo.color = Color(0.02, 0.02, 0.04, 0.88);
	_fundo.set_anchors_preset(Control.PRESET_FULL_RECT);
	_fundo.mouse_filter = Control.MOUSE_FILTER_IGNORE;
	add_child(_fundo);

	var caixa := VBoxContainer.new();
	caixa.set_anchors_preset(Control.PRESET_CENTER);
	caixa.grow_horizontal = Control.GROW_DIRECTION_BOTH;
	caixa.grow_vertical = Control.GROW_DIRECTION_BOTH;
	caixa.custom_minimum_size = Vector2(760.0, 0.0);
	caixa.add_theme_constant_override("separation", 28);
	caixa.mouse_filter = Control.MOUSE_FILTER_IGNORE;
	_fundo.add_child(caixa);

	_rotulo = Label.new();
	_rotulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER;
	_rotulo.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART;
	_rotulo.mouse_filter = Control.MOUSE_FILTER_IGNORE;
	caixa.add_child(_rotulo);

	_dica = Label.new();
	_dica.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER;
	_dica.modulate.a = 0.5;
	_dica.mouse_filter = Control.MOUSE_FILTER_IGNORE;
	caixa.add_child(_dica);
