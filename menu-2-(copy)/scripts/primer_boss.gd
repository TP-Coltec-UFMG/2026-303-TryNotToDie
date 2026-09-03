class_name PrimerBoss
extends Area2D

enum Estado { OCULTO, APARECENDO, MIRANDO, DISPARANDO, VULNERAVEL, SUMINDO };

signal levou_dano(restante: int);
signal derrotado;
signal atirou;

@export var sprite_boss: Node2D;
@export var feixe: Area2D;
@export var sprite_feixe: Node2D;
@export var pontos: Node;
@export var vida: int = 3;

@export_group("Tempos")
@export var t_oculto: float = 0.6;
@export var t_aparecendo: float = 0.35;
@export var t_mirando: float = 0.75;
@export var t_disparando: float = 0.5;
@export var t_vulneravel: float = 1.5;
@export var t_sumindo: float = 0.3;

@export_group("Feixe")
@export var espessura_mira: float = 0.16;
@export var espessura_tiro: float = 1.0;
@export var alpha_mira: float = 0.4;
@export var alpha_tiro: float = 0.95;

var _estado: int = Estado.OCULTO;
var _tempo: float = 0.0;
var _vivo: bool = true;
var _matando: bool = false;
var _jogador: Node2D = null;
var _ultimo_ponto: int = -1;
var _escala_boss: Vector2 = Vector2.ONE;
var _escala_feixe: Vector2 = Vector2.ONE;


func _ready() -> void:
	body_entered.connect(_ao_tocar);

	if sprite_boss != null and is_instance_valid(sprite_boss):
		_escala_boss = sprite_boss.scale;
	if sprite_feixe != null and is_instance_valid(sprite_feixe):
		_escala_feixe = sprite_feixe.scale;

	if feixe != null and is_instance_valid(feixe):
		feixe.body_entered.connect(_ao_queimar);
		feixe.monitoring = false;
		feixe.visible = false;

	_esconder();
	_ir_para(Estado.OCULTO);


func vida_atual() -> int:
	return vida;


func esta_vivo() -> bool:
	return _vivo;


func estado_atual() -> int:
	return _estado;


func esta_tocavel() -> bool:
	if not _vivo:
		return false;
	return _estado == Estado.APARECENDO or _estado == Estado.MIRANDO \
		or _estado == Estado.DISPARANDO or _estado == Estado.VULNERAVEL;


func _physics_process(delta: float) -> void:
	if not _vivo:
		return;

	if _jogador == null or not is_instance_valid(_jogador):
		_jogador = get_tree().get_first_node_in_group("jogador") as Node2D;

	_tempo += delta;

	match _estado:
		Estado.OCULTO:
			if _tempo >= t_oculto:
				_reposicionar();
				_ir_para(Estado.APARECENDO);
		Estado.APARECENDO:
			_crescer(clampf(_tempo / maxf(0.01, t_aparecendo), 0.0, 1.0));
			if _tempo >= t_aparecendo:
				_crescer(1.0);
				_mirar();
				_ir_para(Estado.MIRANDO);
		Estado.MIRANDO:
			_pintar_feixe(espessura_mira, alpha_mira);
			if _tempo >= t_mirando:
				_disparar();
				_ir_para(Estado.DISPARANDO);
		Estado.DISPARANDO:
			_pintar_feixe(espessura_tiro, alpha_tiro);
			_conferir_feixe();
			if _tempo >= t_disparando:
				_apagar_feixe();
				_ir_para(Estado.VULNERAVEL);
		Estado.VULNERAVEL:
			if _tempo >= t_vulneravel:
				_ir_para(Estado.SUMINDO);
		Estado.SUMINDO:
			_crescer(1.0 - clampf(_tempo / maxf(0.01, t_sumindo), 0.0, 1.0));
			if _tempo >= t_sumindo:
				_esconder();
				_ir_para(Estado.OCULTO);


func _ir_para(novo: int) -> void:
	_estado = novo;
	_tempo = 0.0;
	set_deferred("monitoring", esta_tocavel());


func _reposicionar() -> void:
	var opcoes: Array[Marker2D] = [];
	if pontos != null:
		for filho in pontos.get_children():
			if filho is Marker2D:
				opcoes.append(filho);

	if opcoes.is_empty():
		return;

	var escolha := _ultimo_ponto;
	for tentativa in 8:
		escolha = randi() % opcoes.size();
		if escolha != _ultimo_ponto:
			break;

	_ultimo_ponto = escolha;
	global_position = opcoes[escolha].global_position;


func _mirar() -> void:
	if feixe == null or not is_instance_valid(feixe):
		return;

	var alvo := global_position + Vector2(1.0, 0.0);
	if _jogador != null and is_instance_valid(_jogador):
		alvo = _jogador.global_position;

	feixe.rotation = (alvo - global_position).angle();
	feixe.visible = true;
	feixe.monitoring = false;


func _disparar() -> void:
	if feixe == null or not is_instance_valid(feixe):
		return;
	feixe.set_deferred("monitoring", true);
	atirou.emit();


func _conferir_feixe() -> void:
	if feixe == null or not is_instance_valid(feixe) or not feixe.monitoring:
		return;
	for corpo in feixe.get_overlapping_bodies():
		_ao_queimar(corpo);


func _apagar_feixe() -> void:
	if feixe == null or not is_instance_valid(feixe):
		return;
	feixe.set_deferred("monitoring", false);
	feixe.visible = false;


func _pintar_feixe(espessura: float, a: float) -> void:
	if sprite_feixe == null or not is_instance_valid(sprite_feixe):
		return;
	sprite_feixe.scale = Vector2(_escala_feixe.x, _escala_feixe.y * espessura);
	sprite_feixe.modulate.a = a;


func _crescer(fracao: float) -> void:
	if sprite_boss == null or not is_instance_valid(sprite_boss):
		return;
	if _sem_animacao():
		sprite_boss.visible = fracao > 0.5;
		sprite_boss.scale = _escala_boss;
		sprite_boss.modulate.a = 1.0;
		return;
	sprite_boss.visible = true;
	sprite_boss.scale = _escala_boss * Vector2(1.0, maxf(0.02, fracao));
	sprite_boss.modulate.a = fracao;


func _esconder() -> void:
	_apagar_feixe();
	if sprite_boss != null and is_instance_valid(sprite_boss):
		sprite_boss.visible = false;
		sprite_boss.scale = _escala_boss;
		sprite_boss.modulate.a = 1.0;


func _ao_tocar(corpo: Node2D) -> void:
	if not _vivo or _matando or not esta_tocavel():
		return;
	if corpo == null or not corpo.is_in_group("jogador"):
		return;
	if corpo.has_method("esta_morrendo") and corpo.call("esta_morrendo"):
		return;

	vida -= 1;
	_apagar_feixe();
	levou_dano.emit(vida);

	if vida <= 0:
		_vivo = false;
		set_deferred("monitoring", false);
		set_physics_process(false);
		_esconder();
		derrotado.emit();
		return;

	_ir_para(Estado.SUMINDO);


func _ao_queimar(corpo: Node2D) -> void:
	if _matando or not _vivo or _estado != Estado.DISPARANDO:
		return;
	if corpo == null or not corpo.is_in_group("jogador"):
		return;
	if corpo.has_method("esta_morrendo") and corpo.call("esta_morrendo"):
		return;

	_matando = true;
	_apagar_feixe();
	set_physics_process(false);

	if corpo.has_method("morrer"):
		await corpo.call("morrer");
	else:
		await get_tree().create_timer(0.8).timeout;

	Fases.voltar_ao_ponto();


func _sem_animacao() -> bool:
	return Configuracoes.config_ativa(Configuracoes.REMOVER_ANIMACAO);
