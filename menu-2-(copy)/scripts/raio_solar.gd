class_name RaioSolar
extends Area2D

enum Estado { APAGADO, AVISANDO, ACESO };

signal acendeu;
signal queimou;

@export var sprite_raio: Node2D;
@export var distancia_de_ativacao: float = 870.0;
@export var sempre_aceso: bool = false;

@export_group("Ciclo")
@export var duracao_apagado: float = 1.4;
@export var duracao_aviso: float = 0.7;
@export var duracao_aceso: float = 1.1;

@export_group("Aparencia")
@export var alpha_apagado: float = 0.14;
@export var alpha_aviso: float = 0.45;
@export var alpha_aceso: float = 0.95;
@export var largura_apagado: float = 0.4;
@export var largura_aceso: float = 1.0;
@export var piscar_aviso: float = 9.0;

var _estado: int = Estado.APAGADO;
var _tempo: float = 0.0;
var _ligado: bool = false;
var _queimando: bool = false;
var _jogador: Node2D = null;
var _escala_base: Vector2 = Vector2.ONE;


func _ready() -> void:
	body_entered.connect(_ao_encostar);
	if sprite_raio != null and is_instance_valid(sprite_raio):
		_escala_base = sprite_raio.scale;

	if sempre_aceso:
		_ligado = true;
		_estado = Estado.ACESO;

	_pintar(0.0);


func _physics_process(delta: float) -> void:
	if sempre_aceso:
		_estado = Estado.ACESO;
		_pintar(0.0);
		_conferir_quem_esta_dentro();
		return;

	if _jogador == null or not is_instance_valid(_jogador):
		_jogador = get_tree().get_first_node_in_group("jogador") as Node2D;
		if _jogador == null:
			return;

	if not _ligado:
		if global_position.x - _jogador.global_position.x > distancia_de_ativacao:
			return;
		_ligado = true;
		_tempo = 0.0;
		_estado = Estado.APAGADO;

	_tempo += delta;
	_avancar_ciclo();


func _avancar_ciclo() -> void:
	var anterior := _estado;

	if _estado == Estado.APAGADO and _tempo >= duracao_apagado:
		_tempo -= duracao_apagado;
		_estado = Estado.AVISANDO;
	elif _estado == Estado.AVISANDO and _tempo >= duracao_aviso:
		_tempo -= duracao_aviso;
		_estado = Estado.ACESO;
	elif _estado == Estado.ACESO and _tempo >= duracao_aceso:
		_tempo -= duracao_aceso;
		_estado = Estado.APAGADO;

	_pintar(_tempo);

	if _estado == anterior:
		if _estado == Estado.ACESO:
			_conferir_quem_esta_dentro();
		return;

	if _estado == Estado.ACESO:
		acendeu.emit();
		_conferir_quem_esta_dentro();


func estado_atual() -> int:
	return _estado;


func esta_aceso() -> bool:
	return _estado == Estado.ACESO;


func _conferir_quem_esta_dentro() -> void:
	for corpo in get_overlapping_bodies():
		_ao_encostar(corpo);


func _ao_encostar(corpo: Node2D) -> void:
	if _queimando or not esta_aceso():
		return;
	if corpo == null or not corpo.is_in_group("jogador"):
		return;
	if corpo.has_method("esta_morrendo") and corpo.call("esta_morrendo"):
		return;
	if _protegido():
		return;

	_queimando = true;
	set_physics_process(false);
	queimou.emit();

	if corpo.has_method("morrer"):
		await corpo.call("morrer");
	else:
		await get_tree().create_timer(0.8).timeout;

	Fases.voltar_ao_ponto();


func _protegido() -> bool:
	var p := get_tree().get_first_node_in_group("protetor");
	if p == null or not p.has_method("esta_protegido"):
		return false;
	return p.call("esta_protegido");


func _pintar(t: float) -> void:
	if sprite_raio == null or not is_instance_valid(sprite_raio):
		return;

	var a := alpha_apagado;
	var largura := largura_apagado;

	if _estado == Estado.AVISANDO:
		largura = lerpf(largura_apagado, largura_aceso, 0.55);
		var pulso := 0.5 + 0.5 * sin(t * piscar_aviso);
		a = lerpf(alpha_apagado, alpha_aviso, 1.0) * (0.55 + 0.45 * pulso);
		if _sem_animacao():
			a = alpha_aviso;
	elif _estado == Estado.ACESO:
		largura = largura_aceso;
		a = alpha_aceso;

	sprite_raio.scale = Vector2(_escala_base.x * largura, _escala_base.y);
	sprite_raio.modulate.a = a;


func _sem_animacao() -> bool:
	return Configuracoes.config_ativa(Configuracoes.REMOVER_ANIMACAO);
