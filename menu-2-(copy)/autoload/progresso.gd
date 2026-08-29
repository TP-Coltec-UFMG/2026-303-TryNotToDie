extends Node

signal item_pego(id: String);
signal flag_mudou(id: String, valor: bool);


const PA := "pa";
const CHAVE_GALPAO := "chave_galpao";
const FACAO := "facao";

const PORTA_CASA_ARROMBADA := "porta_casa_arrombada";
const GELADEIRA_DESENTERRADA := "geladeira_desenterrada";
const C3_CAIU := "c3_caiu";
const GALPAO_ABERTO := "galpao_aberto";

var _itens: Dictionary = {};
var _flags: Dictionary = {};


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS;


func tem(id: String) -> bool:
	return _itens.has(id);


func pegar(id: String) -> void:
	if _itens.has(id):
		return;
	_itens[id] = true;
	item_pego.emit(id);


func largar(id: String) -> void:
	_itens.erase(id);


func itens() -> Array:
	return _itens.keys();


func ligado(id: String) -> bool:
	return _flags.get(id, false);


func ligar(id: String, valor: bool = true) -> void:
	if _flags.get(id, false) == valor:
		return;
	_flags[id] = valor;
	flag_mudou.emit(id, valor);


func zerar() -> void:
	_itens.clear();
	_flags.clear();
	Fases.esquecer_eventos();
