extends Button

enum Tipo { ACESSIBILIDADE, TELA_CHEIA };

@export var tipo: Tipo = Tipo.ACESSIBILIDADE;

@export var chave: String = "remover_animacao";

@export var cor_ligado: Color = Color.GREEN;
@export var cor_desligado: Color = Color.WHITE;

const ESTADOS_DE_COR := [
	"font_color",
	"font_focus_color",
	"font_hover_color",
	"font_pressed_color",
	"font_hover_pressed_color",
];


func _ready() -> void:
	toggle_mode = true;
	toggled.connect(_on_toggled);
	Configuracoes.config_alterada.connect(_on_config_alterada);
	_sincronizar();


func _estado_real() -> bool:
	return (
		Configuracoes.tela_cheia if tipo == Tipo.TELA_CHEIA
		else Configuracoes.config_ativa(chave)
	);


func _sincronizar() -> void:
	var ligado := _estado_real();
	set_pressed_no_signal(ligado);
	_pintar(ligado);


func _on_config_alterada(chave_alterada: String, _valor: bool) -> void:
	if tipo == Tipo.ACESSIBILIDADE and chave_alterada == chave:
		_sincronizar();


func _on_toggled(ligado: bool) -> void:
	if tipo == Tipo.TELA_CHEIA:
		Configuracoes.definir_tela_cheia(ligado);
	else:
		Configuracoes.definir_config(chave, ligado);
	_pintar(_estado_real());


func _pintar(ligado: bool) -> void:
	var cor := cor_ligado if ligado else cor_desligado;
	for nome_da_cor in ESTADOS_DE_COR:
		add_theme_color_override(nome_da_cor, cor);
