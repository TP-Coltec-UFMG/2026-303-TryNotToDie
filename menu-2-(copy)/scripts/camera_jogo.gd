class_name CameraJogo
extends Camera2D

@export var forca_maxima: float = 60.0;
@export var decaimento: float = 8.0;

var _forca: float = 0.0;


func _process(delta: float) -> void:
	if _forca <= 0.0:
		return;

	_forca = move_toward(_forca, 0.0, decaimento * delta * maxf(1.0, _forca * 0.5));
	offset = Vector2(
		randf_range(-_forca, _forca),
		randf_range(-_forca, _forca)
	);

	if _forca <= 0.01:
		_forca = 0.0;
		offset = Vector2.ZERO;


func sacudir(forca: float = 30.0) -> void:
	if Configuracoes.config_ativa(Configuracoes.REMOVER_ANIMACAO):
		return;
	_forca = maxf(_forca, minf(forca, forca_maxima));
