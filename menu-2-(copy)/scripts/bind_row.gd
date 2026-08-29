extends HBoxContainer

@export var nome_acao: String;

@onready var label_acao: Label = $LabelAcao
@onready var botao_tecla: Button = $BotaoTecla

var _aguardando: bool = false

func _ready() -> void:
	label_acao.text = nome_acao
	botao_tecla.pressed.connect(_on_botao_pressed)
	Configuracoes.bind_alterado.connect(_on_bind_alterado)
	_atualizar_label()

func _atualizar_label() -> void:
	var keycode: int = Configuracoes.binds.get(nome_acao, Configuracoes.BINDS_PADRAO.get(nome_acao, KEY_NONE))
	botao_tecla.text = Configuracoes.texto_da_tecla(keycode)

func _on_bind_alterado(acao: String, _keycode: int) -> void:
	if acao == nome_acao or not _aguardando:
		_atualizar_label()

func _on_botao_pressed() -> void:
	_aguardando = true
	botao_tecla.text = "..."

func _input(evento: InputEvent) -> void:
	if not _aguardando:
		return
	if not (evento is InputEventKey and evento.pressed and not evento.echo):
		return

	get_viewport().set_input_as_handled()
	_aguardando = false

	var keycode: int = evento.physical_keycode

	if keycode == KEY_ESCAPE:
		_atualizar_label()
		return
	var dona := Configuracoes.acao_do_keycode(keycode)
	if dona != "" and dona != nome_acao:
		Configuracoes.definir_bind(dona, Configuracoes.binds[nome_acao])

	Configuracoes.definir_bind(nome_acao, keycode)
	_atualizar_label()
