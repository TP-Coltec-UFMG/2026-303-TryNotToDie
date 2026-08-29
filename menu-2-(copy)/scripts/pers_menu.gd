extends AnimatedSprite2D

class AnimacaoMenu:
	var velocidade_respiracao : float = 0.8;
	var tempo_pre_queda : float = 1.1;
	var min_trigger : int = 4;
	var nome_animacao_atual : String = "piscar_olho_panela";
	var piscar_olho_timer : Timer = Timer.new();
	var escala_inicial : Vector2;
	var seno_periodo : float;
	var caiu : bool = false;
	var posicao_inicial : Vector2;

@export var sprite : AnimatedSprite2D;
@export var camera_menu : Camera2D;

@onready var animacao_configs : AnimacaoMenu = AnimacaoMenu.new();


func piscar_olho() -> void:
	if Configuracoes.config_ativa(Configuracoes.REMOVER_ANIMACAO):
		return;

	animacao_configs.piscar_olho_timer.start(randf() * 7 + 5);
	sprite.play(animacao_configs.nome_animacao_atual);

	if animacao_configs.min_trigger >= 1:
		animacao_configs.min_trigger -= 1;
	else:
		animar_queda();

func _ready() -> void:
	add_child(animacao_configs.piscar_olho_timer);

	animacao_configs.piscar_olho_timer.start(randf() * 1.5 + 1);

	animacao_configs.piscar_olho_timer.timeout.connect(piscar_olho);

	animacao_configs.min_trigger = (randi() % 3) + 1;

	position.x = get_viewport_rect().size.x / 2;

	animacao_configs.escala_inicial = sprite.scale;
	animacao_configs.posicao_inicial = sprite.position;

	Configuracoes.config_alterada.connect(_ao_mudar_config);
	_sincronizar_animacao();

func _ao_mudar_config(chave: String, _valor: bool) -> void:
	if chave == Configuracoes.REMOVER_ANIMACAO:
		_sincronizar_animacao();

func _sincronizar_animacao() -> void:
	if Configuracoes.config_ativa(Configuracoes.REMOVER_ANIMACAO):
		animacao_configs.piscar_olho_timer.stop();
		sprite.stop();
		sprite.frame = 0;
		sprite.scale = animacao_configs.escala_inicial;
	else:
		animacao_configs.piscar_olho_timer.start(randf() * 1.5 + 1);

func _process(delta: float) -> void:

	if not Configuracoes.config_ativa(Configuracoes.REMOVER_ANIMACAO):
		animacao_configs.seno_periodo += delta * animacao_configs.velocidade_respiracao;
		sprite.scale = animacao_configs.escala_inicial * lerp(0.995, 1.005 , sin(animacao_configs.seno_periodo));

func animar_queda() -> void:
	if animacao_configs.caiu:
		return;

	animacao_configs.caiu = true;

	animacao_configs.nome_animacao_atual = "piscar_olho_panela_roxo";

	var tween = create_tween();

	var y_inicial = sprite.position.y;
	var altura_tela = get_viewport_rect().size.y;

	tween.tween_property(sprite, "rotation_degrees", 15, 0.65)\
		.set_trans(Tween.TRANS_SINE)\
		.set_ease(Tween.EASE_OUT);

	tween.tween_interval(animacao_configs.tempo_pre_queda);

	tween.tween_property(sprite, "position:y", altura_tela + 900, 0.35)\
		.set_trans(Tween.TRANS_CUBIC)\
		.set_ease(Tween.EASE_IN);

	tween.tween_callback(func() :
		camera_menu.chacoalhar();
		);

	tween.tween_interval(animacao_configs.tempo_pre_queda * 3);

	tween.tween_callback(func():
		sprite.position.y = get_viewport_rect().size.y + 200;
		sprite.rotation_degrees = 0;
		sprite.play(animacao_configs.nome_animacao_atual);
	);


	tween.tween_property(sprite, "position:y", y_inicial, 0.6)\
		.set_trans(Tween.TRANS_BACK)\
		.set_ease(Tween.EASE_OUT);
