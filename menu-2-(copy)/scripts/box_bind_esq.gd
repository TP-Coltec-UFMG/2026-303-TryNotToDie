extends HBoxContainer

@export var nome_acao : String = "Left";

@onready var label_acao := $LabelAcao
@onready var botao_tecla := $BotaoTecla
@onready var bind_padrao := InputEventKey.new();

var aguardando_input : bool = false

func _ready() -> void:
	bind_padrao.physical_keycode = KEY_A;
	label_acao.text = nome_acao
	atualizar_label_tecla()
	botao_tecla.pressed.connect(_on_botao_pressed)
	InputMap.action_erase_events(nome_acao)
	InputMap.action_add_event(nome_acao, bind_padrao)


func atualizar_label_tecla() -> void:
	var eventos = InputMap.action_get_events(nome_acao)
	if eventos.size() > 0:
		botao_tecla.text = eventos[0].as_text()
	else:
		botao_tecla.text = "A"

func _on_botao_pressed() -> void:
	aguardando_input = true
	botao_tecla.text = "..."

func _input(event: InputEvent) -> void:
	if not aguardando_input:
		return
	if event is InputEventKey and event.pressed:
		InputMap.action_erase_events(nome_acao)
		InputMap.action_add_event(nome_acao, event)
		atualizar_label_tecla()
		aguardando_input = false
		get_viewport().set_input_as_handled()
