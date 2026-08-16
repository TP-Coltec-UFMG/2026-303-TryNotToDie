extends Node

@export var Container_Alpha_Menu : VBoxContainer;
@export var Container_Beta_Menu : VBoxContainer;
@export var Personagem_Menu : AnimatedSprite2D;
@export var Pelicula : Sprite2D;
@export var Box_Fonte : HBoxContainer;
@export var principal : Sprite2D;
var alto_contraste_ativo : bool = true;

var animar_config : bool = true;
var valor_inicial_fonte : int = 22;
var tela : Viewport;

var configs_acessibilidade : Dictionary[String, bool];

func _ready() -> void:
	Container_Alpha_Menu.get_node("Botao_Jogar").grab_focus()
	principal.visible = false;
	tela = get_viewport();
	
	if tela == null:
		print('Nao foi possivel obter o visor');
		get_tree().exit();
	
	var tamanho_tela = tela.get_visible_rect().size
	var tamanho_textura = Pelicula.texture.get_size()
	
	var escala_x = (tamanho_tela.x / 2.0) / tamanho_textura.x
	var escala_y = tamanho_tela.y / tamanho_textura.y
	
	Pelicula.scale = Vector2(escala_x, escala_y)
	Pelicula.position = Vector2(
		(tamanho_textura.x * escala_x) / 2.0,
		tamanho_tela.y / 2.0
	)
	
	Pelicula.visible = false;
	
	Container_Beta_Menu.position.y = tamanho_tela.y / 2.0  - (Container_Beta_Menu.size.y / 2);
	Container_Beta_Menu.position.x = tamanho_tela.x / 6.0 - (Container_Beta_Menu.position.x / 12.0);
	
	# Embora haja como deixar isso no slider, fiz assim para depois salvar as configuracoes no JSON
	# e fazer com que a pessoa que esteja jogando nao precisasse toda hora mexer nesse valor.
	Container_Beta_Menu.get_node("BoxFonte").get_node("SliderFonte").value = valor_inicial_fonte;

#func _process(delta: float) -> void:
	#pass

func animar_menu_config():
	Container_Alpha_Menu.visible = false;
	
	var tween = create_tween();
	
	tween.tween_property(Personagem_Menu, "position:x", tela.size.x, 1.35)\
		.set_trans(Tween.TRANS_QUAD)\
		.set_ease(Tween.EASE_IN);
		
	tween.tween_property(Pelicula, "visible", true, 0);
	
	tween.tween_property(Container_Beta_Menu, "visible", true, 0);
	

func _on_botao_configuracoes_pressed() -> void:
	if animar_config:
		animar_menu_config();
	else:
		Container_Alpha_Menu.visible = false;
		Personagem_Menu.position.x = tela.size.x;
		Pelicula.visible = true;
		Container_Beta_Menu.visible = true;
	Container_Beta_Menu.get_node("Botao_Retornar").grab_focus();

func animar_menu_retorno():
	var tween = create_tween();
	
	tween.tween_property(Pelicula, "visible", false, 0);
	tween.tween_property(Container_Beta_Menu, "visible", false, 0);
	
	tween.tween_property(Personagem_Menu, "position:x", tela.size.x/2, 1.35)\
		.set_trans(Tween.TRANS_QUAD)\
		.set_ease(Tween.EASE_IN);
	
	tween.tween_property(Container_Alpha_Menu, "visible", true, 0);

func _on_botao_retornar_pressed() -> void:
	if animar_config:
		animar_menu_retorno();
	else:
		Pelicula.visible = false;
		Container_Beta_Menu.visible = false;
		Personagem_Menu.position.x = tela.size.x/2;
		Container_Alpha_Menu.visible = true;
	Container_Alpha_Menu.get_node("Botao_Jogar").grab_focus();
	Container_Alpha_Menu.position.x = (tela.get_visible_rect().size.x / 2) - (Container_Alpha_Menu.size.x / 2);

func _on_h_slider_value_changed(value: float) -> void:
	var tema = get_tree().root.theme;
	
	if tema == null:
		tema = Theme.new();
		get_tree().root.theme = tema;
	
	tema.default_font_size = int(value);

func _on_botao_static_pressed() -> void:
	animar_config = !animar_config;
	
func aplicar_alto_contraste(ativo: bool) -> void:
	var tema = get_tree().root.theme
	
	if tema == null:
		tema = Theme.new()
		get_tree().root.theme = tema

	if ativo:
		tema.set_color("font_color", "Label", Color.YELLOW)
		tema.set_color("font_color", "Button", Color.WHITE)
		tema.set_color("font_hover_color", "Button", Color.YELLOW) 
		
		
	else:
		
		tema.clear_color("font_color", "Label")
		tema.clear_color("font_color", "Button")
		tema.clear_color("font_hover_color", "Button")
		
