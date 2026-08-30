extends CharacterBody2D


@export var speed: float = 300.0;
@export var jump_force: float = -500.0;
@export var tolerancia_destino: float = 8.0;
@export var altura_para_pular: float = 40.0;
@export var mostrar_marcador: bool = true;

@export_group("Modo automatico")
@export var modo_automatico: bool = false;
@export var velocidade_auto: float = 260.0;
@export var alcance_frente: float = 78.0;
@export var alcance_buraco: float = 150.0;
@export var avanco_do_raio: float = 62.0;
@export var espera_entre_pulos: float = 0.22;

@export_group("Animacao")
@export var anim_parado: String = "parado";
@export var anim_andando: String = "andando";
@export var escala_animacao: float = 2.4;

@onready var sprite: AnimatedSprite2D = $Sprite;

signal morreu;

var _destino_x: float = 0.0;
var _tem_destino: bool = false;
var _ao_chegar: Callable = Callable();
var _morrendo: bool = false;
var _andando: bool = false;
var _raio_frente: RayCast2D = null;
var _raio_buraco: RayCast2D = null;
var _descanso_pulo: float = 0.0;


func _ready() -> void:
	add_to_group("jogador");
	Configuracoes.config_alterada.connect(_ao_mudar_config);
	_aplicar_animacao(true);

	if modo_automatico:
		_montar_raios();


func _montar_raios() -> void:
	_raio_frente = RayCast2D.new();
	_raio_frente.position = Vector2(0.0, -18.0);
	_raio_frente.target_position = Vector2(alcance_frente, 0.0);
	_raio_frente.collide_with_areas = false;
	add_child(_raio_frente);

	_raio_buraco = RayCast2D.new();
	_raio_buraco.position = Vector2(avanco_do_raio, 0.0);
	_raio_buraco.target_position = Vector2(0.0, alcance_buraco);
	_raio_buraco.collide_with_areas = false;
	add_child(_raio_buraco);


func _correr_sozinho(delta: float) -> float:
	_descanso_pulo = maxf(0.0, _descanso_pulo - delta);

	if not is_on_floor() or _descanso_pulo > 0.0:
		return 1.0;

	var barrado := _raio_frente != null and _raio_frente.is_colliding();
	var buraco := _raio_buraco != null and not _raio_buraco.is_colliding();

	if barrado or buraco or is_on_wall():
		velocity.y = jump_force;
		_descanso_pulo = espera_entre_pulos;

	return 1.0;


func _ao_mudar_config(chave: String, _valor: bool) -> void:
	if chave == Configuracoes.REMOVER_ANIMACAO:
		_aplicar_animacao(true);


func _animar(andando: bool) -> void:
	if andando == _andando:
		return;
	_andando = andando;
	_aplicar_animacao(false);


func _aplicar_animacao(forcar: bool) -> void:
	if sprite == null or sprite.sprite_frames == null or _morrendo:
		return;

	var alvo := anim_parado if (_sem_animacao() or not _andando) else anim_andando;
	if not sprite.sprite_frames.has_animation(alvo):
		return;

	sprite.speed_scale = maxf(0.05, escala_animacao);

	if forcar or sprite.animation != alvo:
		sprite.animation = alvo;
		sprite.frame = 0;

	if _sem_animacao():
		sprite.stop();
	elif not sprite.is_playing():
		sprite.play();


func _sem_animacao() -> bool:
	return Configuracoes.config_ativa(Configuracoes.REMOVER_ANIMACAO);


func esta_morrendo() -> bool:
	return _morrendo;


func morrer() -> void:
	if _morrendo:
		return;
	_morrendo = true;

	cancelar_destino();
	velocity = Vector2.ZERO;
	set_physics_process(false);
	set_process_unhandled_input(false);
	sprite.stop();

	for filho in get_children():
		if filho is CollisionShape2D:
			filho.set_deferred("disabled", true);

	var cam := get_node_or_null("Camera2D") as Camera2D;
	if cam != null:
		var onde := cam.global_position;
		cam.position_smoothing_enabled = false;
		cam.top_level = true;
		cam.global_position = onde;

	morreu.emit();

	if Configuracoes.config_ativa(Configuracoes.REMOVER_ANIMACAO):
		await get_tree().create_timer(0.7).timeout;
		return;

	var y0 := global_position.y;
	var tween := create_tween();
	tween.tween_interval(0.3);
	tween.tween_property(self, "global_position:y", y0 - 220.0, 0.42)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT);
	tween.tween_property(self, "global_position:y", y0 + 900.0, 0.85)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN);
	await tween.finished;


func _unhandled_input(event: InputEvent) -> void:
	if _morrendo or modo_automatico:
		return;
	if event is InputEventMouseButton \
			and event.pressed \
			and event.button_index == MOUSE_BUTTON_LEFT:
		_definir_destino(get_global_mouse_position());


func _definir_destino(ponto: Vector2) -> void:
	_destino_x = ponto.x;
	_tem_destino = absf(_destino_x - global_position.x) > tolerancia_destino;
	_ao_chegar = Callable();

	if mostrar_marcador:
		_marcar(ponto);

	if is_on_floor() and global_position.y - ponto.y > altura_para_pular:
		velocity.y = jump_force;


func _marcar(ponto: Vector2) -> void:
	var pai := get_parent();
	if pai == null:
		return;
	pai.add_child(MarcadorDestino.criar(ponto));


func ir_ate(destino_global_x: float, ao_chegar: Callable = Callable()) -> void:
	_destino_x = destino_global_x;
	_tem_destino = absf(_destino_x - global_position.x) > tolerancia_destino;
	_ao_chegar = ao_chegar;

	if not _tem_destino and ao_chegar.is_valid():
		_chegou();


func _limpar_destino() -> void:
	_tem_destino = false;
	_ao_chegar = Callable();


func cancelar_destino() -> void:
	_limpar_destino();
	_animar(false);


func _chegou() -> void:
	_tem_destino = false;
	var callback := _ao_chegar;
	_ao_chegar = Callable();
	if callback.is_valid():
		callback.call();


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity += get_gravity() * delta;

	var direcao := 0.0;

	if modo_automatico:
		direcao = _correr_sozinho(delta);
		velocity.x = direcao * velocidade_auto;
		sprite.flip_h = false;
		_animar(true);
		move_and_slide();
		return;

	if Input.is_action_just_pressed("Jump") and is_on_floor():
		velocity.y = jump_force;

	direcao = Input.get_axis("Left", "Right");

	if direcao != 0.0:
		_limpar_destino();
	elif _tem_destino:
		var restante := _destino_x - global_position.x;
		if absf(restante) <= tolerancia_destino:
			_chegou();
		else:
			direcao = signf(restante);

	if direcao != 0.0:
		velocity.x = direcao * speed;
		sprite.flip_h = direcao < 0.0;
	else:
		velocity.x = move_toward(velocity.x, 0.0, speed);

	_animar(direcao != 0.0);

	move_and_slide();

	if _tem_destino and is_on_wall():
		cancelar_destino();
