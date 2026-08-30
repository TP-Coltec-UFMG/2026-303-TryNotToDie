class_name Vinhas
extends StaticBody2D

signal cortadas;
signal recusada;

@export var sprite_vinhas: Node2D;
@export var item_necessario: String = "facao";
@export var flag_cortadas: String = "vinhas_cortadas";

@export_group("Corte")
@export var comprimento_corte: float = 1200.0;
@export var decaimento: float = 300.0;
@export var margem_arrasto: float = 70.0;

@export_group("Dica na tela")
@export var dica_sem_item: String = "Emaranhado demais. Ele precisa de algo que corte";
@export var dica_pronta: String = "Segure o botao e arraste sobre as vinhas";
@export var dica_altura: float = -320.0;

@export_group("Animacao")
@export var duracao_queda: float = 0.8;
@export var tremor_maximo: float = 7.0;

var _jogador: Node2D = null;
var _cortadas: bool = false;
var _progresso: float = 0.0;
var _arrastando: bool = false;
var _tem_anterior: bool = false;
var _anterior: Vector2 = Vector2.ZERO;
var _pos_sprite: Vector2 = Vector2.ZERO;
var _dica: DicaFlutuante = null;
var _camada: CanvasLayer = null;
var _barra: ProgressBar = null;


func _ready() -> void:
	set_process(false);

	if sprite_vinhas != null and is_instance_valid(sprite_vinhas):
		_pos_sprite = sprite_vinhas.position;

	var area := get_node_or_null("AreaInteracao") as Area2D;
	if area != null:
		area.body_entered.connect(_ao_entrar_corpo);
		area.body_exited.connect(_ao_sair_corpo);

	if Progresso.ligado(flag_cortadas):
		_cortadas = true;
		_desligar_colisao();
		if sprite_vinhas != null and is_instance_valid(sprite_vinhas):
			sprite_vinhas.visible = false;
		return;

	_dica = DicaFlutuante.criar(_texto_da_dica(), Vector2(0.0, dica_altura));
	add_child(_dica);


func _process(delta: float) -> void:
	if _cortadas:
		return;

	if _arrastando and not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		_soltar();

	if not _arrastando and _progresso > 0.0:
		_progresso = maxf(0.0, _progresso - decaimento * delta);
		_atualizar_visual();


func _input(event: InputEvent) -> void:
	if _cortadas or _jogador == null:
		return;

	if not Progresso.tem(item_necessario):
		if event is InputEventMouseButton and event.pressed \
				and event.button_index == MOUSE_BUTTON_LEFT \
				and _sobre_as_vinhas(get_global_mouse_position()):
			recusada.emit();
		return;

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed and _sobre_as_vinhas(get_global_mouse_position()):
			_arrastando = true;
			_tem_anterior = false;
			get_viewport().set_input_as_handled();
		else:
			_soltar();
		return;

	if event is InputEventMouseMotion and _arrastando:
		var onde := get_global_mouse_position();
		if not _sobre_as_vinhas(onde):
			_tem_anterior = false;
			return;
		if _tem_anterior:
			_avancar(onde.distance_to(_anterior));
		_anterior = onde;
		_tem_anterior = true;
		get_viewport().set_input_as_handled();


func progresso_atual() -> float:
	return _progresso / maxf(1.0, comprimento_corte);


func cortar_agora() -> void:
	_cortar();


func _avancar(distancia: float) -> void:
	_progresso = minf(comprimento_corte, _progresso + distancia);
	_atualizar_visual();
	if _progresso >= comprimento_corte:
		_cortar();


func _soltar() -> void:
	_arrastando = false;
	_tem_anterior = false;


func _ao_entrar_corpo(corpo: Node2D) -> void:
	if _cortadas or not corpo.is_in_group("jogador"):
		return;
	_jogador = corpo;
	_atualizar_dica(true);
	set_process(true);


func _ao_sair_corpo(corpo: Node2D) -> void:
	if corpo != _jogador:
		return;
	_jogador = null;
	_soltar();
	_progresso = 0.0;
	_atualizar_visual();
	_atualizar_dica(false);
	set_process(false);


func _cortar() -> void:
	if _cortadas:
		return;

	_cortadas = true;
	_soltar();
	set_process(false);
	_apagar_barra();
	_apagar_dica();
	_desligar_colisao();
	Progresso.ligar(flag_cortadas);

	await _animar_queda();
	cortadas.emit();


func _animar_queda() -> void:
	if sprite_vinhas == null or not is_instance_valid(sprite_vinhas):
		return;

	sprite_vinhas.position = _pos_sprite;

	if _sem_animacao():
		sprite_vinhas.visible = false;
		return;

	var tween := create_tween();
	tween.set_parallel();
	tween.tween_property(sprite_vinhas, "rotation_degrees", 82.0, duracao_queda)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN);
	tween.tween_property(sprite_vinhas, "position",
			_pos_sprite + Vector2(-60.0, 170.0), duracao_queda)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN);
	tween.tween_property(sprite_vinhas, "modulate:a", 0.0, duracao_queda * 0.6)\
		.set_delay(duracao_queda * 0.4);
	await tween.finished;

	sprite_vinhas.visible = false;


func _desligar_colisao() -> void:
	for filho in get_children():
		if filho is CollisionShape2D:
			filho.set_deferred("disabled", true);

	var area := get_node_or_null("AreaInteracao") as Area2D;
	if area != null:
		area.set_deferred("monitoring", false);


func _sobre_as_vinhas(ponto: Vector2) -> bool:
	return _retangulo().has_point(ponto);


func _retangulo() -> Rect2:
	var forma: CollisionShape2D = null;
	for filho in get_children():
		if filho is CollisionShape2D:
			forma = filho;
			break;

	if forma == null or not (forma.shape is RectangleShape2D):
		return Rect2(global_position - Vector2(120.0, 240.0), Vector2(240.0, 480.0));

	var tamanho: Vector2 = (forma.shape as RectangleShape2D).size * forma.global_scale;
	return Rect2(forma.global_position - tamanho * 0.5, tamanho).grow(margem_arrasto);


func _atualizar_visual() -> void:
	var fracao := progresso_atual();

	if _progresso <= 0.0:
		_apagar_barra();
	else:
		if _camada == null or not is_instance_valid(_camada):
			_montar_barra();
		_barra.value = fracao * 100.0;

	if sprite_vinhas == null or not is_instance_valid(sprite_vinhas):
		return;

	if _sem_animacao():
		sprite_vinhas.position = _pos_sprite;
		return;

	var tremor := tremor_maximo * fracao;
	sprite_vinhas.position = _pos_sprite + Vector2(randf_range(-tremor, tremor), 0.0);


func _montar_barra() -> void:
	_camada = CanvasLayer.new();
	_camada.layer = 90;
	add_child(_camada);

	var caixa := VBoxContainer.new();
	caixa.set_anchors_preset(Control.PRESET_CENTER_BOTTOM);
	caixa.grow_horizontal = Control.GROW_DIRECTION_BOTH;
	caixa.grow_vertical = Control.GROW_DIRECTION_BEGIN;
	caixa.offset_top = -140.0;
	caixa.custom_minimum_size = Vector2(480.0, 0.0);
	caixa.add_theme_constant_override("separation", 10);
	caixa.mouse_filter = Control.MOUSE_FILTER_IGNORE;
	_camada.add_child(caixa);

	var rotulo := Label.new();
	rotulo.mouse_filter = Control.MOUSE_FILTER_IGNORE;
	rotulo.text = dica_pronta;
	rotulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER;
	rotulo.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART;
	rotulo.add_theme_color_override("font_outline_color", Color(0, 0, 0));
	rotulo.add_theme_constant_override("outline_size", 8);
	caixa.add_child(rotulo);

	_barra = ProgressBar.new();
	_barra.mouse_filter = Control.MOUSE_FILTER_IGNORE;
	_barra.custom_minimum_size = Vector2(0.0, 28.0);
	_barra.min_value = 0.0;
	_barra.max_value = 100.0;
	_barra.value = 0.0;
	_barra.show_percentage = false;
	caixa.add_child(_barra);


func _apagar_barra() -> void:
	if _camada != null and is_instance_valid(_camada):
		_camada.queue_free();
	_camada = null;
	_barra = null;


func _texto_da_dica() -> String:
	return dica_pronta if Progresso.tem(item_necessario) else dica_sem_item;


func _atualizar_dica(mostrar: bool) -> void:
	if _dica == null or not is_instance_valid(_dica):
		return;
	_dica.definir_texto(_texto_da_dica());
	_dica.mostrar(mostrar);


func _apagar_dica() -> void:
	if _dica != null and is_instance_valid(_dica):
		_dica.queue_free();
	_dica = null;


func _sem_animacao() -> bool:
	return Configuracoes.config_ativa(Configuracoes.REMOVER_ANIMACAO);
