class_name Leitor
extends Node

signal falou(texto: String)

const ESPERA_VALOR := 0.25

static var _instancia: Leitor = null

var _disponivel: bool = false
var _voz: String = ""
var _prefixo: String = ""
var _valor_pendente: String = ""
var _espera_valor: float = 0.0


static func instancia() -> Leitor:
	return _instancia


static func disponivel() -> bool:
	return _instancia != null and _instancia._disponivel


static func ativo() -> bool:
	return Configuracoes.volume_narracao > 0.001


static func falar(texto: String, interromper: bool = true) -> void:
	if _instancia != null:
		_instancia._falar(texto, interromper)


static func calar() -> void:
	if _instancia != null:
		_instancia._calar()


static func esta_falando() -> bool:
	return disponivel() and ativo() and DisplayServer.tts_is_speaking()


static func anunciar(titulo: String) -> void:
	if _instancia != null:
		_instancia._prefixo = titulo


static func descrever(controle: Control) -> String:
	if controle == null:
		return ""
	if controle.has_meta("fala"):
		return str(controle.get_meta("fala"))

	var partes: Array[String] = []
	var rotulo := _rotulo_vizinho(controle)
	if not rotulo.is_empty():
		partes.append(rotulo)

	if controle is Range:
		partes.append(_valor_falado(controle as Range))
	elif controle is BaseButton:
		var botao := controle as BaseButton
		var texto := str(botao.get("text"))
		if not texto.is_empty() and texto != rotulo:
			partes.append(texto)
		if botao.toggle_mode:
			partes.append("ligado" if botao.button_pressed else "desligado")
	elif "text" in controle:
		partes.append(str(controle.get("text")))

	return ", ".join(partes)


func _enter_tree() -> void:
	_instancia = self


func _exit_tree() -> void:
	if _instancia == self:
		_instancia = null


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_disponivel = bool(ProjectSettings.get_setting("audio/general/text_to_speech", false)) \
		and DisplayServer.has_feature(DisplayServer.FEATURE_TEXT_TO_SPEECH)
	if _disponivel:
		_disponivel = not DisplayServer.tts_get_voices().is_empty()
	if _disponivel:
		_voz = _escolher_voz()
	get_viewport().gui_focus_changed.connect(_ao_mudar_foco)
	Configuracoes.volume_narracao_alterado.connect(_ao_mudar_volume)


func _process(delta: float) -> void:
	if _valor_pendente.is_empty():
		return
	_espera_valor -= delta
	if _espera_valor <= 0.0:
		var texto := _valor_pendente
		_valor_pendente = ""
		_falar(texto, true)


func _falar(texto: String, interromper: bool) -> void:
	var limpo := _limpar(texto)
	if limpo.is_empty() or not ativo():
		return
	falou.emit(limpo)
	if _disponivel:
		var volume := roundi(Configuracoes.volume_narracao * 100.0)
		DisplayServer.tts_speak(limpo, _voz, volume, 1.0, 1.0, 0, interromper)


func _calar() -> void:
	_valor_pendente = ""
	if _disponivel:
		DisplayServer.tts_stop()


func _ao_mudar_foco(controle: Control) -> void:
	var texto := descrever(controle)
	if not _prefixo.is_empty():
		texto = _prefixo + ". " + texto
		_prefixo = ""
	if _leitor_de_tela_ativo():
		return
	_ligar_sinais(controle)
	_falar(texto, true)


func _ligar_sinais(controle: Control) -> void:
	if controle == null or controle.has_meta("leitor_ligado"):
		return
	controle.set_meta("leitor_ligado", true)
	if controle is Range:
		(controle as Range).value_changed.connect(_ao_mudar_valor.bind(controle))
	elif controle is BaseButton and (controle as BaseButton).toggle_mode:
		(controle as BaseButton).toggled.connect(_ao_alternar.bind(controle))


func _ao_mudar_valor(_valor: float, controle: Range) -> void:
	if not controle.has_focus() or _leitor_de_tela_ativo():
		return
	_valor_pendente = _valor_falado(controle)
	_espera_valor = ESPERA_VALOR


func _ao_alternar(ligado: bool, controle: BaseButton) -> void:
	if not controle.has_focus() or _leitor_de_tela_ativo():
		return
	_falar("ligado" if ligado else "desligado", true)


func _ao_mudar_volume(valor: float) -> void:
	if valor <= 0.001:
		_calar()


static func _rotulo_vizinho(controle: Control) -> String:
	var pai := controle.get_parent()
	if pai == null:
		return ""
	var indice := controle.get_index()
	if indice <= 0:
		return ""
	var anterior := pai.get_child(indice - 1) as Label
	if anterior != null and anterior.visible:
		return anterior.text
	return ""


static func _valor_falado(controle: Range) -> String:
	var valor := roundi(controle.value)
	if is_zero_approx(controle.min_value) and is_equal_approx(controle.max_value, 100.0):
		return "%d por cento" % valor
	return str(valor)


static func _limpar(texto: String) -> String:
	return texto.replace("\n", " ").strip_edges().to_lower()


static func _leitor_de_tela_ativo() -> bool:
	return DisplayServer.accessibility_screen_reader_active() == 1


func _escolher_voz() -> String:
	var vozes := DisplayServer.tts_get_voices()
	var portugues := ""
	for voz in vozes:
		var idioma := str(voz.get("language", "")).to_lower().replace("-", "_")
		if idioma == "pt_br":
			return str(voz.get("id", ""))
		if portugues.is_empty() and idioma.begins_with("pt"):
			portugues = str(voz.get("id", ""))
	if not portugues.is_empty():
		return portugues
	if not vozes.is_empty():
		return str(vozes[0].get("id", ""))
	return ""
