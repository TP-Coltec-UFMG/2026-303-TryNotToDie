class_name Anjo
extends Node2D

@export var sprite: AnimatedSprite2D;
@export var som: AudioStreamPlayer2D;

@export_group("Fantasma")
@export_range(0.0, 1.0) var alfa: float = 0.28;
@export var animacao: String = "sino";
@export var escala_animacao: float = 1.0;

@export_group("Voo")
@export var distancia_entrada: float = 210.0;
@export var distancia_saida: float = 240.0;
@export var subida_ao_sair: float = 90.0;
@export var balanco: float = 12.0;
@export var duracao_entrada: float = 0.34;
@export var duracao_parado: float = 0.46;
@export var duracao_saida: float = 0.62;
@export var duracao_sem_animacao: float = 0.5;

@export_group("Som")
@export var caminho_do_som: String = "res://sons/bell.mp3";
@export var forca_do_lado: float = 2.0;
@export var alcance_do_som: float = 4000.0;

var so_o_som: bool = false;
var direcao: float = 1.0;

static var _cena: PackedScene = null;
static var _atual: Anjo = null;

var _comecou: bool = false;
var _fim_do_som: float = 0.0;


static func _pegar_cena() -> PackedScene:
	if _cena == null or not is_instance_valid(_cena):
		_cena = load("res://cenas/anjo.tscn") as PackedScene;
	return _cena;


static func _nascer(pai: Node, onde: Vector2, so_som: bool, rumo: float) -> Anjo:
	if pai == null or not is_instance_valid(pai):
		return null;

	var cena := _pegar_cena();
	if cena == null:
		return null;

	var anjo := cena.instantiate() as Anjo;
	if anjo == null:
		return null;

	anjo.so_o_som = so_som;
	anjo.direcao = -1.0 if rumo < 0.0 else 1.0;

	pai.add_child(anjo);
	anjo.global_position = onde;

	return anjo;


static func aparecer(pai: Node, onde: Vector2, rumo: float) -> Anjo:
	if is_instance_valid(_atual):
		_atual.queue_free();
	_atual = null;

	var anjo := _nascer(pai, onde, false, rumo);
	_atual = anjo;
	return anjo;


static func tocar_sino(pai: Node, onde: Vector2) -> Anjo:
	return _nascer(pai, onde, true, 1.0);


func _ready() -> void:
	z_index = 60;
	z_as_relative = false;

	if sprite == null or not is_instance_valid(sprite):
		sprite = _achar_sprite();
	if som == null or not is_instance_valid(som):
		som = _achar_som();

	modulate.a = 0.0;
	if sprite != null and is_instance_valid(sprite):
		sprite.visible = false;

	_comecar.call_deferred();


func _achar_sprite() -> AnimatedSprite2D:
	for filho in get_children():
		if filho is AnimatedSprite2D:
			return filho;
	return null;


func _achar_som() -> AudioStreamPlayer2D:
	for filho in get_children():
		if filho is AudioStreamPlayer2D:
			return filho;

	var novo := AudioStreamPlayer2D.new();
	novo.name = "Sino";
	novo.panning_strength = forca_do_lado;
	novo.max_distance = alcance_do_som;
	add_child(novo);
	return novo;


func _comecar() -> void:
	if _comecou:
		return;
	_comecou = true;

	if so_o_som:
		_tocar();
		await _esperar_o_som();
		queue_free();
		return;

	_preparar_sprite();
	_tocar();

	if _sem_animacao():
		modulate.a = alfa;
		await get_tree().create_timer(duracao_sem_animacao).timeout;
		if not is_instance_valid(self):
			return;
		await _esperar_o_som();
		queue_free();
		return;

	var centro := position;

	position = centro - Vector2(direcao * distancia_entrada, 0.0);

	var entrada := create_tween().set_parallel();
	entrada.tween_property(self, "position", centro, duracao_entrada)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT);
	entrada.tween_property(self, "modulate:a", alfa, duracao_entrada);
	await entrada.finished;
	if not is_instance_valid(self):
		return;

	var flutuo := create_tween();
	flutuo.tween_property(self, "position:y", centro.y - balanco, duracao_parado * 0.5)\
		.set_trans(Tween.TRANS_SINE);
	flutuo.tween_property(self, "position:y", centro.y, duracao_parado * 0.5)\
		.set_trans(Tween.TRANS_SINE);
	await flutuo.finished;
	if not is_instance_valid(self):
		return;

	var saida := create_tween().set_parallel();
	saida.tween_property(self, "position",
		centro + Vector2(direcao * distancia_saida, -subida_ao_sair), duracao_saida)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN);
	saida.tween_property(self, "modulate:a", 0.0, duracao_saida);
	await saida.finished;
	if not is_instance_valid(self):
		return;

	await _esperar_o_som();
	queue_free();


func _preparar_sprite() -> void:
	if sprite == null or not is_instance_valid(sprite):
		return;

	sprite.visible = true;
	sprite.flip_h = direcao < 0.0;
	sprite.speed_scale = maxf(0.05, escala_animacao);

	if sprite.sprite_frames != null and sprite.sprite_frames.has_animation(animacao):
		if sprite.animation != animacao:
			sprite.animation = animacao;
		sprite.frame = 0;

	if _sem_animacao():
		sprite.stop();
	else:
		sprite.play();


func _tocar() -> void:
	if som == null or not is_instance_valid(som):
		return;

	if som.stream == null and caminho_do_som != "":
		som.stream = load(caminho_do_som) as AudioStream;

	if som.stream == null:
		return;

	var duracao := som.stream.get_length();
	if duracao <= 0.0:
		duracao = 2.0;

	_fim_do_som = _agora() + duracao;
	som.play();


func _esperar_o_som() -> void:
	var falta := _fim_do_som - _agora();
	if falta <= 0.0:
		return;
	await get_tree().create_timer(falta).timeout;


func _agora() -> float:
	return float(Time.get_ticks_msec()) / 1000.0;


func _sem_animacao() -> bool:
	return Configuracoes.config_ativa(Configuracoes.REMOVER_ANIMACAO);
