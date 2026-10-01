extends CanvasLayer

var fade: ColorRect;
var _trocando: bool = false;

func _ready() -> void:
	layer = 64 * 64;

	fade = ColorRect.new();
	fade.mouse_filter = Control.MOUSE_FILTER_IGNORE;
	fade.color = Color.BLACK;
	fade.modulate.a = 0.0;
	fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);
	add_child(fade);

func sem_animacao() -> bool:
	return Configuracoes.config_ativa(Configuracoes.REMOVER_ANIMACAO);

func fade_out() -> void:
	if sem_animacao():
		return;
	var tween := create_tween();
	tween.tween_property(fade, "modulate:a", 1.0, 0.5);
	await tween.finished;

func fade_in() -> void:
	if sem_animacao():
		return;
	var tween := create_tween();
	tween.tween_property(fade, "modulate:a", 0.0, 0.5);
	await tween.finished;

func trocar_cena(caminho: String) -> void:
	if _trocando:
		return;
	_trocando = true;
	await fade_out();
	get_tree().call_deferred("change_scene_to_file", caminho);
	await get_tree().process_frame;
	await get_tree().process_frame;
	await fade_in();
	_trocando = false;
