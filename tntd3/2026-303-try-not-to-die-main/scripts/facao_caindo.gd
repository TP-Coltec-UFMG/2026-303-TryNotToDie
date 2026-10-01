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
@export var texto_qte: String = "APERTE A! Empurre o facão pra longe dele!";
@export var dica_qte: String = "aperte A (ou clique) antes de encostar nele";
@export var duracao_queda: float = 2.6;
@export var toques: int = 1;

@export_group("Queda")
@export var tempo_de_queda_livre: float = 0.9;
@export var balanco_antes_de_cair: float = 7.0;
@export var escorregoes: int = 3;
@export var tamanho_do_escorregao: float = 4.0;
@export var giro_na_queda: float = 28.0;

@export_group("Anjo do QTE")
@export var anjo_no_qte: bool = true;
@export var anjo_quadros: SpriteFrames;
@export var anjo_animacao: String = "";
@export var anjo_deslocamento: Vector2 = Vector2(-180.0, -70.0);

@export_group("O anjo pega o facao")
@export var anjo_pega_o_facao: bool = true;
@export var pega_no_facao: Vector2 = Vector2(-18.0, 23.0);
@export var item_do_facao: String = "facao";

@export_group("Uma vez so")
@export var id_evento: String = "facao_galpao";

var _rodou: bool = false;
var _jogador: Node2D = null;
var _velocidade_da_queda: float = 0.0;

func _ready() -> void:
	body_entered.connect(_ao_entrar_corpo);

	if Fases.evento_visto(id_evento):
		_rodou = true;
		set_deferred("monitoring", false);
		if not Progresso.tem(_id_do_item()):
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
	queda.tween_method(_passo_da_queda.bind(y0, facao.rotation_degrees), 0.0, duracao_queda, duracao_queda);

	var qte := QTE.tecla(texto_qte, acao_desviar, duracao_queda, toques, dica_qte);
	if anjo_no_qte:
		qte.com_anjo(anjo_quadros, anjo_animacao, anjo_deslocamento);
	else:
		qte.sem_anjo();
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

	if anjo_pega_o_facao:
		await _o_anjo_pega();
		desviou.emit();
		return;

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


func _passo_da_queda(t: float, y0: float, giro0: float) -> void:
	if facao == null or not is_instance_valid(facao):
		return;

	var livre := clampf(tempo_de_queda_livre, 0.05, duracao_queda);
	var solto := duracao_queda - livre;
	var passos := maxi(1, escorregoes);
	var y_solto := y0 + tamanho_do_escorregao * float(passos - 1);

	if t < solto:
		_velocidade_da_queda = 0.0;
		var f := t / maxf(0.01, solto);
		var tremor := 0.0 if _sem_animacao() else sin(t * 26.0) * balanco_antes_de_cair * f * f;
		facao.rotation_degrees = giro0 + tremor;
		facao.global_position.y = y0 + tamanho_do_escorregao * floorf(f * float(passos));
		return;

	var dt := t - solto;
	var gravidade := 2.0 * (altura_do_golpe - y_solto) / (livre * livre);
	facao.global_position.y = y_solto + 0.5 * gravidade * dt * dt;
	_velocidade_da_queda = gravidade * dt;
	facao.rotation_degrees = giro0 + giro_na_queda * (dt / livre);


func _o_anjo_pega() -> void:
	var id := _id_do_item();

	if facao == null or not is_instance_valid(facao):
		Progresso.pegar(id);
		return;

	var pai := facao.get_parent();
	if pai == null:
		pai = self;

	_frear_no_ar();
	var anjo := AnjoAjudante.pegar_no_ar(pai, facao, pega_no_facao, Progresso.pegar.bind(id));
	if anjo == null:
		Progresso.pegar(id);
		facao.queue_free();
		return;

	await anjo.terminou;
	Progresso.pegar(id);


func _frear_no_ar() -> void:
	if _velocidade_da_queda <= 0.0 or _sem_animacao():
		return;
	var tempo := 0.3;
	var distancia := minf(_velocidade_da_queda * tempo * 0.5, maxf(0.0, altura_do_golpe - 70.0 - facao.global_position.y));
	if distancia <= 0.0:
		return;
	var freio := create_tween();
	freio.tween_property(facao, "global_position:y", facao.global_position.y + distancia, tempo)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT);


func _id_do_item() -> String:
	var item := facao as ItemColetavel;
	if item != null and is_instance_valid(item):
		return item.id_item;
	return item_do_facao;


func _acertar(_y0: float) -> void:
	acertou.emit();

	Fases.esquecer_evento(id_evento);

	if _jogador != null and _jogador.has_method("morrer"):
		await _jogador.call("morrer");
	else:
		await get_tree().create_timer(0.8).timeout;

	Fases.voltar_ao_ponto();


func _assentar_no_chao() -> void:
	if facao == null or not is_instance_valid(facao):
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
