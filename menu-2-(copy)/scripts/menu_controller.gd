extends Node

@export var container_alpha: VBoxContainer;
@export var container_beta: VBoxContainer;
@export var personagem_menu: AnimatedSprite2D;
@export var pelicula: ColorRect;

@export var duracao_transicao: float = 1.35;

var _tela: Viewport;
var _transicionando: bool = false;

func _ready() -> void:
	_tela = get_viewport();

	for container in [container_alpha, container_beta]:
		for filho in container.get_children():
			if filho is Button:
				filho.mouse_entered.connect(filho.grab_focus);

	if pelicula != null:
		pelicula.visible = false;
		pelicula.mouse_filter = Control.MOUSE_FILTER_IGNORE;

	var slider: HSlider = container_beta.get_node("BoxFonte/SliderFonte");
	slider.min_value = Configuracoes.FONTE_MIN;
	slider.max_value = Configuracoes.FONTE_MAX;
	slider.set_value_no_signal(Configuracoes.tamanho_fonte);

	container_alpha.get_node("Botao_Jogar").grab_focus();

func _on_botao_configuracoes_pressed() -> void:
	if _transicionando:
		return;
	container_alpha.visible = false;

	_caminhar_ate(_largura(), func() -> void:
		container_beta.visible = true
		_mostrar_pelicula(true)
		_focar(container_beta, "Botao_Retornar")
	);


func _on_botao_retornar_pressed() -> void:
	if _transicionando:
		return;
	container_beta.visible = false;
	_mostrar_pelicula(false);

	_caminhar_ate(_largura() / 2.0, func() -> void:
		container_alpha.visible = true
		_focar(container_alpha, "Botao_Jogar")
	);


func _caminhar_ate(destino_x: float, ao_terminar: Callable) -> void:
	_transicionando = true;

	var sem_animacao := Configuracoes.config_ativa(Configuracoes.REMOVER_ANIMACAO);

	var tween := create_tween();
	tween.tween_property(personagem_menu, "position:x", destino_x, duracao_transicao)\
		.set_trans(Tween.TRANS_LINEAR if sem_animacao else Tween.TRANS_QUAD)\
		.set_ease(Tween.EASE_IN_OUT if sem_animacao else Tween.EASE_IN);
	tween.tween_callback(func() -> void:
		ao_terminar.call()
		_transicionando = false
	);

func _on_slider_fonte_value_changed(value: float) -> void:
	Configuracoes.definir_tamanho_fonte(int(value));


func _on_botao_static_pressed() -> void:
	Configuracoes.alternar_config(Configuracoes.REMOVER_ANIMACAO);


func _on_botao_fullscreen_pressed() -> void:
	Configuracoes.alternar_tela_cheia();


func _largura() -> float:
	return _tela.get_visible_rect().size.x;


func _mostrar_pelicula(mostrar: bool) -> void:
	if pelicula != null:
		pelicula.visible = mostrar;


func _focar(container: Control, nome: String) -> void:
	var no := container.get_node_or_null(nome);
	if no is Control:
		no.grab_focus();
