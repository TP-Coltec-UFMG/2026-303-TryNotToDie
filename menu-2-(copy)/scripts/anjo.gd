class_name Anjo
extends Node2D

enum Modo { VOO, SO_SOM, COMPANHIA };

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

@export_group("Companhia")
@export_range(0.0, 1.0) var alfa_companhia: float = 0.45;
@export var entrada_da_companhia: float = 0.55;
@export var saida_da_companhia: float = 0.45;
@export var descida_ao_chegar: float = 46.0;
@export var balanco_parado: float = 14.0;
@export var periodo_do_balanco: float = 2.4;

@export_group("Som")
@export var caminho_do_som: String = "res://sons/bell.mp3";
@export var forca_do_lado: float = 2.0;
@export var alcance_do_som: float = 4000.0;

var modo: Modo = Modo.VOO;
var direcao: float = 1.0;
var quadros: SpriteFrames = null;
var toca_sino: bool = true;

static var _cena: PackedScene = null;
static var _atual: Anjo = null;

var _comecou: bool = false;
var _saindo: bool = false;
var _fim_do_som: float = 0.0;
var _centro: Vector2 = Vector2.ZERO;
var _tempo: float = 0.0;
var _entrada: Tween = null;


static func _pegar_cena() -> PackedScene:
	if _cena == null or not is_instance_valid(_cena):
		_cena = load("res://cenas/anjo.tscn") as PackedScene;
	return _cena;


static func _nascer(pai: Node, onde: Vector2, jeito: Modo, rumo: float) -> Anjo:
	if pai == null or not is_instance_valid(pai):
		return null;

	var cena := _pegar_cena();
	if cena == null:
		return null;

	var anjo := cena.instantiate() as Anjo;
	if anjo == null:
		return null;

	anjo.modo = jeito;
	anjo.direcao = -1.0 if rumo < 0.0 else 1.0;

	pai.add_child(anjo);
	anjo.global_position = onde;

	return anjo;


static func aparecer(pai: Node, onde: Vector2, rumo: float) -> Anjo:
	if is_instance_valid(_atual):
		_atual.queue_free();
	_atual = null;

	var anjo := _nascer(pai, onde, Modo.VOO, rumo);
	_atual = anjo;
	return anjo;


static func tocar_sino(pai: Node, onde: Vector2) -> Anjo:
	return _nascer(pai, onde, Modo.SO_SOM, 1.0);


static func acompanhar(pai: Node, onde: Vector2, rumo: float,
		quais_quadros: SpriteFrames = null, qual_animacao: String = "",
		com_sino: bool = true) -> Anjo:
	var cena := _pegar_cena();
	if cena == null or pai == null or not is_instance_valid(pai):
		return null;

	var anjo := cena.instantiate() as Anjo;
	if anjo == null:
		return null;

	anjo.modo = Modo.COMPANHIA;
	anjo.direcao = -1.0 if rumo < 0.0 else 1.0;
	anjo.quadros = quais_quadros;
	anjo.toca_sino = com_sino;
	if qual_animacao != "":
		anjo.animacao = qual_animacao;

	pai.add_child(anjo);
	anjo.global_position = onde;

	return anjo;


func _ready() -> void:
	z_index = 60;
	z_as_relative = false;
	set_process(false);

	if sprite == null or not is_instance_valid(sprite):
		sprite = _achar_sprite();
	if som == null or not is_instance_valid(som):
		som = _achar_som();

	if som != null and is_instance_valid(som):
		som.bus = Configuracoes.BUS_SONS;

	modulate.a = 0.0;
	if sprite != null and is_instance_valid(sprite):
		sprite.visible = false;

	_comecar.call_deferred();


func _process(delta: float) -> void:
	if _saindo or _sem_animacao():
		return;
	_tempo += delta;
	position.y = _centro.y + sin(_tempo * TAU / maxf(0.1, periodo_do_balanco)) * balanco_parado;


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

	match modo:
		Modo.SO_SOM:
			await _rodar_so_o_som();
		Modo.COMPANHIA:
			await _rodar_companhia();
		_:
			await _rodar_voo();


func _rodar_so_o_som() -> void:
	_tocar();
	await _esperar_o_som();
	queue_free();


func _rodar_companhia() -> void:
	_preparar_sprite();
	_tocar();

	_centro = position;

	if _sem_animacao():
		modulate.a = alfa_companhia;
		return;

	position = _centro - Vector2(0.0, descida_ao_chegar);

	_entrada = create_tween().set_parallel();
	_entrada.tween_property(self, "position", _centro, entrada_da_companhia)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT);
	_entrada.tween_property(self, "modulate:a", alfa_companhia, entrada_da_companhia);
	await _entrada.finished;

	if not is_instance_valid(self) or _saindo:
		return;

	_entrada = null;
	set_process(true);


func despedir() -> void:
	if _saindo:
		return;
	_saindo = true;
	set_process(false);

	if _entrada != null and _entrada.is_valid():
		_entrada.kill();
	_entrada = null;

	if _sem_animacao() or not _comecou:
		queue_free();
		return;

	var saida := create_tween().set_parallel();
	saida.tween_property(self, "modulate:a", 0.0, saida_da_companhia);
	saida.tween_property(self, "position:y", position.y - descida_ao_chegar,
		saida_da_companhia).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN);
	await saida.finished;

	queue_free();


func _rodar_voo() -> void:
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

	_centro = position;
	position = _centro - Vector2(direcao * distancia_entrada, 0.0);

	var entrada := create_tween().set_parallel();
	entrada.tween_property(self, "position", _centro, duracao_entrada)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT);
	entrada.tween_property(self, "modulate:a", alfa, duracao_entrada);
	await entrada.finished;
	if not is_instance_valid(self):
		return;

	var flutuo := create_tween();
	flutuo.tween_property(self, "position:y", _centro.y - balanco, duracao_parado * 0.5)\
		.set_trans(Tween.TRANS_SINE);
	flutuo.tween_property(self, "position:y", _centro.y, duracao_parado * 0.5)\
		.set_trans(Tween.TRANS_SINE);
	await flutuo.finished;
	if not is_instance_valid(self):
		return;

	var saida := create_tween().set_parallel();
	saida.tween_property(self, "position",
		_centro + Vector2(direcao * distancia_saida, -subida_ao_sair), duracao_saida)\
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

	if quadros != null:
		sprite.sprite_frames = quadros;

	sprite.visible = true;
	sprite.flip_h = direcao < 0.0;
	sprite.speed_scale = maxf(0.05, escala_animacao);

	var nome := _animacao_valida();
	if nome != "":
		if sprite.animation != nome:
			sprite.animation = nome;
		sprite.frame = 0;

	if _sem_animacao():
		sprite.stop();
	else:
		sprite.play();


func _animacao_valida() -> String:
	if sprite.sprite_frames == null:
		return "";
	if sprite.sprite_frames.has_animation(animacao):
		return animacao;

	var lista := sprite.sprite_frames.get_animation_names();
	if lista.size() > 0:
		return lista[0];
	return "";


func _tocar() -> void:
	if not toca_sino:
		return;
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
