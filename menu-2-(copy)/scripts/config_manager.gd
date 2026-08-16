extends Node

@export var Container_Alpha_Menu : VBoxContainer;
@export var Container_Beta_Menu : VBoxContainer;
@export var Personagem_Menu : AnimatedSprite2D;
@export var Box_Fonte : HBoxContainer;
@export var principal : Sprite2D;

@onready var config_remover_animacao : String = "remover_animacao";

var pelicula : Control;
var valor_inicial_fonte : int = 22;
var tela : Viewport;

var configs_acessibilidade : Dictionary[String, bool];

func _ready() -> void:
	for botao in Container_Alpha_Menu.get_children():
		if botao is Button:
			botao.mouse_entered.connect(botao.grab_focus)
	for botao in Container_Beta_Menu.get_children():
		if botao is Button:
			botao.mouse_entered.connect(botao.grab_focus)
	
	Container_Alpha_Menu.get_node("Botao_Jogar").grab_focus()
	principal.visible = false;
	tela = get_viewport();
	
	if tela == null:
		print('Nao foi possivel obter o visor');
		get_tree().exit();
	
	var tamanho_tela = tela.get_visible_rect().size
	Container_Beta_Menu.position.y = tamanho_tela.y / 2.0  - (Container_Beta_Menu.size.y / 2);
	Container_Beta_Menu.position.x = tamanho_tela.x / 6.0 - (Container_Beta_Menu.position.x / 12.0);
	
	# Embora haja como deixar isso no slider, fiz assim para depois salvar as configuracoes no JSON
	# e fazer com que a pessoa que esteja jogando nao precisasse toda hora mexer nesse valor.
	Container_Beta_Menu.get_node("BoxFonte").get_node("SliderFonte").value = valor_inicial_fonte;

#func _process(delta: float) -> void:
	#pass
	
func criar_pelicula():
	if(pelicula != null):
		return;
	pelicula = ColorRect.new()

	pelicula.position = Vector2(0, 0)
	pelicula.size = Vector2(
		tela.get_visible_rect().size.x / 2.0,
		tela.get_visible_rect().size.y
	)

	pelicula.color = Color(0, 0, 0, 0.35)

	pelicula.z_index = -1
	pelicula.mouse_filter = Control.MOUSE_FILTER_IGNORE;
	add_child(pelicula)

func liberar_pelicula():
	if(pelicula == null): 
		return;
	pelicula.queue_free();
	pelicula = null;

func animar_menu_config():
	Container_Alpha_Menu.visible = false;
	
	var tween = create_tween();
	
	tween.tween_property(Personagem_Menu, "position:x", tela.size.x, 1.35)\
		.set_trans(Tween.TRANS_QUAD)\
		.set_ease(Tween.EASE_IN);
	
	tween.tween_property(Container_Beta_Menu, "visible", true, 0);
	
	tween.tween_callback(criar_pelicula);

func _on_botao_configuracoes_pressed() -> void:
	if not config_ativa(config_remover_animacao):
		animar_menu_config();
	else:
		Container_Alpha_Menu.visible = false;
		Personagem_Menu.position.x = tela.size.x;
		Container_Beta_Menu.visible = true;
		criar_pelicula();
	Container_Beta_Menu.get_node("Botao_Retornar").grab_focus();
	

func animar_menu_retorno():
	var tween = create_tween();
	tween.tween_callback(liberar_pelicula);
	
	tween.tween_property(Container_Beta_Menu, "visible", false, 0);
	
	tween.tween_property(Personagem_Menu, "position:x", tela.size.x/2, 1.35)\
		.set_trans(Tween.TRANS_QUAD)\
		.set_ease(Tween.EASE_IN);
	
	tween.tween_property(Container_Alpha_Menu, "visible", true, 0);
	

func _on_botao_retornar_pressed() -> void:
	if not config_ativa(config_remover_animacao):
		animar_menu_retorno();
	else:
		Container_Beta_Menu.visible = false;
		Personagem_Menu.position.x = tela.size.x/2;
		Container_Alpha_Menu.visible = true;
		liberar_pelicula();
	Container_Alpha_Menu.get_node("Botao_Jogar").grab_focus();
	Container_Alpha_Menu.position.x = (tela.get_visible_rect().size.x / 2) - (Container_Alpha_Menu.size.x / 2);

func _on_h_slider_value_changed(value: float) -> void:
	var tema = get_tree().root.theme;
	
	if tema == null:
		tema = Theme.new();
		get_tree().root.theme = tema;
	
	tema.default_font_size = int(value);

func _on_botao_static_pressed() -> void:
	if(not configs_acessibilidade.has(config_remover_animacao)):
		configs_acessibilidade[config_remover_animacao] = true;
	else:
		configs_acessibilidade[config_remover_animacao] = not configs_acessibilidade[config_remover_animacao];


func config_ativa(key : String) -> bool:
	if not configs_acessibilidade.has(key):
		return false;
	return configs_acessibilidade.get(key);
