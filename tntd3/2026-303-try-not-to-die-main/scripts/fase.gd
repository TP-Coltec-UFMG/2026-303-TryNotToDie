class_name Fase
extends Node2D

@export var jogador: CharacterBody2D;

# para eu conseguir comecar de qualquer lugar...
@export var entrada_padrao: String = "";

func _ready() -> void:
	var entrada := Fases.consumir_entrada();
	if entrada == "":
		entrada = entrada_padrao;
	if entrada == "" or jogador == null:
		return;

	var marcador := _achar_marcador(self, entrada);
	if marcador == null:
		push_warning("PontoDeEntrada '%s' nao existe em %s." % [entrada, name]);
		return;

	jogador.global_position = marcador.global_position;
	jogador.velocity = Vector2.ZERO;


func _achar_marcador(no: Node, alvo: String) -> Marker2D:
	for filho in no.get_children():
		if filho is Marker2D and filho.name == alvo:
			return filho;
		var achado := _achar_marcador(filho, alvo);
		if achado != null:
			return achado;
	return null;
