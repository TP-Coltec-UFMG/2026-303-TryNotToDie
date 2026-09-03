extends CanvasLayer

signal abriu;
signal fechou;

const CENA_MENU := "res://cenas/menu.tscn";

var acao: String = "Pausa";

var _aberto: bool = false;
var _fundo: ColorRect;
var _titulo: Label;
var _botoes: Array[Button] = [];


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS;
	layer = 200;
	visible = false;
	_montar_ui();
	Configuracoes.fonte_alterada.connect(_ao_mudar_fonte);
	_aplicar_fonte();


func _input(evento: InputEvent) -> void:
	if not InputMap.has_action(acao):
		return;
	if not evento.is_action_pressed(acao):
		return;
	if not _aberto and not _pode_pausar():
		return;

	get_viewport().set_input_as_handled();

	if _aberto:
		fechar();
	else:
		abrir();


func _ao_mudar_fonte(_tamanho: int) -> void:
	_aplicar_fonte();


func _aplicar_fonte() -> void:
	var tamanho := Configuracoes.tamanho_fonte;
	if _titulo != null and is_instance_valid(_titulo):
		_titulo.add_theme_font_size_override("font_size", tamanho);
	for botao in _botoes:
		if is_instance_valid(botao):
			botao.add_theme_font_size_override("font_size", tamanho);


func esta_aberto() -> bool:
	return _aberto;


func abrir() -> void:
	if _aberto:
		return;
	_aberto = true;
	visible = true;
	get_tree().paused = true;
	if not _botoes.is_empty():
		_botoes[0].grab_focus();
	abriu.emit();


func fechar() -> void:
	if not _aberto:
		return;
	_aberto = false;
	visible = false;
	get_tree().paused = false;
	fechou.emit();


func _pode_pausar() -> bool:
	var atual := get_tree().current_scene;
	if atual == null:
		return false;
	return atual.scene_file_path != CENA_MENU;


func _ao_voltar_ao_menu() -> void:
	fechar();
	Progresso.zerar();
	Fases.reiniciar();
	get_tree().call_deferred("change_scene_to_file", CENA_MENU);


func _ao_sair() -> void:
	get_tree().paused = false;
	get_tree().quit();


func _montar_ui() -> void:
	_fundo = ColorRect.new();
	_fundo.name = "Fundo";
	_fundo.color = Color(0, 0, 0, 0.62);
	_fundo.set_anchors_preset(Control.PRESET_FULL_RECT);
	_fundo.mouse_filter = Control.MOUSE_FILTER_STOP;
	add_child(_fundo);

	var caixa := VBoxContainer.new();
	caixa.name = "Caixa";
	caixa.set_anchors_preset(Control.PRESET_CENTER);
	caixa.grow_horizontal = Control.GROW_DIRECTION_BOTH;
	caixa.grow_vertical = Control.GROW_DIRECTION_BOTH;
	caixa.custom_minimum_size = Vector2(420.0, 0.0);
	caixa.add_theme_constant_override("separation", 18);
	caixa.mouse_filter = Control.MOUSE_FILTER_IGNORE;
	_fundo.add_child(caixa);

	_titulo = Label.new();
	var titulo := _titulo;
	titulo.name = "Titulo";
	titulo.text = "PAUSADO";
	titulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER;
	titulo.mouse_filter = Control.MOUSE_FILTER_IGNORE;
	titulo.add_theme_color_override("font_outline_color", Color(0, 0, 0));
	titulo.add_theme_constant_override("outline_size", 10);
	caixa.add_child(titulo);

	_botoes.clear();
	_botoes.append(_novo_botao(caixa, "RETOMAR", fechar));
	_botoes.append(_novo_botao(caixa, "VOLTAR AO MENU", _ao_voltar_ao_menu));
	_botoes.append(_novo_botao(caixa, "SAIR", _ao_sair));

	for i in _botoes.size():
		var acima: Button = _botoes[(i - 1 + _botoes.size()) % _botoes.size()];
		var abaixo: Button = _botoes[(i + 1) % _botoes.size()];
		_botoes[i].focus_neighbor_top = _botoes[i].get_path_to(acima);
		_botoes[i].focus_neighbor_bottom = _botoes[i].get_path_to(abaixo);
		_botoes[i].focus_previous = _botoes[i].get_path_to(acima);
		_botoes[i].focus_next = _botoes[i].get_path_to(abaixo);


func _novo_botao(onde: Control, texto: String, ao_apertar: Callable) -> Button:
	var botao := Button.new();
	botao.name = texto.capitalize().replace(" ", "");
	botao.text = texto;
	botao.focus_mode = Control.FOCUS_ALL;
	botao.mouse_filter = Control.MOUSE_FILTER_STOP;
	botao.custom_minimum_size = Vector2(0.0, 52.0);
	botao.add_theme_color_override("font_color", Color(1, 1, 1));
	botao.pressed.connect(ao_apertar);
	onde.add_child(botao);
	return botao;
