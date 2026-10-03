class_name GeradorVinhas
extends Node2D

signal aviso_comecou(ponto: Vector2);
signal vinha_surgiu(vinha: Node2D);

@export var jogador: Node2D;
@export var pai_das_plantas: Node;
@export var cena_vinha: PackedScene;

@export_group("Onde surgem")
@export var x_inicio: float = 150.0;
@export var x_limite: float = 8950.0;
@export var distancia_minima: float = 430.0;
@export var distancia_maxima: float = 530.0;
@export var intervalo_minimo: float = 650.0;
@export var intervalo_maximo: float = 1150.0;
@export var separacao_minima: float = 380.0;
@export var folga_de_obstaculos: float = 150.0;
@export var folga_de_plantas: float = 260.0;
@export var tolerancia_do_chao: float = 8.0;
@export var alcance_da_busca: float = 500.0;
@export var tentativas: int = 10;

@export_group("Aviso")
@export var duracao_aviso: float = 0.4;
@export var tremor_inicial: float = 2.0;
@export var tremor_final: float = 7.0;
@export var tremor_ao_surgir: float = 10.0;

@export_group("Subida")
@export var duracao_subida: float = 0.25;
@export var profundidade: float = 320.0;
@export var variacao_largura: Vector2 = Vector2(0.85, 1.3);

@export_group("Terra")
@export var cores_da_terra: PackedColorArray = PackedColorArray([
	Color(0.24, 0.14, 0.07),
	Color(0.40, 0.25, 0.13),
	Color(0.55, 0.37, 0.20),
	Color(0.36, 0.60, 0.28),
]);
@export var particulas_aviso: int = 16;
@export var particulas_estouro: int = 42;
@export var gravidade_terra: float = 1100.0;
@export var z_terra: int = 22;

var _proximo_gatilho: float = 0.0;
var _ultimo_x: float = -INF;
var _avisando: bool = false;
var _camera: Node = null;


func _ready() -> void:
	_proximo_gatilho = x_inicio;
	if pai_das_plantas == null:
		pai_das_plantas = get_parent();


func _physics_process(_delta: float) -> void:
	if cena_vinha == null or _avisando:
		return;

	if jogador == null or not is_instance_valid(jogador):
		jogador = get_tree().get_first_node_in_group("jogador") as Node2D;
		if jogador == null:
			return;

	if jogador.has_method("esta_morrendo") and jogador.call("esta_morrendo"):
		return;

	var x := jogador.global_position.x;
	if x + distancia_minima > x_limite:
		set_physics_process(false);
		return;
	if x < _proximo_gatilho:
		return;

	var ponto := _escolher_ponto(x);
	if not ponto.is_finite():
		_proximo_gatilho = x + 40.0;
		return;

	_proximo_gatilho = x + randf_range(intervalo_minimo, intervalo_maximo);
	_avisar(ponto);


func _escolher_ponto(x: float) -> Vector2:
	for _i in tentativas:
		var alvo := x + randf_range(distancia_minima, distancia_maxima);
		if alvo > x_limite:
			continue;
		if alvo - _ultimo_x < separacao_minima:
			continue;
		if _tem_planta_perto(alvo):
			continue;
		var chao := _chao_plano_em(alvo);
		if is_nan(chao):
			continue;
		return Vector2(alvo, chao);
	return Vector2.INF;


func _chao_em(x: float) -> float:
	var y0 := jogador.global_position.y;
	var consulta := PhysicsRayQueryParameters2D.create(
		Vector2(x, y0 - alcance_da_busca),
		Vector2(x, y0 + alcance_da_busca)
	);
	consulta.collide_with_areas = false;
	consulta.collide_with_bodies = true;
	var corpo := jogador as CollisionObject2D;
	if corpo != null:
		consulta.exclude = [corpo.get_rid()];

	var achou := get_world_2d().direct_space_state.intersect_ray(consulta);
	if achou.is_empty():
		return NAN;
	return (achou.position as Vector2).y;


func _chao_plano_em(x: float) -> float:
	var centro := _chao_em(x);
	if is_nan(centro):
		return NAN;

	var passos := maxi(1, ceili(folga_de_obstaculos / 40.0));
	var passo := folga_de_obstaculos / passos;
	for k in range(-passos, passos + 1):
		if k == 0:
			continue;
		var y := _chao_em(x + k * passo);
		if is_nan(y) or absf(y - centro) > tolerancia_do_chao:
			return NAN;
	return centro;


func _tem_planta_perto(x: float) -> bool:
	if pai_das_plantas == null:
		return false;
	for filho in pai_das_plantas.get_children():
		var planta := filho as Planta;
		if planta == null or planta.foi_cortada():
			continue;
		if absf(planta.global_position.x - x) < folga_de_plantas:
			return true;
	return false;


func _avisar(ponto: Vector2) -> void:
	_avisando = true;
	_ultimo_x = ponto.x;

	var monte := _criar_monte(ponto);
	var poeira: CPUParticles2D = null;
	if not _sem_animacao():
		poeira = _soltar_terra(ponto, particulas_aviso, 50.0, 170.0, 28.0, 0.5, 22.0, true);

	aviso_comecou.emit(ponto);

	var tween := create_tween();
	tween.tween_method(_passo_do_aviso.bind(monte, ponto), 0.0, 1.0, maxf(0.05, duracao_aviso));
	tween.tween_callback(_brotar.bind(ponto, monte, poeira));


func _passo_do_aviso(f: float, monte: Node2D, ponto: Vector2) -> void:
	_tremer(lerpf(tremor_inicial, tremor_final, f));

	if _sem_animacao() or not is_instance_valid(monte):
		return;
	monte.scale = Vector2(lerpf(0.35, 1.0, f), lerpf(0.15, 1.0, f));
	monte.global_position = ponto + Vector2(randf_range(-1.5, 1.5) * f, 2.0);


func _brotar(ponto: Vector2, monte: Node2D, poeira: CPUParticles2D) -> void:
	_avisando = false;

	if poeira != null and is_instance_valid(poeira):
		poeira.emitting = false;
		_liberar_depois(poeira, poeira.lifetime + 0.1);

	if not _sem_animacao():
		_soltar_terra(ponto, particulas_estouro, 240.0, 540.0, 32.0, 0.85, 30.0, false);
	_tremer(tremor_ao_surgir);

	var vinha := cena_vinha.instantiate() as Node2D;
	if vinha == null:
		_sumir_monte(monte);
		return;

	_variar(vinha);
	var pai := pai_das_plantas if pai_das_plantas != null else get_parent();
	vinha.global_position = ponto;
	pai.add_child(vinha);
	vinha.global_position = ponto;

	_subir(vinha);
	_sumir_monte(monte);
	vinha_surgiu.emit(vinha);


func _sprite_de(vinha: Node) -> Node2D:
	var planta := vinha as Planta;
	if planta != null and planta.sprite_planta != null and is_instance_valid(planta.sprite_planta):
		return planta.sprite_planta;
	for filho in vinha.get_children():
		if filho is Sprite2D or filho is AnimatedSprite2D:
			return filho;
	return null;


func _variar(vinha: Node2D) -> void:
	var sprite := _sprite_de(vinha);
	if sprite == null:
		return;
	sprite.scale.x *= randf_range(variacao_largura.x, variacao_largura.y);
	if sprite is Sprite2D:
		(sprite as Sprite2D).flip_h = randf() < 0.5;


func _subir(vinha: Node2D) -> void:
	var sprite := _sprite_de(vinha);
	if sprite == null or _sem_animacao():
		return;

	var base := sprite.position;
	sprite.position = base + Vector2(0.0, profundidade);

	var tween := vinha.create_tween();
	tween.tween_property(sprite, "position", base, maxf(0.05, duracao_subida))\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT);


func _criar_monte(ponto: Vector2) -> Node2D:
	var monte := Node2D.new();
	monte.z_index = z_terra - 1;

	var escuro := Polygon2D.new();
	escuro.color = cores_da_terra[0] if cores_da_terra.size() > 0 else Color(0.24, 0.14, 0.07);
	escuro.polygon = _meia_elipse(42.0, 15.0);
	monte.add_child(escuro);

	var claro := Polygon2D.new();
	claro.color = cores_da_terra[1] if cores_da_terra.size() > 1 else Color(0.40, 0.25, 0.13);
	claro.polygon = _meia_elipse(30.0, 10.0);
	claro.position = Vector2(0.0, -1.0);
	monte.add_child(claro);

	add_child(monte);
	monte.global_position = ponto + Vector2(0.0, 2.0);
	if not _sem_animacao():
		monte.scale = Vector2(0.35, 0.15);
	return monte;


func _meia_elipse(raio_x: float, raio_y: float) -> PackedVector2Array:
	var pontos := PackedVector2Array();
	var lados := 10;
	for i in lados + 1:
		var a := PI + PI * float(i) / float(lados);
		pontos.append(Vector2(roundf(raio_x * cos(a)), roundf(raio_y * sin(a))));
	return pontos;


func _sumir_monte(monte: Node2D) -> void:
	if monte == null or not is_instance_valid(monte):
		return;
	if _sem_animacao():
		monte.queue_free();
		return;
	monte.scale = Vector2.ONE;
	var tween := create_tween();
	tween.tween_property(monte, "modulate:a", 0.0, 0.5).set_delay(0.5);
	tween.tween_callback(monte.queue_free);


func _soltar_terra(ponto: Vector2, quantidade: int, velocidade_min: float, velocidade_max: float,
		abertura: float, vida: float, largura: float, continuo: bool) -> CPUParticles2D:
	var p := CPUParticles2D.new();
	p.z_index = z_terra;
	p.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST;
	p.amount = maxi(1, quantidade);
	p.lifetime = vida;
	p.one_shot = not continuo;
	p.explosiveness = 0.0 if continuo else 0.9;
	p.randomness = 0.4;
	p.local_coords = false;
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE;
	p.emission_rect_extents = Vector2(largura, 3.0);
	p.direction = Vector2.UP;
	p.spread = abertura;
	p.gravity = Vector2(0.0, gravidade_terra);
	p.initial_velocity_min = velocidade_min;
	p.initial_velocity_max = velocidade_max;
	p.scale_amount_min = 3.0;
	p.scale_amount_max = 7.0;
	p.color_initial_ramp = _gradiente_da_terra();
	p.color_ramp = _gradiente_de_sumico();

	add_child(p);
	p.global_position = ponto + Vector2(0.0, -4.0);
	p.emitting = true;

	if not continuo:
		_liberar_depois(p, vida + 0.2);
	return p;


func _gradiente_da_terra() -> Gradient:
	var g := Gradient.new();
	g.interpolation_mode = Gradient.GRADIENT_INTERPOLATE_CONSTANT;
	var n := cores_da_terra.size();
	if n == 0:
		return g;
	var offsets := PackedFloat32Array();
	for i in n:
		offsets.append(float(i) / float(n));
	g.offsets = offsets;
	g.colors = cores_da_terra;
	return g;


func _gradiente_de_sumico() -> Gradient:
	var g := Gradient.new();
	g.offsets = PackedFloat32Array([0.0, 0.7, 1.0]);
	g.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 1), Color(1, 1, 1, 0)]);
	return g;


func _liberar_depois(no: Node, segundos: float) -> void:
	var tween := create_tween();
	tween.tween_interval(maxf(0.0, segundos));
	tween.tween_callback(no.queue_free);


func _tremer(forca: float) -> void:
	if forca <= 0.0:
		return;
	if _camera == null or not is_instance_valid(_camera):
		_camera = _achar_camera();
	if _camera != null:
		_camera.call("sacudir", forca);


func _achar_camera() -> Node:
	if jogador == null or not is_instance_valid(jogador):
		return null;
	for filho in jogador.get_children():
		if filho.has_method("sacudir"):
			return filho;
	return null;


func _sem_animacao() -> bool:
	return Configuracoes.config_ativa(Configuracoes.REMOVER_ANIMACAO);
