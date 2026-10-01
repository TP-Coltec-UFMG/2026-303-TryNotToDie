class_name AnjoAjudante
extends Node2D

enum Modo { CORTAR, PROTETOR, PEGAR };

signal terminou;

@export var visual: Node2D;
@export var mao: Node2D;
@export var facao: Node2D;
@export var protetor: Node2D;
@export_range(0.0, 1.0) var alfa: float = 0.35;

@export_group("Cortar")
@export var desvio_do_mouse: Vector2 = Vector2(-40.0, -46.0);
@export var suavidade: float = 18.0;
@export var angulo_de_descanso: float = -40.0;
@export var abertura_do_golpe: float = 55.0;
@export var ritmo_do_golpe: float = 22.0;
@export var entrada: float = 0.12;
@export var saida: float = 0.25;

@export_group("Protetor")
@export var duracao_passagem: float = 0.6;
@export var comeco_relativo: Vector2 = Vector2(-250.0, -100.0);
@export var meio_relativo: Vector2 = Vector2(0.0, -62.0);
@export var fim_relativo: Vector2 = Vector2(250.0, -115.0);
@export var angulo_do_protetor: float = 170.0;
@export var cor_do_creme: Color = Color(1.0, 0.95, 0.72, 1.0);

@export_group("Pegar")
@export var duracao_pega: float = 0.65;
@export var entrada_da_pega: Vector2 = Vector2(-280.0, 40.0);
@export var saida_da_pega: Vector2 = Vector2(320.0, -190.0);
@export var angulo_alcancando: float = -60.0;
@export var angulo_segurando: float = -135.0;
@export var escala_na_mao: float = 0.6;
@export var caminho_do_sino: String = "res://sons/bell.mp3";

var modo: Modo = Modo.CORTAR;
var alvo: Node2D = null;

static var _cena: PackedScene = null;
static var _cortador: AnjoAjudante = null;

var _saindo: bool = false;
var _tempo: float = 0.0;
var _mouse_anterior: Vector2 = Vector2.ZERO;
var _velocidade_mouse: float = 0.0;
var _lado: float = 1.0;
var _gotas: CPUParticles2D = null;
var _objeto: Node2D = null;
var _pega_local: Vector2 = Vector2.ZERO;
var _ao_pegar: Callable = Callable();
var _ponto_da_pega: Vector2 = Vector2.ZERO;
var _controle: Vector2 = Vector2.ZERO;
var _comeco: Vector2 = Vector2.ZERO;
var _fim: Vector2 = Vector2.ZERO;
var _pegou: bool = false;
var _relativo_inicial: Transform2D = Transform2D.IDENTITY;


static func _pegar_cena() -> PackedScene:
	if _cena == null:
		_cena = load("res://cenas/anjo_ajudante.tscn") as PackedScene;
	return _cena;


static func cortar(pai: Node) -> AnjoAjudante:
	if is_instance_valid(_cortador) and not _cortador._saindo:
		return _cortador;
	if pai == null or not is_instance_valid(pai):
		return null;
	var cena := _pegar_cena();
	if cena == null:
		return null;
	var anjo := cena.instantiate() as AnjoAjudante;
	if anjo == null:
		return null;
	anjo.modo = Modo.CORTAR;
	pai.add_child(anjo);
	_cortador = anjo;
	return anjo;


static func passar_protetor(pai: Node, quem: Node2D) -> AnjoAjudante:
	if pai == null or not is_instance_valid(pai) or quem == null or not is_instance_valid(quem):
		return null;
	var cena := _pegar_cena();
	if cena == null:
		return null;
	var anjo := cena.instantiate() as AnjoAjudante;
	if anjo == null:
		return null;
	anjo.modo = Modo.PROTETOR;
	anjo.alvo = quem;
	pai.add_child(anjo);
	return anjo;


static func pegar_no_ar(pai: Node, objeto: Node2D, pega_local: Vector2, ao_pegar: Callable = Callable()) -> AnjoAjudante:
	if pai == null or not is_instance_valid(pai) or objeto == null or not is_instance_valid(objeto):
		return null;
	var cena := _pegar_cena();
	if cena == null:
		return null;
	var anjo := cena.instantiate() as AnjoAjudante;
	if anjo == null:
		return null;
	anjo.modo = Modo.PEGAR;
	anjo._objeto = objeto;
	anjo._pega_local = pega_local;
	anjo._ao_pegar = ao_pegar;
	pai.add_child(anjo);
	return anjo;


func _ready() -> void:
	z_index = 4096;
	z_as_relative = false;
	modulate.a = 0.0;

	if facao != null:
		facao.visible = modo == Modo.CORTAR;
	if protetor != null:
		protetor.visible = modo == Modo.PROTETOR;

	match modo:
		Modo.CORTAR:
			_comecar_corte();
		Modo.PROTETOR:
			_comecar_protetor();
		Modo.PEGAR:
			_comecar_pega();


func _comecar_corte() -> void:
	_mouse_anterior = get_global_mouse_position();
	global_position = _mouse_anterior + desvio_do_mouse;
	if mao != null:
		mao.rotation_degrees = angulo_de_descanso;

	if _sem_animacao():
		modulate.a = alfa;
		return;
	create_tween().tween_property(self, "modulate:a", alfa, entrada);


func _process(delta: float) -> void:
	if modo == Modo.CORTAR:
		_seguir_mouse(delta);


func _seguir_mouse(delta: float) -> void:
	if _saindo:
		return;

	if not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		soltar();
		return;

	var mouse := get_global_mouse_position();
	var movimento := mouse - _mouse_anterior;
	_mouse_anterior = mouse;

	if _sem_animacao():
		global_position = mouse + desvio_do_mouse;
		return;

	var rapidez := movimento.length() / maxf(0.0001, delta);
	_velocidade_mouse = lerpf(_velocidade_mouse, rapidez, clampf(delta * 12.0, 0.0, 1.0));
	if absf(movimento.x) > 0.5:
		_lado = signf(movimento.x);

	var alvo_pos := mouse + Vector2(desvio_do_mouse.x * _lado, desvio_do_mouse.y);
	global_position = global_position.lerp(alvo_pos, clampf(delta * suavidade, 0.0, 1.0));

	if visual != null:
		visual.scale.x = move_toward(visual.scale.x, _lado, delta * 10.0);

	_tempo += delta;
	var forca := clampf(_velocidade_mouse / 900.0, 0.0, 1.0);
	if mao != null:
		mao.rotation_degrees = angulo_de_descanso - abertura_do_golpe * forca * (0.5 + 0.5 * sin(_tempo * ritmo_do_golpe));


func soltar() -> void:
	if _saindo:
		return;
	_saindo = true;
	if _cortador == self:
		_cortador = null;

	if _sem_animacao():
		queue_free();
		return;

	var tween := create_tween().set_parallel();
	tween.tween_property(self, "modulate:a", 0.0, saida);
	tween.tween_property(self, "global_position:y", global_position.y - 30.0, saida)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN);
	tween.chain().tween_callback(queue_free);


func _comecar_protetor() -> void:
	if mao != null:
		mao.rotation_degrees = angulo_do_protetor;
	if visual != null:
		visual.scale.x = 1.0;

	if _sem_animacao():
		_posicionar(0.5);
		modulate.a = alfa;
		var espera := create_tween();
		espera.tween_interval(0.5);
		espera.tween_callback(_acabar);
		return;

	_posicionar(0.0);
	_gotas = _criar_gotas();

	var tween := create_tween();
	tween.tween_method(_passo_da_passagem, 0.0, 1.0, maxf(0.1, duracao_passagem))\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT);
	tween.tween_callback(_acabar);


func _acabar() -> void:
	if _gotas != null and is_instance_valid(_gotas):
		_gotas.emitting = false;
		var gotas := _gotas;
		get_tree().create_timer(gotas.lifetime + 0.1).timeout.connect(gotas.queue_free);
	_gotas = null;
	terminou.emit();
	queue_free();


func _passo_da_passagem(t: float) -> void:
	_posicionar(t);

	var aparecer := clampf(t / 0.15, 0.0, 1.0);
	var sumir := clampf((1.0 - t) / 0.2, 0.0, 1.0);
	modulate.a = alfa * minf(aparecer, sumir);

	if mao != null:
		mao.rotation_degrees = angulo_do_protetor + sin(t * TAU * 3.0) * 14.0;

	if _gotas != null and is_instance_valid(_gotas) and mao != null:
		_gotas.global_position = mao.to_global(Vector2(0.0, -20.0));
		_gotas.global_rotation = mao.global_rotation;
		_gotas.emitting = t > 0.3 and t < 0.72;


func _posicionar(t: float) -> void:
	var base := global_position;
	if alvo != null and is_instance_valid(alvo):
		base = alvo.global_position;
	var a := comeco_relativo.lerp(meio_relativo, t);
	var b := meio_relativo.lerp(fim_relativo, t);
	global_position = base + a.lerp(b, t);


func _criar_gotas() -> CPUParticles2D:
	if mao == null:
		return null;
	var p := CPUParticles2D.new();
	p.z_index = 4096;
	p.z_as_relative = false;
	p.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST;
	p.amount = 30;
	p.lifetime = 0.45;
	p.local_coords = false;
	p.emitting = false;
	p.direction = Vector2.UP;
	p.spread = 22.0;
	p.gravity = Vector2(0.0, 900.0);
	p.initial_velocity_min = 120.0;
	p.initial_velocity_max = 260.0;
	p.scale_amount_min = 4.0;
	p.scale_amount_max = 7.0;
	p.color = cor_do_creme;
	var sumico := Gradient.new();
	sumico.offsets = PackedFloat32Array([0.0, 0.75, 1.0]);
	sumico.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 1), Color(1, 1, 1, 0)]);
	p.color_ramp = sumico;
	var pai := get_parent() if get_parent() != null else self;
	pai.add_child(p);
	p.global_position = mao.to_global(Vector2(0.0, -20.0));
	p.global_rotation = mao.global_rotation;
	return p;


func _comecar_pega() -> void:
	if visual != null:
		visual.scale.x = 1.0;
	if mao != null:
		mao.rotation_degrees = angulo_alcancando;
	_tocar_sino();

	var mao_local := mao.position if mao != null else Vector2.ZERO;
	_ponto_da_pega = _objeto.global_transform * _pega_local - mao_local;
	_comeco = _ponto_da_pega + entrada_da_pega;
	_fim = _ponto_da_pega + saida_da_pega;
	_controle = 2.0 * _ponto_da_pega - 0.5 * (_comeco + _fim);

	if _sem_animacao():
		global_position = _ponto_da_pega;
		modulate.a = alfa;
		_pegar();
		if is_instance_valid(_objeto):
			_objeto.queue_free();
		var espera := create_tween();
		espera.tween_interval(0.5);
		espera.tween_callback(_acabar);
		return;

	global_position = _comeco;
	var tween := create_tween();
	tween.tween_method(_passo_da_pega, 0.0, 1.0, maxf(0.1, duracao_pega))\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT);
	tween.tween_callback(_soltar_o_objeto);
	tween.tween_callback(_acabar);


func _passo_da_pega(t: float) -> void:
	if not _pegou and _objeto != null and is_instance_valid(_objeto):
		var mao_local := mao.position if mao != null else Vector2.ZERO;
		_ponto_da_pega = _objeto.global_transform * _pega_local - mao_local;
		_fim = _ponto_da_pega + saida_da_pega;
		_controle = 2.0 * _ponto_da_pega - 0.5 * (_comeco + _fim);

	var a := _comeco.lerp(_controle, t);
	var b := _controle.lerp(_fim, t);
	global_position = a.lerp(b, t);

	var aparecer := clampf(t / 0.15, 0.0, 1.0);
	var sumir := clampf((1.0 - t) / 0.2, 0.0, 1.0);
	modulate.a = alfa * minf(aparecer, sumir);

	if t >= 0.5 and not _pegou:
		_pegar();

	if not _pegou or _objeto == null or not is_instance_valid(_objeto) or mao == null:
		return;

	var junta := clampf((t - 0.5) / 0.15, 0.0, 1.0);
	mao.rotation_degrees = lerpf(angulo_alcancando, angulo_segurando, junta);
	var escala := Vector2.ONE * escala_na_mao;
	var alvo_rel := Transform2D(0.0, escala, 0.0, -_pega_local * escala_na_mao);
	var rel := _relativo_inicial.interpolate_with(alvo_rel, junta);
	_objeto.global_transform = mao.global_transform * rel;
	_objeto.modulate.a = sumir;


func _pegar() -> void:
	_pegou = true;
	if _objeto != null and is_instance_valid(_objeto):
		_objeto.z_index = 4096;
		_objeto.z_as_relative = false;
		if mao != null:
			_relativo_inicial = mao.global_transform.affine_inverse() * _objeto.global_transform;
	if _ao_pegar.is_valid():
		_ao_pegar.call();


func _soltar_o_objeto() -> void:
	if _objeto != null and is_instance_valid(_objeto):
		_objeto.queue_free();
	_objeto = null;


func _tocar_sino() -> void:
	if caminho_do_sino == "" or not ResourceLoader.exists(caminho_do_sino):
		return;
	var som := AudioStreamPlayer.new();
	som.stream = load(caminho_do_sino) as AudioStream;
	som.bus = Configuracoes.BUS_SONS;
	var pai := get_parent() if get_parent() != null else self;
	pai.add_child(som);
	som.finished.connect(som.queue_free);
	som.play();


func _sem_animacao() -> bool:
	return Configuracoes.config_ativa(Configuracoes.REMOVER_ANIMACAO);
