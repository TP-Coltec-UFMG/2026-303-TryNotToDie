class_name Geladeira
extends StaticBody2D

signal recusada(motivo: String);
signal desenterrada;
signal arremessada;
signal esmagou;

@export var alvo_arremesso: Node2D;
@export var desabamento: Node;
@export var acao_interagir: String = "Down";
@export var item_necessario: String = "pa";

@export_group("Dica na tela")
@export var dica: String = "S ou clique para ele cavar";
@export var dica_sem_item: String = "Enterrada demais. Ele precisa de uma pa";
@export var dica_altura: float = -140.0;

@export_group("Cavar e levantar")
@export var duracao_cavar: float = 1.1;
@export var altura_sobre_a_cabeca: float = 140.0;
@export var afundar_maximo: float = 30.0;

@export_group("QTE")
@export var texto_qte: String = "Ele vai se esmagar com a geladeira!";
@export var dica_qte: String = "segure uma tecla ou o botao do mouse";
@export var segundos_segurando: float = 2.2;
@export var limite_qte: float = 3.5;

@export_group("Arremesso")
@export var duracao_voo: float = 0.9;
@export var altura_arco: float = 320.0;

@export_group("Esmagar")
@export var duracao_queda: float = 0.26;

var _jogador: Node2D = null;
var _ocupada: bool = false;
var _dica: DicaFlutuante = null;
var _qte: QTE = null;


func _ready() -> void:
	set_process(false);
	input_pickable = true;
	input_event.connect(_ao_clicar);

	var area := get_node_or_null("AreaInteracao") as Area2D;
	if area != null:
		area.body_entered.connect(_ao_entrar_corpo);
		area.body_exited.connect(_ao_sair_corpo);

	if Progresso.ligado(Progresso.GELADEIRA_DESENTERRADA):
		queue_free();
		return;

	if not dica.is_empty():
		_dica = DicaFlutuante.criar(_texto_da_dica(), Vector2(0.0, dica_altura));
		add_child(_dica);


func _process(_delta: float) -> void:
	if _qte == null or not is_instance_valid(_qte) or _jogador == null:
		return;

	var p := _qte.progresso_atual();
	var altura := lerpf(altura_sobre_a_cabeca - afundar_maximo, altura_sobre_a_cabeca, p);
	global_position = Vector2(
		_jogador.global_position.x,
		_jogador.global_position.y - altura
	);


func _unhandled_input(event: InputEvent) -> void:
	if _jogador == null or _ocupada:
		return;
	if event.is_action_pressed(acao_interagir):
		interagir();


func _ao_entrar_corpo(corpo: Node2D) -> void:
	if not corpo.is_in_group("jogador"):
		return;
	_jogador = corpo;
	_atualizar_dica(true);


func _ao_sair_corpo(corpo: Node2D) -> void:
	if corpo == _jogador and not _ocupada:
		_jogador = null;
		_atualizar_dica(false);


func _ao_clicar(_viewport: Node, event: InputEvent, _shape: int) -> void:
	if _ocupada:
		return;
	if not (event is InputEventMouseButton and event.pressed \
			and event.button_index == MOUSE_BUTTON_LEFT):
		return;

	var jogador := get_tree().get_first_node_in_group("jogador");
	if jogador == null or not jogador.has_method("ir_ate"):
		return;

	jogador.call("ir_ate", global_position.x, Callable(self, "interagir"));


func interagir() -> void:
	if _ocupada:
		return;

	if not Progresso.tem(item_necessario):
		recusada.emit("sem_item");
		_atualizar_dica(_jogador != null);
		return;

	if _jogador == null:
		_jogador = get_tree().get_first_node_in_group("jogador") as Node2D;
	if _jogador == null:
		return;

	_ocupada = true;
	_apagar_dica();

	await _levantar();
	desenterrada.emit();

	_qte = QTE.segurar(texto_qte, segundos_segurando, limite_qte);
	_qte.dica_personalizada = dica_qte;
	add_child(_qte);
	set_process(true);

	var venceu: bool = await _qte.terminou;
	_qte = null;
	set_process(false);

	if venceu:
		await _arremessar();
	else:
		await _esmagar();


func _levantar() -> void:
	set_deferred("input_pickable", false);
	for filho in get_children():
		if filho is CollisionShape2D:
			filho.set_deferred("disabled", true);

	var area := get_node_or_null("AreaInteracao") as Area2D;
	if area != null:
		area.set_deferred("monitoring", false);

	var destino := Vector2(
		_jogador.global_position.x,
		_jogador.global_position.y - (1.25 * altura_sobre_a_cabeca)
	);

	if _sem_animacao():
		global_position = destino;
		rotation = 0.0;
		return;

	var tween := create_tween();
	tween.set_parallel();
	tween.tween_property(self, "global_position", destino, duracao_cavar)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT);
	tween.tween_property(self, "rotation", 0.0, duracao_cavar)\
		.set_trans(Tween.TRANS_SINE);
	await tween.finished;


func _arremessar() -> void:
	Progresso.ligar(Progresso.GELADEIRA_DESENTERRADA);

	var destino := global_position;
	if alvo_arremesso != null:
		destino = alvo_arremesso.global_position;

	if not _sem_animacao() and destino != global_position:
		var origem := global_position;
		var arco := altura_arco;
		var tween := create_tween();
		tween.tween_method(
			func(p: float) -> void:
				global_position = origem.lerp(destino, p) + Vector2(0.0, -arco * sin(p * PI)),
			0.0,
			1.0,
			duracao_voo
		);
		tween.parallel().tween_property(self, "rotation_degrees", rotation_degrees + 220.0, duracao_voo);
		await tween.finished;

	arremessada.emit();

	if desabamento != null and desabamento.has_method("executar"):
		await desabamento.call("executar");

	queue_free();


func _esmagar() -> void:
	esmagou.emit();

	_jogador.set_physics_process(false);
	_jogador.set_process_unhandled_input(false);
	if _jogador.has_method("cancelar_destino"):
		_jogador.call("cancelar_destino");

	if not _sem_animacao():
		var tween := create_tween();
		tween.tween_property(self, "global_position:y", _jogador.global_position.y + 14.0, duracao_queda)\
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN);
		await tween.finished;

	if _jogador.has_method("morrer"):
		await _jogador.call("morrer");
	else:
		await get_tree().create_timer(0.8).timeout;

	Fases.voltar_ao_ponto();


func _texto_da_dica() -> String:
	return dica if Progresso.tem(item_necessario) else dica_sem_item;


func _atualizar_dica(mostrar: bool) -> void:
	if _dica == null or not is_instance_valid(_dica):
		return;
	_dica.definir_texto(_texto_da_dica());
	_dica.mostrar(mostrar);


func _apagar_dica() -> void:
	if _dica != null and is_instance_valid(_dica):
		_dica.queue_free();
	_dica = null;


func _sem_animacao() -> bool:
	return Configuracoes.config_ativa(Configuracoes.REMOVER_ANIMACAO);
