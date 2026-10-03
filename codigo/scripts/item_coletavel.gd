class_name ItemColetavel
extends Area2D

signal coletado(id: String);

@export var id_item: String = "pa";
@export var sumir_ao_pegar: bool = true;
@export var requer_flag: String = "";
@export var flutuar: bool = true;
@export var flutuar_altura: float = 6.0;
@export var flutuar_periodo: float = 1.8;

var _y_base: float = 0.0;
var _tempo: float = 0.0;
var _pego: bool = false;


func _ready() -> void:
	if Progresso.tem(id_item):
		queue_free();
		return;

	body_entered.connect(_ao_encostar);
	ancorar();

	if requer_flag != "":
		Progresso.flag_mudou.connect(_ao_mudar_flag);
		_aplicar_visibilidade(Progresso.ligado(requer_flag));


func ancorar() -> void:
	_y_base = position.y;
	_tempo = 0.0;
	set_process(flutuar and not _sem_animacao());


func _process(delta: float) -> void:
	_tempo += delta;
	var sobe := (1.0 - cos(_tempo * TAU / maxf(0.05, flutuar_periodo))) * 0.5;
	position.y = _y_base - sobe * flutuar_altura;


func _ao_encostar(corpo: Node2D) -> void:
	if _pego or not corpo.is_in_group("jogador"):
		return;

	_pego = true;
	Progresso.pegar(id_item);
	coletado.emit(id_item);

	set_deferred("monitoring", false);

	if sumir_ao_pegar:
		_sumir();


func _sumir() -> void:
	if _sem_animacao():
		queue_free();
		return;

	var tween := create_tween().set_parallel();
	tween.tween_property(self, "scale", scale * 1.6, 0.25)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT);
	tween.tween_property(self, "modulate:a", 0.0, 0.25);
	tween.chain().tween_callback(queue_free);


func _ao_mudar_flag(id: String, valor: bool) -> void:
	if id == requer_flag:
		_aplicar_visibilidade(valor);


func _aplicar_visibilidade(mostrar: bool) -> void:
	visible = mostrar;
	set_deferred("monitoring", mostrar);


func _sem_animacao() -> bool:
	return Configuracoes.config_ativa(Configuracoes.REMOVER_ANIMACAO);
