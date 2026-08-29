class_name Desabamento
extends Node2D

signal terminou;

@export var casa: Node2D;
@export var comodo: String = "C3";
@export var pontos_queda: Node;

@export_group("Chave")
@export var chave_no_teto: Node2D;
@export var id_chave: String = "chave_galpao";
@export var textura_chave: Texture2D;
@export var escala_chave: Vector2 = Vector2(0.45, 0.45);
@export var hitbox_chave: Vector2 = Vector2(70, 70);

@export_group("Queda")
@export var duracao_queda: float = 1.1;
@export var giro_queda: float = 72.0;
@export var deriva_queda: Vector2 = Vector2(-70.0, 1400.0);
@export_range(0.0, 1.0) var inicio_do_sumico: float = 0.55;

@export_group("Tempos")
@export var duracao_voo_chave: float = 1.2;
@export var forca_tremor: float = 55.0;

var _rodou: bool = false;


func _ready() -> void:
	if Progresso.ligado(Progresso.C3_CAIU):
		_rodou = true;
		var no := _pegar_comodo();
		if no != null:
			no.queue_free();
		if chave_no_teto != null:
			chave_no_teto.queue_free();


func executar() -> void:
	if _rodou:
		return;
	_rodou = true;

	var no := _pegar_comodo();
	if no == null:
		terminou.emit();
		return;

	var origem_chave := no.global_position + Vector2(0.0, -260.0);
	if chave_no_teto != null and is_instance_valid(chave_no_teto):
		origem_chave = chave_no_teto.global_position;
		chave_no_teto.queue_free();

	_sacudir();
	
	await _derrubar(no);
	await _soltar_chave(origem_chave);

	Progresso.ligar(Progresso.C3_CAIU);
	terminou.emit();


func _pegar_comodo() -> Node2D:
	if casa == null:
		return null;
	if casa.has_method("soltar_comodo"):
		var no: Node2D = casa.call("soltar_comodo", comodo);
		if no != null:
			return no;
	return casa.get_node_or_null(comodo) as Node2D;


func _derrubar(no: Node2D) -> void:
	for filho in no.get_children():
		if filho is CollisionShape2D:
			filho.set_deferred("disabled", true);

	if _sem_animacao():
		no.queue_free();
		return;

	var corpo := no as AnimatableBody2D;
	if corpo != null:
		corpo.sync_to_physics = false;

	var origem := no.position;
	var giro := no.rotation_degrees;

	var tween := create_tween().set_parallel();
	tween.tween_method(
		func(p: float) -> void:
			if not is_instance_valid(no):
				return;
			var e := p * p;
			no.position = origem + deriva_queda * e;
			no.rotation_degrees = giro + giro_queda * e,
		0.0, 1.0, duracao_queda
	);
	tween.tween_property(no, "modulate:a", 0.0, duracao_queda * (1.0 - inicio_do_sumico))\
		.set_delay(duracao_queda * inicio_do_sumico);

	await tween.finished;

	no.queue_free();


func _soltar_chave(origem: Vector2) -> void:
	var destino := _sortear_ponto();

	if Progresso.tem(id_chave):
		return;

	var chave := _montar_chave();
	chave.global_position = origem;

	var pai := get_parent();
	if pai == null:
		pai = self;
	pai.add_child(chave);
	chave.global_position = origem;

	if _sem_animacao() or destino == origem:
		chave.global_position = destino;
		_assentar(chave);
		return;

	var altura := 240.0;
	var tween := create_tween();
	tween.tween_method(
		func(p: float) -> void:
			if not is_instance_valid(chave):
				return
			chave.global_position = origem.lerp(destino, p) \
				+ Vector2(0.0, -altura * sin(p * PI)),
		0.0, 1.0, duracao_voo_chave
	);
	tween.parallel().tween_property(chave, "rotation_degrees", 720.0,
		duracao_voo_chave * 0.7);
	await tween.finished;

	if not is_instance_valid(chave):
		return;

	chave.rotation_degrees = 0.0;
	_assentar(chave);


func _assentar(chave: ItemColetavel) -> void:
	if not is_instance_valid(chave):
		return;
	chave.flutuar = true;
	chave.ancorar();
	chave.set_deferred("monitoring", true);


func _sortear_ponto() -> Vector2:
	var opcoes: Array[Marker2D] = [];
	if pontos_queda != null:
		for filho in pontos_queda.get_children():
			if filho is Marker2D:
				opcoes.append(filho);

	if opcoes.is_empty():
		push_warning("Desabamento sem pontos de queda: a chave cai no proprio no.");
		return global_position;

	return opcoes[randi() % opcoes.size()].global_position;


func _montar_chave() -> ItemColetavel:
	var item := ItemColetavel.new();
	item.name = "Chave";
	item.id_item = id_chave;
	item.flutuar = false;
	item.monitoring = false;

	var sprite := Sprite2D.new();
	sprite.texture = textura_chave;
	sprite.scale = escala_chave;
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST;
	item.add_child(sprite);

	var forma := RectangleShape2D.new();
	forma.size = hitbox_chave;
	var colisao := CollisionShape2D.new();
	colisao.shape = forma;
	item.add_child(colisao);

	return item;


func _sacudir() -> void:
	var jogador := get_tree().get_first_node_in_group("jogador");
	if jogador == null:
		return;
	for filho in jogador.get_children():
		if filho.has_method("sacudir"):
			filho.call("sacudir", forca_tremor);
			return;


func _sem_animacao() -> bool:
	return Configuracoes.config_ativa(Configuracoes.REMOVER_ANIMACAO);
