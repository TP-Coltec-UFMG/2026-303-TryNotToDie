extends CharacterBody2D


@export var speed: float = 300.0;
@export var jump_force: float = -500.0;
@export var tolerancia_destino: float = 8.0;
@export var altura_para_pular: float = 40.0;
@export var mostrar_marcador: bool = true;

@onready var sprite: AnimatedSprite2D = $Sprite;

signal morreu;

var _destino_x: float = 0.0;
var _tem_destino: bool = false;
var _ao_chegar: Callable = Callable();
var _morrendo: bool = false;


func _ready() -> void:
	add_to_group("jogador");


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
	if _morrendo:
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


func cancelar_destino() -> void:
	_tem_destino = false;
	_ao_chegar = Callable();


func _chegou() -> void:
	_tem_destino = false;
	var callback := _ao_chegar;
	_ao_chegar = Callable();
	if callback.is_valid():
		callback.call();


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity += get_gravity() * delta;

	if Input.is_action_just_pressed("Jump") and is_on_floor():
		velocity.y = jump_force;

	var direcao := Input.get_axis("Left", "Right");

	if direcao != 0.0:
		cancelar_destino();
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

	move_and_slide();

	if _tem_destino and is_on_wall():
		cancelar_destino();
