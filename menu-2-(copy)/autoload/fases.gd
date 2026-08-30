extends Node

signal fase_trocada(caminho: String);

var proxima_entrada: String = "";

var fase_atual: String = "";

var _retorno_cena: String = "";
var _retorno_entrada: String = "";


func _ready() -> void:
	
	process_mode = Node.PROCESS_MODE_ALWAYS;


func ir_para(caminho: String, entrada: String = "") -> void:
	
	if caminho.is_empty():
		push_warning("Fases.ir_para chamado sem caminho de cena.");
		return;

	if not ResourceLoader.exists(caminho):
		push_error("Fase inexistente: %s" % caminho);
		return;

	proxima_entrada = entrada;
	fase_atual = caminho;
	_retorno_cena = caminho;
	_retorno_entrada = entrada;
	fase_trocada.emit(caminho);

	get_tree().call_deferred("change_scene_to_file", caminho);


var _eventos_vistos: Dictionary = {};


func evento_visto(id: String) -> bool:
	return _eventos_vistos.has(id);


func marcar_evento(id: String) -> void:
	_eventos_vistos[id] = true;


func esquecer_evento(id: String) -> void:
	_eventos_vistos.erase(id);


func marcar_ponto(entrada: String) -> void:
	if fase_atual != "":
		_retorno_cena = fase_atual;
	_retorno_entrada = entrada;


func voltar_ao_ponto() -> void:
	if _retorno_cena.is_empty():
		proxima_entrada = _retorno_entrada;
		get_tree().call_deferred("reload_current_scene");
		return;
	ir_para(_retorno_cena, _retorno_entrada);


func esquecer_eventos() -> void:
	_eventos_vistos.clear();


func consumir_entrada() -> String:
	var entrada := proxima_entrada;
	proxima_entrada = "";
	return entrada;
