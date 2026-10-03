class_name CasaInterior
extends Fase

@export var comodo_de_cima: Node2D;


func _ready() -> void:
	super();

	if comodo_de_cima != null and Progresso.ligado(Progresso.C3_CAIU):
		comodo_de_cima.queue_free();
