class_name DicaFlutuante
extends Node2D

@export var texto: String = "";
@export var deslocamento: Vector2 = Vector2(0.0, -120.0);
@export var largura: float = 460.0;

var _rotulo: Label;
var _tween: Tween;


func _ready() -> void:
	z_index = 50;
	z_as_relative = false;

	_rotulo = Label.new();
	_rotulo.text = texto;
	_rotulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER;
	_rotulo.vertical_alignment = VERTICAL_ALIGNMENT_CENTER;
	_rotulo.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART;
	_rotulo.custom_minimum_size = Vector2(largura, 0.0);
	_rotulo.size = Vector2(largura, 70.0);
	_rotulo.position = deslocamento - Vector2(largura * 0.5, 35.0);
	_rotulo.mouse_filter = Control.MOUSE_FILTER_IGNORE;
	_rotulo.add_theme_color_override("font_color", Color(1, 1, 1));
	_rotulo.add_theme_color_override("font_outline_color", Color(0, 0, 0));
	_rotulo.add_theme_constant_override("outline_size", 10);
	_rotulo.modulate.a = 0.0;
	add_child(_rotulo);


static func criar(qual_texto: String, onde: Vector2 = Vector2(0.0, -120.0)) -> DicaFlutuante:
	var dica := DicaFlutuante.new();
	dica.texto = qual_texto;
	dica.deslocamento = onde;
	return dica;


func definir_texto(novo: String) -> void:
	texto = novo;
	if _rotulo != null:
		_rotulo.text = novo;


func mostrar(ligado: bool) -> void:
	if _rotulo == null:
		return;

	var alvo := 1.0 if ligado else 0.0;

	if Configuracoes.config_ativa(Configuracoes.REMOVER_ANIMACAO):
		_rotulo.modulate.a = alvo;
		return;

	if _tween != null and _tween.is_valid():
		_tween.kill();
	_tween = create_tween();
	_tween.tween_property(_rotulo, "modulate:a", alvo, 0.18);
