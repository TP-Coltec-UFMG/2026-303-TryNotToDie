class_name Porta
extends Area2D

@export_file("*.tscn") var cena_destino: String = "";
@export var entrada_destino: String = "";
@export var apenas_sinaliza: bool = false;
@export var acao_entrar: String = "Down";
@export var entrar_ao_encostar: bool = false;

@export_group("Dica na tela")
@export var dica: String = "S ou clique para entrar";
@export var dica_trancada: String = "Trancada. S ou clique para forcar";
@export var dica_sem_item: String = "Falta a chave";
@export var dica_altura: float = -110.0;

@export_group("Trancada")
@export var trancada: bool = false;
@export var requer_item: String = "";
@export var destrancada: String = "";
@export var abrir_porta: String = "";

@export_group("Arrombar (QTE)")
@export var arrombar_com_qte: bool = false;
@export var texto_qte: String = "ARROMBE A PORTA!";
@export var toques_qte: int = 9;
@export var limite_qte: float = 3.3;

signal recusada(motivo: String);
signal entrou;

var _jogador: Node2D = null;
var _ocupada: bool = false;
var _dica: DicaFlutuante = null;


func _ready() -> void:
	input_pickable = true;
	body_entered.connect(_ao_entrar_corpo);
	body_exited.connect(_ao_sair_corpo);
	input_event.connect(_ao_clicar);

	if destrancada != "" and Progresso.ligado(destrancada):
		trancada = false;

	if not dica.is_empty():
		_dica = DicaFlutuante.criar(_texto_da_dica(), Vector2(0.0, dica_altura));
		add_child(_dica);


func _unhandled_input(event: InputEvent) -> void:
	if _jogador == null or _ocupada:
		return;
	if event.is_action_pressed(acao_entrar):
		abrir();


func _ao_entrar_corpo(corpo: Node2D) -> void:
	if not corpo.is_in_group("jogador"):
		return;
	_jogador = corpo;
	_atualizar_dica(true);
	if entrar_ao_encostar:
		abrir();


func _ao_sair_corpo(corpo: Node2D) -> void:
	if corpo == _jogador:
		_jogador = null;
		_atualizar_dica(false);


func _ao_clicar(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if _ocupada:
		return;
	if not (event is InputEventMouseButton and event.pressed \
			and event.button_index == MOUSE_BUTTON_LEFT):
		return;

	var jogador := get_tree().get_first_node_in_group("jogador");
	if jogador == null or not jogador.has_method("ir_ate"):
		return;

	jogador.call("ir_ate", global_position.x, Callable(self, "abrir"));


func abrir() -> void:
	if _ocupada:
		return;

	if requer_item != "" and not Progresso.tem(requer_item):
		recusada.emit("sem_item");
		_atualizar_dica(_jogador != null);
		return;

	if trancada:
		if not arrombar_com_qte:
			recusada.emit("trancada");
			return;

		_ocupada = true;
		var qte := QTE.martelar(texto_qte, limite_qte, toques_qte);
		add_child(qte);
		var venceu: bool = await qte.terminou;
		_ocupada = false;

		if not venceu:
			recusada.emit("qte_falhou");
			return;

		trancada = false;
		_atualizar_dica(_jogador != null);

	_entrar();


func _entrar() -> void:
	if _ocupada:
		return;

	if abrir_porta != "":
		Progresso.ligar(abrir_porta);

	entrou.emit();

	if apenas_sinaliza:
		_atualizar_dica(false);
		return;

	if cena_destino.is_empty():
		push_warning("Porta '%s' sem cena_destino definida." % name);
		return;

	_ocupada = true;
	Fases.ir_para(cena_destino, entrada_destino);


func _texto_da_dica() -> String:
	if requer_item != "" and not Progresso.tem(requer_item):
		return dica_sem_item;
	if trancada:
		return dica_trancada;
	return dica;


func _atualizar_dica(mostrar: bool) -> void:
	if _dica == null:
		return;
	_dica.definir_texto(_texto_da_dica());
	_dica.mostrar(mostrar);
