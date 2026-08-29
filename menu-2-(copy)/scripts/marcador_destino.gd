class_name MarcadorDestino
extends Node2D

@export var cor: Color = Color(1.0, 0.95, 0.6, 0.9);
@export var raio_inicial: float = 10.0;
@export var raio_final: float = 44.0;
@export var duracao: float = 0.55;

var _raio: float = 0.0;
var _alfa: float = 1.0;


static func criar(onde_global: Vector2) -> MarcadorDestino:
	var m := MarcadorDestino.new();
	m.global_position = onde_global;
	return m;


func _ready() -> void:
	z_index = 40;
	z_as_relative = false;
	_raio = raio_inicial;

	if Configuracoes.config_ativa(Configuracoes.REMOVER_ANIMACAO):
		_raio = raio_final * 0.6;
		queue_redraw();
		await get_tree().create_timer(0.5).timeout;
		queue_free();
		return;

	var tween := create_tween().set_parallel();
	tween.tween_method(_definir_raio, raio_inicial, raio_final, duracao)\
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT);
	tween.tween_method(_definir_alfa, 1.0, 0.0, duracao);
	await tween.finished;
	queue_free();


func _definir_raio(valor: float) -> void:
	_raio = valor;
	queue_redraw();


func _definir_alfa(valor: float) -> void:
	_alfa = valor;
	queue_redraw();


func _draw() -> void:
	var c := cor;
	c.a = cor.a * _alfa;
	draw_arc(Vector2.ZERO, _raio, 0.0, TAU, 32, c, 3.0, true);
	draw_arc(Vector2.ZERO, _raio * 0.45, 0.0, TAU, 24, c, 2.0, true);
