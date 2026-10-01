class_name GerenciadorNuvens
extends Node2D

class Nuvem:
	var sprite: Sprite2D;
	var velocidade: float;


const CAMINHOS_PADRAO: Array[String] = [
	"res://sprites/nuvens1.png",
	"res://sprites/nuvens2.png",
	"res://sprites/nuvens3.png",
	"res://sprites/nuvens4.png",
];

@export var texturas: Array[Texture2D] = [];
@export_range(1, 20) var max_nuvens: int = 5;
@export var velocidade_min: float = 1.0;
@export var velocidade_max: float = 3.0;
@export var escala_min: float = 1.5;
@export var escala_max: float = 3.5;
@export var faixa_y: Vector2 = Vector2(30.0, 260.0);
@export var intervalo_spawn: Vector2 = Vector2(1.2, 3.5);
@export var margem_fora: float = 80.0;
@export var povoar_no_inicio: bool = true;

var _texturas: Array[Texture2D] = [];
var _nuvens: Array[Nuvem] = [];
var _rng := RandomNumberGenerator.new();
var _timer := Timer.new();

func _ready() -> void:
	_rng.randomize();

	_texturas = texturas.duplicate();
	if _texturas.is_empty():
		for caminho in CAMINHOS_PADRAO:
			var tex := load(caminho) as Texture2D;
			if tex != null:
				_texturas.append(tex);

	if _texturas.is_empty():
		push_warning("GerenciadorNuvens sem texturas: nada sera instanciado.");
		set_process(false);
		return;

	_timer.one_shot = true;
	_timer.timeout.connect(_ao_estourar_timer);
	add_child(_timer);

	Configuracoes.config_alterada.connect(_ao_mudar_config);
	get_viewport().size_changed.connect(_ao_redimensionar);

	_reconstruir();


func _process(delta: float) -> void:
	if _sem_animacao():
		return;

	var tela := get_viewport_rect().size;

	for i in range(_nuvens.size() - 1, -1, -1):
		var nuvem := _nuvens[i];
		nuvem.sprite.position.x += nuvem.velocidade * delta;

		var meia_largura: float = nuvem.sprite.texture.get_width() * nuvem.sprite.scale.x * 0.5;
		var sumiu_a_direita := nuvem.velocidade > 0.0 \
			and nuvem.sprite.position.x - meia_largura > tela.x;
		var sumiu_a_esquerda := nuvem.velocidade < 0.0 \
			and nuvem.sprite.position.x + meia_largura < 0.0;

		if sumiu_a_direita or sumiu_a_esquerda:
			nuvem.sprite.queue_free();
			_nuvens.remove_at(i);

func _reconstruir() -> void:
	_limpar();

	if _sem_animacao():
		_timer.stop();
		_montar_estatico();
		return;

	if povoar_no_inicio:
		for i in max_nuvens:
			_criar_nuvem(false);

	_reagendar();


func _reagendar() -> void:
	_timer.start(_rng.randf_range(intervalo_spawn.x, intervalo_spawn.y));


func _ao_estourar_timer() -> void:
	if _sem_animacao():
		return;

	if _nuvens.size() < max_nuvens:
		_criar_nuvem(true);

	_reagendar();


func _limpar() -> void:
	for nuvem in _nuvens:
		nuvem.sprite.queue_free();
	_nuvens.clear();

func _criar_nuvem(fora_da_tela: bool) -> void:
	var tela := get_viewport_rect().size;
	var para_direita := _rng.randi() % 2 == 0;
	var escala := _rng.randf_range(escala_min, escala_max);
	var sprite := _novo_sprite(_texturas[_rng.randi() % _texturas.size()], escala);
	var meia_largura: float = sprite.texture.get_width() * escala * 0.5;

	var x: float;
	if fora_da_tela:
		if para_direita:
			x = -meia_largura - margem_fora;
		else:
			x = tela.x + meia_largura + margem_fora;
	else:
		x = _rng.randf_range(meia_largura, maxf(meia_largura, tela.x - meia_largura));

	sprite.position = Vector2(x, _rng.randf_range(faixa_y.x, faixa_y.y));
	add_child(sprite);

	var nuvem := Nuvem.new();
	nuvem.sprite = sprite;
	nuvem.velocidade = _rng.randf_range(velocidade_min, velocidade_max);
	if not para_direita:
		nuvem.velocidade = -nuvem.velocidade;

	_nuvens.append(nuvem);


func _montar_estatico() -> void:
	var tela := get_viewport_rect().size;

	for i in max_nuvens:
		var escala := _rng.randf_range(escala_min, escala_max);
		var sprite := _novo_sprite(_texturas[i % _texturas.size()], escala);
		var coluna := (float(i) + 0.5) / float(max_nuvens);

		sprite.position = Vector2(
			tela.x * coluna,
			lerpf(faixa_y.x, faixa_y.y, _rng.randf())
		);
		add_child(sprite);

		var nuvem := Nuvem.new();
		nuvem.sprite = sprite;
		nuvem.velocidade = 0.0;
		_nuvens.append(nuvem);


func _novo_sprite(textura: Texture2D, escala: float) -> Sprite2D:
	var sprite := Sprite2D.new();
	sprite.texture = textura;
	sprite.scale = Vector2(escala, escala);
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST;
	return sprite;

func _sem_animacao() -> bool:
	return Configuracoes.config_ativa(Configuracoes.REMOVER_ANIMACAO);

func _ao_mudar_config(chave: String, _valor: bool) -> void:
	if chave == Configuracoes.REMOVER_ANIMACAO:
		_reconstruir();

func _ao_redimensionar() -> void:
	if _sem_animacao():
		_reconstruir();
