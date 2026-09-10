class_name QTE
extends CanvasLayer

enum Modo { MARTELAR, SEGURAR };

signal terminou(venceu: bool);

const ACOES: Array[String] = ["Left", "Right", "Jump", "Down"];

var modo: Modo = Modo.MARTELAR;
var texto: String = "";
var tempo_limite: float = 5.0;
var toques_necessarios: int = 14;
var tempo_segurando: float = 1.5;
var congelar_jogador: bool = true;
var acoes_validas: Array[String] = [];
var aceita_mouse: bool = true;
var dica_personalizada: String = "";

var anjo_visivel: bool = true;
var anjo_quadros: SpriteFrames = null;
var anjo_animacao: String = "";
var anjo_deslocamento: Vector2 = Vector2(-170.0, -60.0);
var anjo_onde: Callable = Callable();
var anjo_toca_sino: bool = true;
var anjo_espelha_o_jogador: bool = false;

var _progresso: float = 0.0;
var _restante: float = 0.0;
var _acabou: bool = false;
var _jogador: Node2D = null;
var _anjo: Anjo = null;

var _barra: ProgressBar;
var _rotulo: Label;
var _tempo_rotulo: Label;


static func martelar(rotulo: String, duracao: float, toques: int) -> QTE:
	var q := QTE.new();
	q.modo = Modo.MARTELAR;
	q.texto = rotulo;
	q.tempo_limite = duracao;
	q.toques_necessarios = maxi(1, toques);
	return q;


static func tecla(rotulo: String, acao: String, duracao: float,
		toques: int = 1, dica: String = "") -> QTE:
	var q := QTE.new();
	q.modo = Modo.MARTELAR;
	q.texto = rotulo;
	q.tempo_limite = duracao;
	q.toques_necessarios = maxi(1, toques);
	q.acoes_validas = [acao];
	q.dica_personalizada = dica;
	return q;


static func segurar(rotulo: String, segundos: float, limite: float) -> QTE:
	var q := QTE.new();
	q.modo = Modo.SEGURAR;
	q.texto = rotulo;
	q.tempo_segurando = maxf(0.1, segundos);
	q.tempo_limite = limite;
	return q;


func com_anjo(quadros: SpriteFrames, anim: String = "",
		deslocamento: Vector2 = Vector2.ZERO, toca_sino: bool = true) -> QTE:
	anjo_visivel = true;
	anjo_quadros = quadros;
	anjo_animacao = anim;
	anjo_toca_sino = toca_sino;
	if deslocamento != Vector2.ZERO:
		anjo_deslocamento = deslocamento;
	return self;


func lado_a_lado(quadros: SpriteFrames, anim: String = "",
		distancia: float = 90.0) -> QTE:
	anjo_visivel = true;
	anjo_quadros = quadros;
	anjo_animacao = anim;
	anjo_deslocamento = Vector2(-absf(distancia), 0.0);
	anjo_espelha_o_jogador = true;
	return self;


func com_anjo_em(onde: Callable) -> QTE:
	anjo_visivel = true;
	anjo_onde = onde;
	return self;


func sem_anjo() -> QTE:
	anjo_visivel = false;
	return self;


func _ready() -> void:
	layer = 100;
	_montar_ui();

	_restante = tempo_limite;

	_jogador = get_tree().get_first_node_in_group("jogador") as Node2D;

	if congelar_jogador:
		_travar(true);

	_chamar_anjo();


func _chamar_anjo() -> void:
	if not anjo_visivel or _jogador == null or not is_instance_valid(_jogador):
		return;

	var pai := _jogador.get_parent();
	if pai == null:
		return;

	var onde := _jogador.global_position + anjo_deslocamento;
	if anjo_onde.is_valid():
		var pedido: Variant = anjo_onde.call(_jogador);
		if pedido is Vector2:
			onde = pedido;

	var rumo := _jogador.global_position.x - onde.x;
	if anjo_espelha_o_jogador:
		rumo = -1.0 if _flip_do_jogador() else 1.0;

	_anjo = Anjo.acompanhar(pai, onde, rumo, anjo_quadros, anjo_animacao, anjo_toca_sino);


func _flip_do_jogador() -> bool:
	if _jogador == null or not is_instance_valid(_jogador):
		return false;
	for filho in _jogador.get_children():
		if filho is AnimatedSprite2D or filho is Sprite2D:
			return filho.flip_h;
	return false;


func _despedir_anjo() -> void:
	if _anjo != null and is_instance_valid(_anjo):
		_anjo.despedir();
	_anjo = null;


func _process(delta: float) -> void:
	if _acabou:
		return;

	_restante -= delta;
	_tempo_rotulo.text = "%.1fs" % maxf(0.0, _restante);

	if modo == Modo.SEGURAR:
		if _apertado():
			_progresso += delta / tempo_segurando;
		else:
			_progresso -= delta / (tempo_segurando * 2.0);
		_progresso = clampf(_progresso, 0.0, 1.0);

	_barra.value = _progresso * 100.0;

	if _progresso >= 1.0:
		_encerrar(true);
	elif _restante <= 0.0:
		_encerrar(false);


func _input(event: InputEvent) -> void:
	if _acabou or modo != Modo.MARTELAR:
		return;

	var contou := false;
	if aceita_mouse and event is InputEventMouseButton and event.pressed \
			and event.button_index == MOUSE_BUTTON_LEFT:
		contou = true;
	else:
		for acao in _acoes():
			if event.is_action_pressed(acao):
				contou = true;
				break;

	if contou:
		_progresso = minf(1.0, _progresso + 1.0 / float(toques_necessarios));
		get_viewport().set_input_as_handled();


func progresso_atual() -> float:
	return _progresso;


func _acoes() -> Array:
	return acoes_validas if not acoes_validas.is_empty() else ACOES;


func _apertado() -> bool:
	if aceita_mouse and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		return true;
	for acao in _acoes():
		if Input.is_action_pressed(acao):
			return true;
	return false;


func _encerrar(venceu: bool) -> void:
	if _acabou:
		return;
	_acabou = true;
	set_process(false);

	_despedir_anjo();

	if congelar_jogador:
		_travar(false);

	terminou.emit(venceu);
	queue_free();


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
	var fundo := ColorRect.new();
	fundo.color = Color(0, 0, 0, 0.45);
	fundo.set_anchors_preset(Control.PRESET_FULL_RECT);
	fundo.mouse_filter = Control.MOUSE_FILTER_IGNORE;
	add_child(fundo);

	var caixa := VBoxContainer.new();
	caixa.set_anchors_preset(Control.PRESET_CENTER);
	caixa.grow_horizontal = Control.GROW_DIRECTION_BOTH;
	caixa.grow_vertical = Control.GROW_DIRECTION_BOTH;
	caixa.custom_minimum_size = Vector2(560, 0);
	caixa.add_theme_constant_override("separation", 12);
	caixa.mouse_filter = Control.MOUSE_FILTER_IGNORE;
	fundo.add_child(caixa);

	_rotulo = Label.new();
	_rotulo.mouse_filter = Control.MOUSE_FILTER_IGNORE;
	_rotulo.text = texto;
	_rotulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER;
	_rotulo.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART;
	caixa.add_child(_rotulo);

	var dica := Label.new();
	dica.mouse_filter = Control.MOUSE_FILTER_IGNORE;
	if not dica_personalizada.is_empty():
		dica.text = dica_personalizada;
	elif modo == Modo.MARTELAR:
		dica.text = "MARTELE as teclas ou clique!";
	else:
		dica.text = "SEGURE uma tecla ou o botao do mouse!";
	dica.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER;
	dica.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART;
	caixa.add_child(dica);

	_barra = ProgressBar.new();
	_barra.mouse_filter = Control.MOUSE_FILTER_IGNORE;
	_barra.custom_minimum_size = Vector2(0, 36);
	_barra.min_value = 0.0;
	_barra.max_value = 100.0;
	_barra.value = 0.0;
	_barra.show_percentage = false;
	caixa.add_child(_barra);

	_tempo_rotulo = Label.new();
	_tempo_rotulo.mouse_filter = Control.MOUSE_FILTER_IGNORE;
	_tempo_rotulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER;
	caixa.add_child(_tempo_rotulo);
