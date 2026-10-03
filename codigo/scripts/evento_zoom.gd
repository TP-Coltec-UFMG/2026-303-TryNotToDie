class_name EventoZoom
extends Area2D

@export var alvo: Node2D;
@export var camera: Camera2D;

@export_group("Uma vez so")
@export var id_evento: String = "zoom_casa";
@export var lembrar_entre_fases: bool = true;

@export_group("Tempos")
@export var duracao_afastar: float = 1.2;
@export var duracao_segurar: float = 1.6;
@export var duracao_voltar: float = 1.0;

@export_group("Enquadramento")
@export var margem: float = 60.0;
@export var zoom_minimo: float = 0.15;

signal comecou;
signal terminou;

var _rodando: bool = false;
var _ja_rodou: bool = false;


func _ready() -> void:
	body_entered.connect(_ao_entrar_corpo);

	if lembrar_entre_fases and Fases.evento_visto(id_evento):
		_ja_rodou = true;
		set_deferred("monitoring", false);


func _ao_entrar_corpo(corpo: Node2D) -> void:
	if _rodando or _ja_rodou:
		return;
	if not corpo.is_in_group("jogador"):
		return;
	disparar(corpo);


func disparar(jogador: Node2D) -> void:
	if _rodando or _ja_rodou:
		return;

	var cam := camera;
	if cam == null:
		cam = _achar_camera(jogador);

	if cam == null or alvo == null:
		get_tree().quit();

	_ja_rodou = true;
	set_deferred("monitoring", false);
	if lembrar_entre_fases:
		Fases.marcar_evento(id_evento);

	_rodando = true;
	comecou.emit();
	await _executar(cam, jogador);
	_rodando = false;
	terminou.emit();


func _executar(cam: Camera2D, jogador: Node2D) -> void:
	var caixa := _caixa_global(alvo);
	if caixa.size == Vector2.ZERO:
		push_warning("nenhum sprite visivel em '%s'." % alvo.name);
		return;

	var zoom_original := cam.zoom;
	var local_original := cam.position;
	var suavizacao := cam.position_smoothing_enabled;

	var destino_pos := caixa.get_center();
	var destino_zoom := _zoom_para_caber(caixa, zoom_original.x);

	_travar(jogador, true);

	var global_antes := cam.global_position;
	cam.position_smoothing_enabled = false;
	cam.top_level = true;
	cam.global_position = global_antes;

	if Configuracoes.config_ativa(Configuracoes.REMOVER_ANIMACAO):
		cam.global_position = destino_pos;
		cam.zoom = destino_zoom;
		await get_tree().create_timer(duracao_segurar).timeout;
	else:
		var ida := create_tween().set_parallel();
		ida.tween_property(cam, "global_position", destino_pos, duracao_afastar)\
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT);
		ida.tween_property(cam, "zoom", destino_zoom, duracao_afastar)\
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT);
		await ida.finished;

		await get_tree().create_timer(duracao_segurar).timeout;

		var volta := create_tween().set_parallel();
		volta.tween_property(cam, "global_position",
				jogador.global_position + local_original, duracao_voltar)\
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT);
		volta.tween_property(cam, "zoom", zoom_original, duracao_voltar)\
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT);
		await volta.finished;

	cam.top_level = false;
	cam.position = local_original;
	cam.zoom = zoom_original;
	cam.position_smoothing_enabled = suavizacao;
	cam.reset_smoothing();

	_travar(jogador, false);

func _travar(jogador: Node2D, travar: bool) -> void:
	if jogador == null:
		return;

	if travar and jogador.has_method("cancelar_destino"):
		jogador.call("cancelar_destino");

	var corpo := jogador as CharacterBody2D;
	if corpo != null and travar:
		corpo.velocity = Vector2.ZERO;

	jogador.set_physics_process(not travar);
	jogador.set_process_unhandled_input(not travar);


func _zoom_para_caber(caixa: Rect2, teto: float) -> Vector2:
	var tela := get_viewport_rect().size;
	var tamanho := caixa.size + Vector2(margem, margem) * 2.0;

	var z := minf(tela.x / tamanho.x, tela.y / tamanho.y);

	return Vector2.ONE * clampf(z, zoom_minimo, teto);


func _caixa_global(raiz: Node) -> Rect2:
	var caixa := Rect2();
	var achou := false;

	for no in _sprites_de(raiz):
		var tamanho := _tamanho_de(no);
		if tamanho == Vector2.ZERO:
			continue;

		var canto := _canto_local(no, tamanho);
		var t := no.global_transform;
		var cantos: Array[Vector2] = [
			canto,
			canto + Vector2(tamanho.x, 0.0),
			canto + tamanho,
			canto + Vector2(0.0, tamanho.y),
		];

		for c in cantos:
			var g: Vector2 = t * c;
			if achou:
				caixa = caixa.expand(g);
			else:
				caixa = Rect2(g, Vector2.ZERO);
				achou = true;

	return caixa;


func _canto_local(no: Node2D, tamanho: Vector2) -> Vector2:
	var canto := Vector2.ZERO;

	var sp := no as Sprite2D;
	if sp != null:
		if sp.centered:
			canto = -tamanho * 0.5;
		return canto + sp.offset;

	var anim := no as AnimatedSprite2D;
	if anim != null:
		if anim.centered:
			canto = -tamanho * 0.5;
		return canto + anim.offset;

	return canto;


func _sprites_de(raiz: Node) -> Array[Node2D]:
	var saida: Array[Node2D] = [];
	_coletar_sprites(raiz, saida);
	return saida;


func _coletar_sprites(no: Node, saida: Array[Node2D]) -> void:
	if no is Sprite2D or no is AnimatedSprite2D:
		var item := no as CanvasItem;
		if item.is_visible_in_tree():
			saida.append(no);

	for filho in no.get_children():
		_coletar_sprites(filho, saida);


func _tamanho_de(no: Node2D) -> Vector2:
	var sp := no as Sprite2D;
	if sp != null:
		if sp.texture == null:
			return Vector2.ZERO;
		return sp.region_rect.size if sp.region_enabled else sp.texture.get_size();

	var anim := no as AnimatedSprite2D;
	if anim != null:
		var frames := anim.sprite_frames;
		if frames == null or not frames.has_animation(anim.animation):
			return Vector2.ZERO;
		var tex := frames.get_frame_texture(anim.animation, anim.frame);
		return Vector2.ZERO if tex == null else tex.get_size();

	return Vector2.ZERO;


func _achar_camera(jogador: Node2D) -> Camera2D:
	if jogador == null:
		return null;
	for filho in jogador.get_children():
		if filho is Camera2D:
			return filho;
	return null;
