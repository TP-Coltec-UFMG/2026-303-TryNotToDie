extends Control

const CENA_MENU := "res://cenas/menu.tscn";
const FRACAO_TOPO := 0.14;
const FRACAO_BASE := 0.22;

const ROTEIRO_PADRAO := """# TRY NOT TO DIE

## DESENVOLVIMENTO
PROGRAMACAO | Bernardo Drummond Oliveira Penna
ARTE E PIXEL ART | Verônica Fernandes Silva
ARTE E PIXEL ART | Júlia Cruz Menezes
ARTE E PIXEL ART | Ítalo Gomes Bragança
ARTE E PIXEL ART | Felipe Soares Palhares
GAME DESIGN | Felipe Soares Palhares
LEVEL DESIGN | Felipe Soares Palhares
ROTEIRO | Felipe Soares Palhares

## MUSICA
MUSIC FROM FREE TO USE
> SOURCE: https://freetouse.com/music

ENLIVENING BY PUFINO
> TEMA DO MENU E DOS CREDITOS

WANDERER AT NIGHT BY ZAMBOLINO
> TEMA DO JOGO

## EFEITOS SONOROS
Bell Ring | [DRAGON-STUDIO / https://pixabay.com/]

## ARTE DE TERCEIROS
PORTA | [Pipoya (@pipohi) / https://pipoya.itch.io/pipoya-rpg-tileset-32x32/devlog/222435/add-door-animation]
PILHAS DE PEDRA | [karsiori / https://karsiori.itch.io/pixel-art-rock-pile-pack]

## FONTE TIPOGRAFICA
ARCADE N | YUJI ADACHI

## FEITO COM
GODOT ENGINE
> godotengine.org/license

## AGRADECIMENTOS
A TODOS QUE TESTARAM O JOGO
E A VOCE, QUE CHEGOU ATE AQUI

---

OBRIGADO POR JOGAR!
""";

@export var fonte: Font;
@export var velocidade: float = 55.0;
@export var aceleracao: float = 5.0;
@export var espera_no_final: float = 3.5;
@export var segundos_por_pagina: float = 4.5;
@export var largura_maxima: float = 980.0;
@export_file("*.tscn") var cena_ao_terminar: String = CENA_MENU;

@export_group("Cores")
@export var cor_fundo: Color = Color(0.02, 0.02, 0.04);
@export var cor_titulo: Color = Color(1.0, 0.8, 0.5);
@export var cor_secao: Color = Color(1.0, 0.66, 0.36);
@export var cor_papel: Color = Color(1.0, 1.0, 1.0, 0.6);
@export var cor_texto: Color = Color(1.0, 1.0, 1.0);
@export var cor_nota: Color = Color(1.0, 1.0, 1.0, 0.45);

@export_multiline var roteiro: String = ROTEIRO_PADRAO;

var _fundo: ColorRect;
var _rolo: VBoxContainer;
var _degrade_topo: TextureRect;
var _degrade_base: TextureRect;
var _dica: Label;
var _ultimo: Control = null;
var _rolando: bool = false;
var _terminando: bool = false;
var _espera: float = 0.0;


func _ready() -> void:
	_montar_ui();
	_construir_roteiro();
	resized.connect(_ajustar_layout);
	_ajustar_layout();
	_rolo.position.y = _altura_tela();

	await get_tree().process_frame;
	await get_tree().process_frame;
	_ajustar_layout();
	_rolando = true;


func _process(delta: float) -> void:
	if not _rolando or _ultimo == null:
		return;

	var fator := aceleracao if Input.is_anything_pressed() else 1.0;

	if _sem_animacao():
		_espera -= delta * fator;
		if _espera <= 0.0:
			_espera = segundos_por_pagina;
			_virar_pagina();
		return;

	_rolo.position.y -= velocidade * fator * delta;
	var alvo := _alvo_final();
	if _rolo.position.y <= alvo:
		_rolo.position.y = alvo;
		_encerrar(espera_no_final);


func _unhandled_input(evento: InputEvent) -> void:
	if _terminando:
		return;
	if InputMap.has_action("Pause") and evento.is_action_pressed("Pause"):
		get_viewport().set_input_as_handled();
		_encerrar(0.0);


func _virar_pagina() -> void:
	var altura := _altura_tela();
	var topo := altura * FRACAO_TOPO;
	var limite := altura * (1.0 - FRACAO_BASE);
	var alvo := _alvo_final();
	var itens := _itens();

	for i in itens.size():
		var item := itens[i];
		if _rolo.position.y + item.position.y + item.size.y <= limite:
			continue;
		if item == _ultimo:
			break;

		var novo_y := topo - item.position.y;
		if i > 0 and itens[i - 1].has_meta("cabecalho"):
			var com_cabecalho := topo - itens[i - 1].position.y;
			if com_cabecalho < _rolo.position.y - 1.0:
				novo_y = com_cabecalho;

		if novo_y >= _rolo.position.y - 1.0:
			continue;
		if novo_y <= alvo:
			break;
		_rolo.position.y = novo_y;
		return;

	_rolo.position.y = alvo;
	_encerrar(espera_no_final);


func _itens() -> Array[Control]:
	var lista: Array[Control] = [];
	for filho in _rolo.get_children():
		var item := filho as Control;
		if item != null and not item.has_meta("espaco"):
			lista.append(item);
	return lista;


func _encerrar(espera: float) -> void:
	if _terminando:
		return;
	_terminando = true;
	_rolando = false;
	if espera > 0.0:
		await get_tree().create_timer(espera).timeout;
	Transicao.trocar_cena(cena_ao_terminar);


func _alvo_final() -> float:
	if _ultimo == null:
		return 0.0;
	return _altura_tela() * 0.5 - (_ultimo.position.y + _ultimo.size.y * 0.5);


func _montar_ui() -> void:
	_fundo = ColorRect.new();
	_fundo.name = "Fundo";
	_fundo.color = cor_fundo;
	_fundo.mouse_filter = Control.MOUSE_FILTER_IGNORE;
	_fundo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);
	add_child(_fundo);

	_rolo = VBoxContainer.new();
	_rolo.name = "Rolo";
	_rolo.mouse_filter = Control.MOUSE_FILTER_IGNORE;
	_rolo.add_theme_constant_override("separation", roundi(_base() * 0.45));
	add_child(_rolo);

	_degrade_topo = _degrade(true);
	_degrade_topo.name = "DegradeTopo";
	add_child(_degrade_topo);
	_degrade_topo.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE);

	_degrade_base = _degrade(false);
	_degrade_base.name = "DegradeBase";
	add_child(_degrade_base);
	_degrade_base.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE);

	_dica = _rotulo(_texto_da_dica(), _tamanho(0.6), Color(1.0, 1.0, 1.0, 0.35), HORIZONTAL_ALIGNMENT_RIGHT);
	_dica.name = "Dica";
	_dica.autowrap_mode = TextServer.AUTOWRAP_OFF;
	add_child(_dica);
	_dica.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT, Control.PRESET_MODE_MINSIZE, 20);
	_dica.grow_horizontal = Control.GROW_DIRECTION_BEGIN;
	_dica.grow_vertical = Control.GROW_DIRECTION_BEGIN;


func _construir_roteiro() -> void:
	_ultimo = null;

	for bruta in roteiro.split("\n"):
		var linha := bruta.strip_edges();

		if linha.is_empty():
			_espaco(_base() * 1.5);
		elif linha == "---":
			_espaco(_altura_tela() * 0.6);
		elif linha.begins_with("##"):
			_adicionar(_rotulo(linha.substr(2).strip_edges(), _tamanho(1.18), cor_secao, HORIZONTAL_ALIGNMENT_CENTER), true);
		elif linha.begins_with("#"):
			_adicionar(_rotulo(linha.substr(1).strip_edges(), _tamanho(2.0), cor_titulo, HORIZONTAL_ALIGNMENT_CENTER), true);
		elif linha.begins_with(">"):
			_adicionar(_rotulo(linha.substr(1).strip_edges(), _tamanho(0.72), cor_nota, HORIZONTAL_ALIGNMENT_CENTER));
		elif linha.contains("|"):
			var partes := linha.split("|", true, 1);
			_adicionar(_dupla(partes[0].strip_edges(), partes[1].strip_edges()));
		else:
			_adicionar(_rotulo(linha, _tamanho(1.0), cor_texto, HORIZONTAL_ALIGNMENT_CENTER));


func _adicionar(item: Control, cabecalho: bool = false) -> void:
	if cabecalho:
		item.set_meta("cabecalho", true);
	_rolo.add_child(item);
	_ultimo = item;


func _espaco(altura: float) -> void:
	var vazio := Control.new();
	vazio.mouse_filter = Control.MOUSE_FILTER_IGNORE;
	vazio.custom_minimum_size = Vector2(0.0, altura);
	vazio.set_meta("espaco", true);
	_rolo.add_child(vazio);


func _dupla(papel: String, nome: String) -> Control:
	var linha := HBoxContainer.new();
	linha.mouse_filter = Control.MOUSE_FILTER_IGNORE;
	linha.add_theme_constant_override("separation", roundi(_base() * 1.2));

	var esquerda := _rotulo(papel, _tamanho(0.82), cor_papel, HORIZONTAL_ALIGNMENT_RIGHT);
	var direita := _rotulo(nome, _tamanho(1.0), cor_texto, HORIZONTAL_ALIGNMENT_LEFT);

	for rotulo in [esquerda, direita]:
		rotulo.size_flags_horizontal = Control.SIZE_EXPAND_FILL;
		rotulo.vertical_alignment = VERTICAL_ALIGNMENT_CENTER;
		linha.add_child(rotulo);

	return linha;


func _rotulo(texto: String, tamanho: int, cor: Color, alinhamento: HorizontalAlignment) -> Label:
	var rotulo := Label.new();
	rotulo.text = texto;
	rotulo.horizontal_alignment = alinhamento;
	rotulo.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART;
	rotulo.mouse_filter = Control.MOUSE_FILTER_IGNORE;
	if fonte != null:
		rotulo.add_theme_font_override("font", fonte);
	rotulo.add_theme_font_size_override("font_size", tamanho);
	rotulo.add_theme_color_override("font_color", cor);
	return rotulo;


func _degrade(no_topo: bool) -> TextureRect:
	var opaco := cor_fundo;
	var transparente := Color(cor_fundo, 0.0);

	var gradiente := Gradient.new();
	if no_topo:
		gradiente.offsets = PackedFloat32Array([0.0, 0.35, 1.0]);
		gradiente.colors = PackedColorArray([opaco, opaco, transparente]);
	else:
		gradiente.offsets = PackedFloat32Array([0.0, 0.55, 1.0]);
		gradiente.colors = PackedColorArray([transparente, opaco, opaco]);

	var textura := GradientTexture2D.new();
	textura.gradient = gradiente;
	textura.width = 4;
	textura.height = 128;
	textura.fill_from = Vector2(0.0, 0.0);
	textura.fill_to = Vector2(0.0, 1.0);

	var faixa := TextureRect.new();
	faixa.texture = textura;
	faixa.expand_mode = TextureRect.EXPAND_IGNORE_SIZE;
	faixa.stretch_mode = TextureRect.STRETCH_SCALE;
	faixa.mouse_filter = Control.MOUSE_FILTER_IGNORE;
	return faixa;


func _ajustar_layout() -> void:
	if _rolo == null:
		return;
	var tela := get_viewport_rect().size;
	var largura := minf(largura_maxima, tela.x - 64.0);
	_rolo.custom_minimum_size = Vector2(largura, 0.0);
	_rolo.reset_size();
	_rolo.position.x = (tela.x - largura) * 0.5;

	_degrade_topo.offset_left = 0.0;
	_degrade_topo.offset_right = 0.0;
	_degrade_topo.offset_top = 0.0;
	_degrade_topo.offset_bottom = tela.y * FRACAO_TOPO;

	_degrade_base.offset_left = 0.0;
	_degrade_base.offset_right = 0.0;
	_degrade_base.offset_top = -tela.y * FRACAO_BASE;
	_degrade_base.offset_bottom = 0.0;


func _texto_da_dica() -> String:
	var tecla := "ESC";
	if Configuracoes.binds.has("Pause"):
		var texto := Configuracoes.texto_da_tecla(Configuracoes.binds["Pause"]);
		if not texto.is_empty():
			tecla = texto.to_upper();
	return "SEGURE UMA TECLA PARA ACELERAR\n%s PARA PULAR" % tecla;


func _altura_tela() -> float:
	return get_viewport_rect().size.y;


func _base() -> int:
	return Configuracoes.tamanho_fonte;


func _tamanho(escala: float) -> int:
	return maxi(10, roundi(_base() * escala));


func _sem_animacao() -> bool:
	return Configuracoes.config_ativa(Configuracoes.REMOVER_ANIMACAO);
