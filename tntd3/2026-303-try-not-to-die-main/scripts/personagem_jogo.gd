extends CharacterBody2D

@export var speed: float = 300.0;
@export var jump_force: float = -500.0;
@export var tolerancia_destino: float = 8.0;
@export var altura_para_pular: float = 40.0;

@export_group("Pulo no clique")
@export var pulo_inteligente: bool = true;
@export var folga_do_pulo: float = 12.0;
@export var alcance_da_espera: float = 360.0;
@export var busca_da_superficie: float = 2000.0;
@export var maximo_de_tentativas: int = 3;

@export_group("Anjo")
@export var mostrar_anjo: bool = true;
@export var distancia_do_sino: float = 360.0;
@export var intervalo_do_sino: float = 0.22;

@export_group("Modo automatico")
@export var modo_automatico: bool = false;
@export var velocidade_auto: float = 260.0;
@export var alcance_frente: float = 78.0;
@export var alcance_buraco: float = 150.0;
@export var avanco_do_raio: float = 62.0;
@export var espera_entre_pulos: float = 0.22;

@export_group("Autonomo")
@export var autonomo: bool = false;
@export var espera_minima: float = 2.2;
@export var espera_maxima: float = 4.8;
@export var passear_depois_de: Vector2 = Vector2(4.0, 8.0);
@export var raio_do_passeio: float = 160.0;
@export var distancia_do_passeio: Vector2 = Vector2(40.0, 110.0);
@export var trechos_do_passeio: Vector2i = Vector2i(1, 3);
@export var pausa_entre_trechos: Vector2 = Vector2(0.5, 1.3);
@export var velocidade_do_passeio: float = 95.0;

@export_group("Animacao")
@export var anim_parado: String = "parado";
@export var anim_andando: String = "andando";
@export var anim_respirando: String = "respirando";
@export var anim_cabeca_esquerda: String = "cabeca_esquerda";
@export var anim_cabeca_direita: String = "cabeca_direita";
@export var anim_olhando_cima: String = "olhando_cima";
@export var anim_olhando_lado: String = "olhando_lado";
@export var escala_animacao: float = 2.4;
@export var anim_morte_vinha: String = "morte_vinha";
@export var anim_morte_sol: String = "morte_sol";
@export var espera_apos_morte: float = 0.35;
@export var min_interrogacao: int = 4;

@onready var sprite: AnimatedSprite2D = $Sprite;
@onready var forma: CollisionShape2D = $CollisionShape2D;

signal morreu;

var _destino_x: float = 0.0;
var _tem_destino: bool = false;
var _ao_chegar: Callable = Callable();
var _morrendo: bool = false;
var _andando: bool = false;
var _raio_frente: RayCast2D = null;
var _raio_buraco: RayCast2D = null;
var _descanso_pulo: float = 0.0;
var _descanso_sino: float = 0.0;
var _qnt_interrogacao : int;

var _velocidade_destino: float = 0.0;
var _pulo_pendente: bool = false;
var _chao_alvo_y: float = 0.0;
var _x_do_ultimo_pulo: float = INF;
var _pulos_tentados: int = 0;

var _anim_ociosa: String = "";
var _ocio: float = 0.0;
var _acao_restante: float = 0.0;
var _passeando: bool = false;
var _ancora_x: float = 0.0;
var _renovar_ancora: bool = true;
var _para_passear: float = 0.0;
var _trechos_restantes: int = 0;


func _ready() -> void:
	add_to_group("jogador");
	Configuracoes.config_alterada.connect(_ao_mudar_config);
	_velocidade_destino = speed;
	_ancora_x = global_position.x;
	_ocio = randf_range(espera_minima, espera_maxima);
	_para_passear = randf_range(passear_depois_de.x, passear_depois_de.y);
	_aplicar_animacao(true);

	if modo_automatico:
		_montar_raios();

func _montar_raios() -> void:
	_raio_frente = RayCast2D.new();
	_raio_frente.position = Vector2(0.0, -22.0);
	_raio_frente.target_position = Vector2(alcance_frente, 0.0);
	_raio_frente.collide_with_areas = false;
	add_child(_raio_frente);

	_raio_buraco = RayCast2D.new();
	_raio_buraco.position = Vector2(avanco_do_raio, 0.0);
	_raio_buraco.target_position = Vector2(0.0, alcance_buraco);
	_raio_buraco.collide_with_areas = false;
	add_child(_raio_buraco);

	#queue_redraw();


func _correr_sozinho(delta: float) -> float:
	_descanso_pulo = maxf(0.0, _descanso_pulo - delta);

	if not is_on_floor() or _descanso_pulo > 0.0:
		return 1.0;

	var barrado := _raio_frente != null and _raio_frente.is_colliding();
	var buraco := _raio_buraco != null and not _raio_buraco.is_colliding();

	if barrado or buraco or is_on_wall():
		velocity.y = jump_force;
		_descanso_pulo = espera_entre_pulos;

	return 1.0;


func _ao_mudar_config(chave: String, _valor: bool) -> void:
	if chave == Configuracoes.REMOVER_ANIMACAO:
		_aplicar_animacao(true);


func _animar(andando: bool) -> void:
	if andando == _andando:
		return;
	_andando = andando;
	_aplicar_animacao(false);


func _aplicar_animacao(forcar: bool) -> void:
	if sprite == null or sprite.sprite_frames == null or _morrendo:
		return;

	var quadros := sprite.sprite_frames;
	var alvo := anim_parado;
	if not _sem_animacao():
		if _andando:
			alvo = anim_andando;
		elif _usa_ocio():
			if _anim_ociosa != "" and quadros.has_animation(_anim_ociosa):
				alvo = _anim_ociosa;
			elif quadros.has_animation(anim_respirando):
				alvo = anim_respirando;

	if not quadros.has_animation(alvo):
		if not quadros.has_animation(anim_parado):
			return;
		alvo = anim_parado;

	if alvo == anim_andando:
		sprite.speed_scale = maxf(0.05, escala_animacao * _fator_do_passo());
	else:
		sprite.speed_scale = 1.0;

	if forcar or sprite.animation != alvo:
		sprite.animation = alvo;
		sprite.frame = 0;

	if _sem_animacao():
		sprite.stop();
	elif not sprite.is_playing():
		sprite.play();


func _fator_do_passo() -> float:
	if not _passeando or speed <= 0.0:
		return 1.0;
	return clampf(_velocidade_destino / speed, 0.45, 1.0);


func _sem_animacao() -> bool:
	return Configuracoes.config_ativa(Configuracoes.REMOVER_ANIMACAO);


func esta_morrendo() -> bool:
	return _morrendo;


func morrer(tipo: String = "") -> void:
	if _morrendo:
		return;
	_morrendo = true;

	cancelar_destino();
	velocity = Vector2.ZERO;
	set_physics_process(false);
	set_process_unhandled_input(false);
	sprite.stop();

	for filho in get_children():
		if filho is CollisionShape2D:
			filho.set_deferred("disabled", true);

	var cam := get_node_or_null("Camera2D") as Camera2D;
	if cam != null:
		var onde := cam.global_position;
		cam.position_smoothing_enabled = false;
		cam.top_level = true;
		cam.global_position = onde;

	morreu.emit();

	var anim_da_morte := _animacao_da_morte(tipo);
	if anim_da_morte != "":
		await _morte_animada(anim_da_morte, tipo);
		return;

	if Configuracoes.config_ativa(Configuracoes.REMOVER_ANIMACAO):
		await get_tree().create_timer(0.7).timeout;
		return;

	var y0 := global_position.y;
	var tween := create_tween();
	tween.tween_interval(0.3);
	tween.tween_property(self, "global_position:y", y0 - 220.0, 0.42)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT);
	tween.tween_property(self, "global_position:y", y0 + 900.0, 0.85)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN);
	await tween.finished;


func _animacao_da_morte(tipo: String) -> String:
	var nome := "";
	match tipo:
		"vinha":
			nome = anim_morte_vinha;
		"sol":
			nome = anim_morte_sol;
	if nome == "" or sprite == null or sprite.sprite_frames == null:
		return "";
	if not sprite.sprite_frames.has_animation(nome):
		return "";
	return nome;


func _morte_animada(nome: String, tipo: String) -> void:
	sprite.flip_h = false;
	sprite.speed_scale = 1.0;
	sprite.animation = nome;

	if _sem_animacao():
		sprite.stop();
		sprite.frame = int(sprite.sprite_frames.get_frame_count(nome) * 0.6);
		await get_tree().create_timer(0.9).timeout;
		return;

	sprite.play(nome);
	if tipo == "sol":
		_soltar_fumaca();
	await sprite.animation_finished;
	await get_tree().create_timer(espera_apos_morte).timeout;


func _soltar_fumaca() -> void:
	var fumaca := CPUParticles2D.new();
	fumaca.z_as_relative = false;
	fumaca.z_index = 4096;
	fumaca.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST;
	fumaca.amount = 18;
	fumaca.lifetime = 1.3;
	fumaca.emitting = false;
	fumaca.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE;
	fumaca.emission_rect_extents = Vector2(22.0, 30.0);
	fumaca.direction = Vector2.UP;
	fumaca.spread = 25.0;
	fumaca.gravity = Vector2(0.0, -50.0);
	fumaca.initial_velocity_min = 20.0;
	fumaca.initial_velocity_max = 55.0;
	fumaca.scale_amount_min = 6.0;
	fumaca.scale_amount_max = 12.0;
	var cores := Gradient.new();
	cores.offsets = PackedFloat32Array([0.0, 0.25, 1.0]);
	cores.colors = PackedColorArray([Color(0.3, 0.28, 0.27, 0.0), Color(0.32, 0.3, 0.29, 0.6), Color(0.55, 0.55, 0.55, 0.0)]);
	fumaca.color_ramp = cores;
	add_child(fumaca);
	fumaca.position = sprite.position + Vector2(0.0, -20.0);

	var ritmo := create_tween();
	ritmo.tween_interval(0.25);
	ritmo.tween_callback(fumaca.set.bind("emitting", true));
	ritmo.tween_interval(1.4);
	ritmo.tween_callback(fumaca.set.bind("emitting", false));


func _unhandled_input(event: InputEvent) -> void:
	if _morrendo or modo_automatico:
		return;
	if event is InputEventMouseButton \
			and event.pressed \
			and event.button_index == MOUSE_BUTTON_LEFT:
		_definir_destino(get_global_mouse_position());


func _definir_destino(ponto: Vector2) -> void:
	_interromper_ocio();

	_destino_x = ponto.x;
	_tem_destino = absf(_destino_x - global_position.x) > tolerancia_destino;
	_ao_chegar = Callable();
	_velocidade_destino = speed;
	_x_do_ultimo_pulo = INF;

	if mostrar_anjo:
		_chamar_anjo(ponto);

	_planejar_pulo(ponto);

	# Simula delay mental do personagem
	if(_qnt_interrogacao == 0):
		var tween = create_tween();
		$Sprite2D.visible = true;
		$Sprite2D.modulate.a = 1.0;
		tween.tween_property($Sprite2D, "modulate:a", 1.0, 0.15);
		tween.tween_interval(0.5);
		tween.tween_property($Sprite2D, "modulate:a", 0.0, 0.15);
		await tween.finished
		$Sprite2D.visible = false
		_qnt_interrogacao = (randi() % min_interrogacao) + 3;
	else:
		_qnt_interrogacao -= 1;


func _planejar_pulo(ponto: Vector2) -> void:
	_pulo_pendente = false;
	_pulos_tentados = 0;

	if not pulo_inteligente:
		if is_on_floor() and global_position.y - ponto.y > altura_para_pular:
			velocity.y = jump_force;
		return;

	_chao_alvo_y = _superficie_sob(ponto);
	if _pes_y() - _chao_alvo_y <= altura_para_pular:
		return;

	_pulo_pendente = true;
	if not _tem_destino and is_on_floor():
		_pular();


func _superficie_sob(ponto: Vector2) -> float:
	var espaco := get_world_2d().direct_space_state;
	var inicio := ponto;

	var consulta := PhysicsPointQueryParameters2D.new();
	consulta.collide_with_areas = false;
	consulta.exclude = [get_rid()];
	for _i in 40:
		consulta.position = inicio;
		if espaco.intersect_point(consulta, 1).is_empty():
			break;
		inicio.y -= 16.0;

	var raio := PhysicsRayQueryParameters2D.create(inicio, inicio + Vector2(0.0, busca_da_superficie));
	raio.collide_with_areas = false;
	raio.exclude = [get_rid()];
	var achou := espaco.intersect_ray(raio);
	if achou.is_empty():
		return ponto.y;
	return (achou.position as Vector2).y;


func _pes_y() -> float:
	if forma == null or not (forma.shape is RectangleShape2D):
		return global_position.y;
	return forma.global_position.y + (forma.shape as RectangleShape2D).size.y * 0.5 * forma.global_scale.y;


func _altura_do_corpo() -> float:
	if forma == null or not (forma.shape is RectangleShape2D):
		return 100.0;
	return (forma.shape as RectangleShape2D).size.y * forma.global_scale.y;


func _meia_largura() -> float:
	if forma == null or not (forma.shape is RectangleShape2D):
		return 20.0;
	return (forma.shape as RectangleShape2D).size.x * 0.5 * forma.global_scale.x;


func _gravidade() -> float:
	return maxf(1.0, get_gravity().y);


func _altura_maxima() -> float:
	var v := -jump_force;
	return v * v / (2.0 * _gravidade());


func _tempo_ate_subir(altura: float) -> float:
	var v := -jump_force;
	var g := _gravidade();
	var delta := v * v - 2.0 * g * altura;
	if altura <= 0.0:
		return 0.0;
	if delta <= 0.0:
		return v / g;
	return (v - sqrt(delta)) / g;


func _pular() -> void:
	velocity.y = jump_force;
	_x_do_ultimo_pulo = global_position.x;
	_pulos_tentados += 1;


func _conferir_pulo_pendente(direcao: float) -> void:
	if not _pulo_pendente or not is_on_floor() or direcao == 0.0:
		return;
	if _pulos_tentados >= maximo_de_tentativas:
		return;

	var pes := _pes_y();
	if pes - _chao_alvo_y <= altura_para_pular * 0.5:
		_pulo_pendente = false;
		return;

	var obstaculo := _obstaculo_a_frente(direcao);
	var vel := absf(velocity.x) if absf(velocity.x) > 1.0 else _velocidade_destino;

	if obstaculo.is_finite():
		var subida := obstaculo.y + folga_do_pulo;
		if subida > _altura_maxima():
			return;
		if obstaculo.x <= vel * _tempo_ate_subir(subida):
			_pular();
		return;

	var falta := absf(_destino_x - global_position.x);
	var subida_alvo := minf(pes - _chao_alvo_y + folga_do_pulo, _altura_maxima());
	var tempo := _tempo_ate_subir(subida_alvo);
	var ate_o_topo := -jump_force / _gravidade();
	if falta <= vel * lerpf(tempo, ate_o_topo, 0.5):
		_pular();


func _obstaculo_a_frente(direcao: float) -> Vector2:
	if forma == null or forma.shape == null:
		return Vector2.INF;

	var espaco := get_world_2d().direct_space_state;
	var pes_agora := _pes_y();
	var corpo_alto := _altura_do_corpo();
	var extra := clampf(pes_agora - _chao_alvo_y, 0.0, _altura_maxima());
	var faixa := RectangleShape2D.new();
	faixa.size = Vector2(_meia_largura() * 2.0, corpo_alto + extra);

	var consulta := PhysicsShapeQueryParameters2D.new();
	consulta.shape = faixa;
	consulta.transform = Transform2D(0.0, Vector2(forma.global_position.x, pes_agora - 2.0 - faixa.size.y * 0.5));
	consulta.motion = Vector2(direcao * alcance_da_espera, 0.0);
	consulta.collide_with_areas = false;
	consulta.exclude = [get_rid()];

	var fracoes := espaco.cast_motion(consulta);
	if fracoes.size() < 2 or fracoes[0] >= 1.0:
		return Vector2.INF;

	var distancia := fracoes[0] * alcance_da_espera;
	var pes := _pes_y();
	var x_face := global_position.x + direcao * (distancia + _meia_largura() + 3.0);
	var topo := maxf(pes - _altura_maxima() - 30.0, _chao_alvo_y - 20.0);

	var raio := PhysicsRayQueryParameters2D.create(Vector2(x_face, topo), Vector2(x_face, pes + 2.0));
	raio.collide_with_areas = false;
	raio.hit_from_inside = true;
	raio.exclude = [get_rid()];
	var achou := espaco.intersect_ray(raio);
	if achou.is_empty() or (achou.normal as Vector2) == Vector2.ZERO:
		return Vector2(distancia, INF);

	return Vector2(distancia, pes - (achou.position as Vector2).y);


func _chamar_anjo(ponto: Vector2) -> void:
	var pai := get_parent();
	if pai == null:
		return;
	_descanso_sino = intervalo_do_sino;
	Anjo.aparecer(pai, ponto, ponto.x - global_position.x);


func _sino_do_lado(lado: float) -> void:
	var pai := get_parent();
	if pai == null:
		return;
	_descanso_sino = intervalo_do_sino;
	Anjo.tocar_sino(pai, global_position + Vector2(lado * distancia_do_sino, 0.0));


func _conferir_teclado(delta: float) -> void:
	_descanso_sino = maxf(0.0, _descanso_sino - delta);

	if not mostrar_anjo or _descanso_sino > 0.0:
		return;

	if Input.is_action_just_pressed("Right"):
		_sino_do_lado(1.0);
	elif Input.is_action_just_pressed("Left"):
		_sino_do_lado(-1.0);


func ir_ate(destino_global_x: float, ao_chegar: Callable = Callable()) -> void:
	_interromper_ocio();
	_destino_x = destino_global_x;
	_tem_destino = absf(_destino_x - global_position.x) > tolerancia_destino;
	_ao_chegar = ao_chegar;
	_velocidade_destino = speed;
	_pulo_pendente = false;

	if not _tem_destino and ao_chegar.is_valid():
		_chegou();


func _limpar_destino() -> void:
	_tem_destino = false;
	_ao_chegar = Callable();
	_pulo_pendente = false;
	_passeando = false;
	_velocidade_destino = speed;


func cancelar_destino() -> void:
	_limpar_destino();
	_animar(false);


func _chegou() -> void:
	_tem_destino = false;
	_pulo_pendente = false;
	var callback := _ao_chegar;
	_ao_chegar = Callable();
	if callback.is_valid():
		callback.call();


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity += get_gravity() * delta;

	var direcao := 0.0;

	if modo_automatico:
		direcao = _correr_sozinho(delta);
		velocity.x = direcao * velocidade_auto;
		sprite.flip_h = false;
		_animar(true);
		move_and_slide();
		return;

	if Input.is_action_just_pressed("Jump") and is_on_floor():
		velocity.y = jump_force;
		_interromper_ocio();

	_conferir_teclado(delta);

	direcao = Input.get_axis("Left", "Right");

	if direcao != 0.0:
		_limpar_destino();
		_interromper_ocio();
	elif _tem_destino:
		var restante := _destino_x - global_position.x;
		if absf(restante) <= tolerancia_destino:
			_chegou();
		else:
			direcao = signf(restante);

	if direcao != 0.0:
		var vel := _velocidade_destino if _tem_destino else speed;
		velocity.x = direcao * vel;
		sprite.flip_h = direcao < 0.0;
	else:
		velocity.x = move_toward(velocity.x, 0.0, speed);

	if _tem_destino:
		_conferir_pulo_pendente(direcao);

	_animar(direcao != 0.0);

	move_and_slide();

	if _tem_destino and is_on_wall() and is_on_floor():
		if _pulo_pendente and _pulos_tentados < maximo_de_tentativas \
				and absf(global_position.x - _x_do_ultimo_pulo) > 4.0:
			_pular();
		else:
			cancelar_destino();

	_atualizar_ocio(delta);


func _usa_ocio() -> bool:
	return autonomo and not modo_automatico;


func _interromper_ocio() -> void:
	_renovar_ancora = true;
	_acao_restante = 0.0;
	_trechos_restantes = 0;
	_ocio = randf_range(espera_minima, espera_maxima);
	_para_passear = randf_range(passear_depois_de.x, passear_depois_de.y);
	if _passeando:
		_passeando = false;
		_velocidade_destino = speed;
	if _anim_ociosa != "":
		_anim_ociosa = "";
		if not _andando:
			_aplicar_animacao(false);


func _definir_anim_ociosa(nome: String) -> void:
	_anim_ociosa = nome;
	if not _andando:
		_aplicar_animacao(false);


func _atualizar_ocio(delta: float) -> void:
	if not _usa_ocio() or _morrendo:
		return;
	if _sem_animacao():
		if _anim_ociosa != "":
			_definir_anim_ociosa("");
		return;
	if _tem_destino or not is_on_floor() or absf(velocity.x) > 1.0:
		return;

	if _renovar_ancora:
		_renovar_ancora = false;
		_ancora_x = global_position.x;

	if _acao_restante > 0.0:
		_acao_restante -= delta;
		if _acao_restante <= 0.0:
			if _trechos_restantes > 0:
				_proximo_trecho();
			else:
				_voltar_a_respirar();
		return;

	_para_passear -= delta;
	if _para_passear <= 0.0:
		_comecar_passeio();
		return;

	_ocio -= delta;
	if _ocio <= 0.0:
		_fazer_um_gesto();


func _voltar_a_respirar() -> void:
	_acao_restante = 0.0;
	_ocio = randf_range(espera_minima, espera_maxima);
	_definir_anim_ociosa("");


func _fazer_um_gesto() -> void:
	var sorteio := randf();

	if sorteio < 0.35:
		sprite.flip_h = false;
		var lado := anim_cabeca_esquerda if randf() < 0.5 else anim_cabeca_direita;
		_fazer(lado, randf_range(1.0, 2.0));
		return;

	if sorteio < 0.7:
		_olhar_para(-1.0 if randf() < 0.5 else 1.0, randf_range(1.4, 2.8));
		return;

	sprite.flip_h = false;
	_fazer(anim_olhando_cima, randf_range(1.8, 3.2));


func _fazer(nome: String, duracao: float) -> void:
	_acao_restante = duracao;
	_definir_anim_ociosa(nome);


func _olhar_para(lado: float, duracao: float) -> void:
	sprite.flip_h = lado < 0.0;
	_fazer(anim_olhando_lado, duracao);


func _comecar_passeio() -> void:
	_trechos_restantes = randi_range(maxi(1, trechos_do_passeio.x), maxi(1, trechos_do_passeio.y));
	_proximo_trecho();


func _proximo_trecho() -> void:
	_trechos_restantes -= 1;
	if not _dar_um_passo():
		_trechos_restantes = 0;
		_terminar_passeio();


func _terminar_passeio() -> void:
	_para_passear = randf_range(passear_depois_de.x, passear_depois_de.y);
	_voltar_a_respirar();


func _dar_um_passo() -> bool:
	var x := global_position.x;
	var distancia := randf_range(distancia_do_passeio.x, distancia_do_passeio.y);
	var lado := -1.0 if randf() < 0.5 else 1.0;
	var longe := x - _ancora_x;
	if absf(longe) > raio_do_passeio * 0.4 and randf() < 0.75:
		lado = -signf(longe);

	for _tentativa in 2:
		var alvo := clampf(x + lado * distancia, _ancora_x - raio_do_passeio, _ancora_x + raio_do_passeio);
		if absf(alvo - x) >= distancia_do_passeio.x * 0.5 and _caminho_livre(alvo):
			_anim_ociosa = "";
			_passeando = true;
			_velocidade_destino = velocidade_do_passeio;
			_destino_x = alvo;
			_tem_destino = true;
			_pulo_pendente = false;
			_ao_chegar = Callable(self, "_fim_do_trecho").bind(lado);
			return true;
		lado = -lado;
	return false;


func _fim_do_trecho(lado: float) -> void:
	_passeando = false;
	_velocidade_destino = speed;

	if _trechos_restantes > 0:
		var proximo := lado if randf() < 0.5 else -lado;
		_olhar_para(proximo, randf_range(pausa_entre_trechos.x, pausa_entre_trechos.y));
		return;

	_para_passear = randf_range(passear_depois_de.x, passear_depois_de.y);
	if randf() < 0.6:
		_olhar_para(lado, randf_range(0.8, 1.6));
	else:
		_voltar_a_respirar();


func _caminho_livre(alvo_x: float) -> bool:
	if forma == null or forma.shape == null:
		return false;

	var espaco := get_world_2d().direct_space_state;
	var pes := _pes_y();
	var deslocamento := alvo_x - global_position.x;

	var amostras := maxi(1, ceili(absf(deslocamento) / 16.0));
	for i in amostras + 1:
		var x := global_position.x + deslocamento * float(i) / float(amostras);
		x += signf(deslocamento) * _meia_largura() * (1.0 if i == amostras else 0.0);
		var chao := PhysicsRayQueryParameters2D.create(Vector2(x, pes - 10.0), Vector2(x, pes + 30.0));
		chao.collide_with_areas = false;
		chao.exclude = [get_rid()];
		var achou := espaco.intersect_ray(chao);
		if achou.is_empty() or absf((achou.position as Vector2).y - pes) > 6.0:
			return false;

	var corpo := PhysicsShapeQueryParameters2D.new();
	corpo.shape = forma.shape;
	corpo.transform = forma.global_transform.translated(Vector2(0.0, -2.0));
	corpo.motion = Vector2(deslocamento, 0.0);
	corpo.collide_with_areas = false;
	corpo.exclude = [get_rid()];
	var fracoes := espaco.cast_motion(corpo);
	if fracoes.size() < 2 or fracoes[0] < 1.0:
		return false;

	var aqui := PhysicsShapeQueryParameters2D.new();
	aqui.shape = forma.shape;
	aqui.transform = forma.global_transform;
	aqui.collide_with_areas = true;
	aqui.collide_with_bodies = false;
	var ja_estou := {};
	for info in espaco.intersect_shape(aqui, 32):
		ja_estou[info.rid] = true;

	var faixa := RectangleShape2D.new();
	var tamanho := (forma.shape as RectangleShape2D).size if forma.shape is RectangleShape2D else Vector2(40.0, 100.0);
	faixa.size = Vector2(absf(deslocamento) + tamanho.x, tamanho.y);
	var caminho := PhysicsShapeQueryParameters2D.new();
	caminho.shape = faixa;
	caminho.transform = Transform2D(0.0, forma.global_position + Vector2(deslocamento * 0.5, 0.0));
	caminho.collide_with_areas = true;
	caminho.collide_with_bodies = false;
	for info in espaco.intersect_shape(caminho, 32):
		if not ja_estou.has(info.rid):
			return false;

	return true;
