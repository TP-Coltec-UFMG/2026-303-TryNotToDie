extends Node

const FAIXA_MENU := "res://sons/musica/pufino_enlivening.mp3";
const FAIXA_JOGO := "res://sons/musica/zambolino_wanderer_at_night.mp3";

const CENA_MENU := "res://cenas/menu.tscn";
const CENA_CREDITOS := "res://cenas/creditos.tscn";

const DURACAO_TROCA := 1.2;
const DURACAO_SAIDA := 0.25;
const SILENCIO := 0.0001;

var _tocadores: Array[AudioStreamPlayer] = [];
var _ativo: int = 0;
var _faixa_atual: String = "";
var _cena_vista: int = 0;
var _cache: Dictionary[String, AudioStream] = {};
var _troca: Tween = null;
var _saindo: bool = false;


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS;
	get_tree().auto_accept_quit = false;
	for i in 2:
		var tocador := AudioStreamPlayer.new();
		tocador.name = "Tocador%d" % i;
		tocador.bus = Configuracoes.BUS_MUSICA;
		tocador.volume_db = linear_to_db(SILENCIO);
		add_child(tocador);
		_tocadores.append(tocador);


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		sair();


func sair() -> void:
	if _saindo:
		return;
	_saindo = true;

	if _troca != null and _troca.is_valid():
		_troca.kill();

	var silenciar := create_tween().set_parallel();
	silenciar.tween_interval(DURACAO_SAIDA);
	for tocador in _tocadores:
		if tocador.playing:
			silenciar.tween_method(_definir_volume.bind(tocador), db_to_linear(tocador.volume_db), SILENCIO, DURACAO_SAIDA);
	await silenciar.finished;

	for tocador in _tocadores:
		tocador.stop();
	await get_tree().create_timer(0.1).timeout;
	get_tree().quit();


func _exit_tree() -> void:
	if _troca != null and _troca.is_valid():
		_troca.kill();
	for tocador in _tocadores:
		tocador.stop();
		tocador.stream = null;
	_cache.clear();


func _process(_delta: float) -> void:
	var cena := get_tree().current_scene;
	var id := cena.get_instance_id() if cena != null else 0;
	if id == _cena_vista:
		return;
	_cena_vista = id;
	if cena != null:
		tocar(faixa_da_cena(cena.scene_file_path));


func faixa_da_cena(caminho: String) -> String:
	if caminho == CENA_MENU or caminho == CENA_CREDITOS:
		return FAIXA_MENU;
	return FAIXA_JOGO;


func faixa_atual() -> String:
	return _faixa_atual;


func tocar(caminho: String) -> void:
	if caminho == _faixa_atual:
		return;

	var stream := _carregar(caminho);
	if stream == null:
		return;
	_faixa_atual = caminho;

	var antigo := _tocadores[_ativo];
	_ativo = 1 - _ativo;
	var novo := _tocadores[_ativo];

	novo.stream = stream;
	novo.volume_db = linear_to_db(SILENCIO);
	novo.play();

	if _troca != null and _troca.is_valid():
		_troca.kill();

	var volume_antigo := db_to_linear(antigo.volume_db) if antigo.playing else SILENCIO;

	_troca = create_tween().set_parallel();
	_troca.tween_method(_definir_volume.bind(novo), SILENCIO, 1.0, DURACAO_TROCA);
	_troca.tween_method(_definir_volume.bind(antigo), volume_antigo, SILENCIO, DURACAO_TROCA);
	_troca.chain().tween_callback(func() -> void:
		if _tocadores[_ativo] != antigo:
			antigo.stop()
	);


func _definir_volume(valor: float, tocador: AudioStreamPlayer) -> void:
	tocador.volume_db = linear_to_db(maxf(valor, SILENCIO));


func _carregar(caminho: String) -> AudioStream:
	if _cache.has(caminho):
		return _cache[caminho];

	if not ResourceLoader.exists(caminho):
		push_warning("Musica nao encontrada: %s" % caminho);
		return null;

	var stream := load(caminho) as AudioStream;
	if stream == null:
		return null;

	stream.set("loop", true);
	_cache[caminho] = stream;
	return stream;
