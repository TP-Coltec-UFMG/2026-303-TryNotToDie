extends AnimatedSprite2D

@export var sprite : AnimatedSprite2D;
@export var camera_menu : Camera2D;
@export var vel_resp : float = 0.8;
@export var min_easter_egg : int;
@export var max_easter_egg : int;
@export var tempo_pre_queda_dramatico : float;
@export var tempo_pos_queda : float;

@onready var piscar_olho_timer : Timer = Timer.new();

var retirar_animacao : bool = false;
var escala_inicial : Vector2;
var seno_periodo : float;
var animacao_atual : String = "piscar_olho_panela";
var val_easter_egg : int;

var caiu : bool = false;
var posicao_inicial : Vector2;

func piscar_olho() -> void:
	if retirar_animacao:
		return;
	
	piscar_olho_timer.start(randf() * 7 + 5);
	sprite.play(animacao_atual);
	
	val_easter_egg -= 1;
	
	if val_easter_egg <= 0:
		animar_queda();

func _ready() -> void:
	add_child(piscar_olho_timer);
	piscar_olho_timer.start(randf() * 1.5 + 1);
	piscar_olho_timer.timeout.connect(piscar_olho);
	
	position.x = get_viewport_rect().size.x / 2;

	escala_inicial = sprite.scale;
	posicao_inicial = sprite.position;
	
	val_easter_egg = randi() % (max_easter_egg - min_easter_egg) + min_easter_egg;

func _process(delta: float) -> void:

	if not retirar_animacao:
		seno_periodo += delta * vel_resp;
		sprite.scale = escala_inicial * lerp(0.995, 1.005 , sin(seno_periodo));

func animar_queda() -> void:
	if caiu:
		return;
	
	caiu = true;
	
	animacao_atual = "piscar_olho_panela_roxo";

	var tween = create_tween();

	var y_inicial = sprite.position.y;
	var altura_tela = get_viewport_rect().size.y;

	tween.tween_property(sprite, "rotation_degrees", 15, 0.65)\
		.set_trans(Tween.TRANS_SINE)\
		.set_ease(Tween.EASE_OUT);

	tween.tween_interval(tempo_pre_queda_dramatico);

	tween.tween_property(sprite, "position:y", altura_tela + 900, 0.35)\
		.set_trans(Tween.TRANS_CUBIC)\
		.set_ease(Tween.EASE_IN);

	tween.tween_callback(func() :
		camera_menu.chacoalhar();
		)

	tween.tween_interval(tempo_pos_queda);
	
	tween.tween_callback(func():
		sprite.position.y = get_viewport_rect().size.y + 200;
		sprite.rotation_degrees = 0;
		sprite.play(animacao_atual);
	)
	

	tween.tween_property(sprite, "position:y", y_inicial, 0.6)\
		.set_trans(Tween.TRANS_BACK)\
		.set_ease(Tween.EASE_OUT);


func _on_botao_static_pressed() -> void:
	retirar_animacao = !retirar_animacao;
