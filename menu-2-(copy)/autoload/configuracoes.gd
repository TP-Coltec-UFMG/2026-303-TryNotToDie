extends Node

const CAMINHO_SAVE := "user://config.json"

const REMOVER_ANIMACAO := "remover_animacao"
const ALTO_CONTRASTE := "alto_contraste"

const BINDS_PADRAO := {
	"Left": KEY_A,
	"Right": KEY_D,
	"Jump": KEY_SPACE,
	"Down": KEY_S,
	"Pausa": KEY_TAB,
}

const FONTE_MIN := 12
const FONTE_MAX := 48

signal config_alterada(chave: String, valor: bool)
signal fonte_alterada(tamanho: int)
signal bind_alterado(acao: String, keycode: int)

var acessibilidade: Dictionary[String, bool] = {
	REMOVER_ANIMACAO: false,
	ALTO_CONTRASTE: false,
}
var tamanho_fonte: int = 22
var tela_cheia: bool = false
var binds: Dictionary[String, int] = {}

var _tema: Theme


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_garantir_tema()
	carregar()


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
	fonte_alterada.emit(tamanho_fonte)
	salvar()

func _garantir_tema() -> void:
	var raiz := get_tree().root
	if raiz.theme == null:
		raiz.theme = Theme.new();
	_tema = raiz.theme;

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
	return OS.get_keycode_string(DisplayServer.keyboard_get_keycode_from_physical(keycode))

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

	var b: Variant = dados.get("binds");
	if b is Dictionary:
		for acao in b:
			var nome := String(acao);
			if InputMap.has_action(nome):
				binds[nome] = int(b[acao]);
