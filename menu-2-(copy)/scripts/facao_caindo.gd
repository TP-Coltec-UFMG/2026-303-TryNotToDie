class_name FacaoCaindo
extends Area2D

signal desviou;
signal acertou;

@export var facao: Node2D;
@export var altura_do_golpe: float = 340.0;
@export var altura_de_repouso: float = 428.0;
@export var desvio_lateral: float = 240.0;

@export_group("QTE")
@export var acao_desviar: String = "Left";
@export var texto_qte: String = "APERTE A! Empurre o facao pra longe dele!";
@export var dica_qte: String = "aperte A (ou clique) antes de encostar nele";
@export var duracao_queda: float = 2.6;
@export var toques: int = 1;

@export_group("Uma vez so")
@export var id_evento: String = "facao_galpao";

var _rodou: bool = false;
var _jogador: Node2D = null;

func _ready() -> void:
	body_entered.connect(_ao_entrar_corpo);

	if Fases.evento_visto(id_evento):
		_rodou = true;
		set_deferred("monitoring", false);
		_assentar_no_chao();


func _ao_entrar_corpo(corpo: Node2D) -> void:
	if _rodou or not corpo.is_in_group("jogador"):
		return;
	_jogador = corpo;
	_rodou = true;
	set_deferred("monitoring", false);
	_executar();


func _executar() -> void:
	if facao == null:
		push_warning("FacaoCaindo '%s' sem facao definido." % name);
		return;

	var x0 := facao.global_position.x;
	var y0 := facao.global_position.y;

	var queda := create_tween();
	queda.tween_property(facao, "global_position:y", altura_do_golpe, duracao_queda)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN);

	var qte := QTE.tecla(texto_qte, acao_desviar, duracao_queda, toques, dica_qte);
	add_child(qte);
	var venceu: bool = await qte.terminou;

	if is_instance_valid(queda):
		queda.kill();

	if venceu:
		await _desviar(x0);
	else:
		await _acertar(y0);


func _desviar(x0: float) -> void:
	Fases.marcar_evento(id_evento);

	if not _sem_animacao():
		var t := create_tween();
		t.set_parallel();
		t.tween_property(facao, "global_position:x", x0 + desvio_lateral, 0.55)\
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT);
		t.tween_property(facao, "global_position:y", altura_de_repouso, 0.55)\
			.set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT);
		t.tween_property(facao, "rotation_degrees", 96.0, 0.55);
		await t.finished;
	else:
		facao.global_position = Vector2(x0 + desvio_lateral, altura_de_repouso);
		facao.rotation_degrees = 96.0;

	_liberar_para_pegar();
	desviou.emit();


func _acertar(_y0: float) -> void:
	acertou.emit();

	Fases.esquecer_evento(id_evento);

	if _jogador != null and _jogador.has_method("morrer"):
		await _jogador.call("morrer");
	else:
		await get_tree().create_timer(0.8).timeout;

	Fases.voltar_ao_ponto();


func _assentar_no_chao() -> void:
	if facao == null:
		return;
	facao.global_position = Vector2(
		facao.global_position.x + desvio_lateral,
		altura_de_repouso
	);
	facao.rotation_degrees = 96.0;
	_liberar_para_pegar();


func _liberar_para_pegar() -> void:
	var item := facao as ItemColetavel;
	if item == null:
		return;
	item.flutuar = false;
	item.ancorar();
	item.set_deferred("monitoring", true);


func _sem_animacao() -> bool:
	return Configuracoes.config_ativa(Configuracoes.REMOVER_ANIMACAO);
