class_name ArenaBoss
extends Fase

signal venceu;

@export var boss: Node;
@export var camera: Camera2D;
@export var narracao: Node;
@export var cena_apos_vitoria: String = "res://cenas/menu.tscn";

@export_group("Vitoria")
@export var espera_apos_vitoria: float = 2.0;
@export var texto_vitoria: String = "ELE SOBREVIVEU AO DIA";
@export var zerar_progresso: bool = true;

var _acabou: bool = false;
var _camada: CanvasLayer = null;
var _rotulo: Label = null;
var _marcas: HBoxContainer = null;
var _total: int = 3;


func _ready() -> void:
	super();

	if camera != null and is_instance_valid(camera):
		if jogador != null and is_instance_valid(jogador):
			var propria := jogador.get_node_or_null("Camera2D") as Camera2D;
			if propria != null:
				propria.enabled = false;
		camera.make_current();

	_montar_hud();
	Configuracoes.fonte_alterada.connect(_ao_mudar_fonte);

	if boss != null and is_instance_valid(boss):
		_total = maxi(1, int(boss.get("vida")));
		boss.connect("levou_dano", _ao_dar_dano);
		boss.connect("derrotado", _ao_vencer);

	_atualizar_hud(_total);
	await _esperar_a_narracao();


func _esperar_a_narracao() -> void:
	if boss == null or not is_instance_valid(boss):
		return;
	if narracao == null or not is_instance_valid(narracao):
		return;
	if not narracao.has_method("esta_rodando"):
		return;

	await get_tree().process_frame;
	await get_tree().process_frame;

	if not narracao.call("esta_rodando"):
		return;

	boss.set_physics_process(false);
	await narracao.terminou;
	if is_instance_valid(boss):
		boss.set_physics_process(true);


func _ao_dar_dano(restante: int) -> void:
	_atualizar_hud(restante);
	if camera != null and is_instance_valid(camera) and camera.has_method("sacudir"):
		camera.call("sacudir", 22.0);


func _ao_vencer() -> void:
	if _acabou:
		return;
	_acabou = true;

	_atualizar_hud(0);
	if _rotulo != null and is_instance_valid(_rotulo):
		_rotulo.text = texto_vitoria;

	venceu.emit();

	if jogador != null and is_instance_valid(jogador):
		if jogador.has_method("cancelar_destino"):
			jogador.call("cancelar_destino");
		jogador.set_physics_process(false);

	await get_tree().create_timer(espera_apos_vitoria).timeout;

	if zerar_progresso:
		Progresso.zerar();
		Fases.reiniciar();

	get_tree().call_deferred("change_scene_to_file", cena_apos_vitoria);


func _ao_mudar_fonte(_tamanho: int) -> void:
	_aplicar_fonte();


func _aplicar_fonte() -> void:
	if _rotulo != null and is_instance_valid(_rotulo):
		_rotulo.add_theme_font_size_override("font_size", Configuracoes.tamanho_fonte);


func _montar_hud() -> void:
	_camada = CanvasLayer.new();
	_camada.name = "HudBoss";
	_camada.layer = 80;
	add_child(_camada);

	var caixa := VBoxContainer.new();
	caixa.name = "Caixa";
	caixa.set_anchors_preset(Control.PRESET_CENTER_TOP);
	caixa.grow_horizontal = Control.GROW_DIRECTION_BOTH;
	caixa.offset_top = 24.0;
	caixa.custom_minimum_size = Vector2(420.0, 0.0);
	caixa.add_theme_constant_override("separation", 8);
	caixa.mouse_filter = Control.MOUSE_FILTER_IGNORE;
	_camada.add_child(caixa);

	_rotulo = Label.new();
	_rotulo.name = "Rotulo";
	_rotulo.text = "ENCOSTE NELE";
	_rotulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER;
	_rotulo.mouse_filter = Control.MOUSE_FILTER_IGNORE;
	_rotulo.add_theme_color_override("font_outline_color", Color(0, 0, 0));
	_rotulo.add_theme_constant_override("outline_size", 10);
	caixa.add_child(_rotulo);

	_marcas = HBoxContainer.new();
	_marcas.name = "Marcas";
	_marcas.alignment = BoxContainer.ALIGNMENT_CENTER;
	_marcas.add_theme_constant_override("separation", 12);
	_marcas.mouse_filter = Control.MOUSE_FILTER_IGNORE;
	caixa.add_child(_marcas);

	_aplicar_fonte();


func _atualizar_hud(restante: int) -> void:
	if _marcas == null or not is_instance_valid(_marcas):
		return;

	for filho in _marcas.get_children():
		filho.queue_free();

	for i in _total:
		var marca := ColorRect.new();
		marca.mouse_filter = Control.MOUSE_FILTER_IGNORE;
		marca.custom_minimum_size = Vector2(46.0, 22.0);
		marca.color = Color(1, 1, 1, 0.92) if i < restante else Color(0, 0, 0, 0.35);
		_marcas.add_child(marca);
