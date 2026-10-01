extends Node

const CAMINHO_SAVE := "user://config.json"

const REMOVER_ANIMACAO := "remover_animacao"
const ALTO_CONTRASTE := "alto_contraste"

const BINDS_PADRAO := {
	"Left": KEY_A,
	"Right": KEY_D,
	"Jump": KEY_SPACE,
	"Down": KEY_S,
	"Pause": KEY_ESCAPE,
}

const FONTE_MIN := 10
const FONTE_MAX := 42

const FONTE_BASE := "res://ARCADE_N.TTF"
const FONTE_ACENTOS := "res://ARCADE_ACENTOS.TTF"

const NOMES_TECLAS := {
	"Space": "ESPAÇO",
	"Escape": "ESC",
	"Enter": "ENTER",
	"Kp Enter": "ENTER",
	"Backspace": "BACKSPACE",
	"Tab": "TAB",
	"Shift": "SHIFT",
	"Ctrl": "CTRL",
	"Alt": "ALT",
	"Meta": "WINDOWS",
	"CapsLock": "CAPS LOCK",
	"Up": "SETA CIMA",
	"Down": "SETA BAIXO",
	"Left": "SETA ESQUERDA",
	"Right": "SETA DIREITA",
	"PageUp": "PAGE UP",
	"PageDown": "PAGE DOWN",
	"Comma": ",",
	"Period": ".",
	"Minus": "-",
	"Equal": "=",
	"Slash": "/",
	"Backslash": "\\",
	"Semicolon": ";",
	"Apostrophe": "'",
	"Quoteleft": "`",
	"Bracketleft": "[",
	"Bracketright": "]",
}

const BUS_SONS := "Sons"
const BUS_MUSICA := "Musica"
const VOLUME_PADRAO := 0.7
const VOLUME_MUSICA_PADRAO := 0.5
const VOLUME_NARRACAO_PADRAO := 0.0

signal config_alterada(chave: String, valor: bool)
signal fonte_alterada(tamanho: int)
signal bind_alterado(acao: String, keycode: int)
signal volume_alterado(valor: float)
signal volume_musica_alterado(valor: float)
signal volume_narracao_alterado(valor: float)

var acessibilidade: Dictionary[String, bool] = {
	REMOVER_ANIMACAO: false,
	ALTO_CONTRASTE: false,
}
var tamanho_fonte: int = 22
var tela_cheia: bool = false
var volume_sons: float = VOLUME_PADRAO
var volume_musica: float = VOLUME_MUSICA_PADRAO
var volume_narracao: float = VOLUME_NARRACAO_PADRAO
var binds: Dictionary[String, int] = {}

var _tema: Theme
var _fonte_base: FontFile


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_garantir_acentos()
	_garantir_tema()
	_garantir_bus()
	carregar()
	add_child(Leitor.new())


func config_ativa(chave: String) -> bool:
	return acessibilidade.get(chave, false)

func definir_config(chave: String, valor: bool) -> void:
	if acessibilidade.get(chave, false) == valor:
		return
	acessibilidade[chave] = valor
	config_alterada.emit(chave, valor)
	salvar()


func alternar_config(chave: String) -> bool:
	var novo := not config_ativa(chave)
	definir_config(chave, novo)
	return novo

func definir_tamanho_fonte(valor: int) -> void:
	tamanho_fonte = clampi(valor, FONTE_MIN, FONTE_MAX)
	_garantir_tema()
	_tema.default_font_size = tamanho_fonte
	var espaco_linhas := maxi(3, roundi(tamanho_fonte * 0.3))
	_tema.set_constant("line_spacing", "Label", espaco_linhas)
	ThemeDB.get_default_theme().set_constant("line_spacing", "Label", espaco_linhas)
	fonte_alterada.emit(tamanho_fonte)
	salvar()

func _garantir_tema() -> void:
	var raiz := get_tree().root
	if raiz.theme == null:
		raiz.theme = Theme.new();
	_tema = raiz.theme;

func _garantir_bus() -> void:
	_criar_bus(BUS_SONS);
	_criar_bus(BUS_MUSICA);


func _criar_bus(nome: String) -> void:
	if AudioServer.get_bus_index(nome) >= 0:
		return;
	var indice := AudioServer.bus_count;
	AudioServer.add_bus(indice);
	AudioServer.set_bus_name(indice, nome);
	AudioServer.set_bus_send(indice, "Master");


func definir_volume_sons(valor: float) -> void:
	var novo := clampf(valor, 0.0, 1.0);
	if is_equal_approx(novo, volume_sons):
		return;
	volume_sons = novo;
	_aplicar_volume();
	volume_alterado.emit(volume_sons);
	salvar();


func definir_volume_musica(valor: float) -> void:
	var novo := clampf(valor, 0.0, 1.0);
	if is_equal_approx(novo, volume_musica):
		return;
	volume_musica = novo;
	_aplicar_volume();
	volume_musica_alterado.emit(volume_musica);
	salvar();


func definir_volume_narracao(valor: float) -> void:
	var novo := clampf(valor, 0.0, 1.0);
	if is_equal_approx(novo, volume_narracao):
		return;
	volume_narracao = novo;
	volume_narracao_alterado.emit(volume_narracao);
	salvar();


func _aplicar_volume() -> void:
	_garantir_bus();
	_aplicar_volume_no_bus(BUS_SONS, volume_sons);
	_aplicar_volume_no_bus(BUS_MUSICA, volume_musica);


func _aplicar_volume_no_bus(nome: String, valor: float) -> void:
	var indice := AudioServer.get_bus_index(nome);
	if indice < 0:
		return;
	AudioServer.set_bus_mute(indice, valor <= 0.001);
	AudioServer.set_bus_volume_db(indice, linear_to_db(maxf(valor, 0.001)));


func definir_tela_cheia(valor: bool) -> void:
	tela_cheia = valor;
	DisplayServer.window_set_mode(
		DisplayServer.WINDOW_MODE_FULLSCREEN if valor else DisplayServer.WINDOW_MODE_WINDOWED
	);
	salvar();


func alternar_tela_cheia() -> bool:
	definir_tela_cheia(not tela_cheia);
	return tela_cheia;

func definir_bind(acao: String, keycode: int) -> void:
	if not InputMap.has_action(acao):
		push_warning("Acao inexistente no InputMap: %s" % acao);
		return;
	binds[acao] = keycode;
	_aplicar_bind(acao, keycode);
	bind_alterado.emit(acao, keycode);
	salvar();

func resetar_binds() -> void:
	for acao in BINDS_PADRAO:
		definir_bind(acao, BINDS_PADRAO[acao]);

func acao_do_keycode(keycode: int) -> String:
	## Retorna a acao que ja usa essa tecla, ou "" se estiver livre.
	for acao in binds:
		if binds[acao] == keycode:
			return acao;
	return "";

func texto_da_tecla(keycode: int) -> String:
	## physical_keycode -> letra que a pessoa realmente ve no teclado dela
	var nome := OS.get_keycode_string(DisplayServer.keyboard_get_keycode_from_physical(keycode))
	if NOMES_TECLAS.has(nome):
		return NOMES_TECLAS[nome]
	if nome.begins_with("Kp "):
		var resto := nome.substr(3)
		return "NUM " + NOMES_TECLAS.get(resto, resto.to_upper())
	return nome.to_upper()

func _garantir_acentos() -> void:
	if not ResourceLoader.exists(FONTE_BASE) or not ResourceLoader.exists(FONTE_ACENTOS):
		return
	_fonte_base = load(FONTE_BASE) as FontFile
	var acentos := load(FONTE_ACENTOS) as Font
	if _fonte_base == null or acentos == null or _fonte_base.fallbacks.has(acentos):
		return
	var reservas := _fonte_base.fallbacks.duplicate()
	reservas.push_front(acentos)
	_fonte_base.fallbacks = reservas

func _aplicar_bind(acao: String, keycode: int) -> void:
	InputMap.action_erase_events(acao);
	var evento := InputEventKey.new();
	evento.physical_keycode = keycode;
	InputMap.action_add_event(acao, evento);

func _aplicar_todos_os_binds() -> void:
	for acao in binds:
		if InputMap.has_action(acao):
			_aplicar_bind(acao, binds[acao]);


func salvar() -> void:
	var dados := {
		"acessibilidade": acessibilidade,
		"tamanho_fonte": tamanho_fonte,
		"tela_cheia": tela_cheia,
		"volume_sons": volume_sons,
		"volume_musica": volume_musica,
		"volume_narracao": volume_narracao,
		"binds": binds,
	};
	var arquivo := FileAccess.open(CAMINHO_SAVE, FileAccess.WRITE);
	if arquivo == null:
		push_error("Nao consegui salvar config: %s" % error_string(FileAccess.get_open_error()))
		return
	arquivo.store_string(JSON.stringify(dados, "\t"));
	arquivo.close();

func carregar() -> void:
	binds.clear();

	for chave in BINDS_PADRAO:
		binds[chave] = BINDS_PADRAO[chave];

	if FileAccess.file_exists(CAMINHO_SAVE):
		var arquivo := FileAccess.open(CAMINHO_SAVE, FileAccess.READ);
		if arquivo != null:
			var bruto: Variant = JSON.parse_string(arquivo.get_as_text());
			arquivo.close();

			if bruto is Dictionary:
				_ler_dados(bruto);

	_aplicar_todos_os_binds();
	definir_tamanho_fonte(tamanho_fonte);
	_aplicar_volume();

	DisplayServer.window_set_mode(
		DisplayServer.WINDOW_MODE_FULLSCREEN if tela_cheia else DisplayServer.WINDOW_MODE_WINDOWED
	);


func _ler_dados(dados: Dictionary) -> void:
	var acess: Variant = dados.get("acessibilidade")
	if acess is Dictionary:
		for chave in acess:
			acessibilidade[String(chave)] = bool(acess[chave]);

	tamanho_fonte = clampi(int(dados.get("tamanho_fonte", tamanho_fonte)), FONTE_MIN, FONTE_MAX);
	tela_cheia = bool(dados.get("tela_cheia", tela_cheia));
	volume_sons = clampf(float(dados.get("volume_sons", volume_sons)), 0.0, 1.0);
	volume_musica = clampf(float(dados.get("volume_musica", volume_musica)), 0.0, 1.0);
	volume_narracao = clampf(float(dados.get("volume_narracao", volume_narracao)), 0.0, 1.0);

	var b: Variant = dados.get("binds");
	if b is Dictionary:
		for acao in b:
			var nome := String(acao);
			if InputMap.has_action(nome):
				binds[nome] = int(b[acao]);
