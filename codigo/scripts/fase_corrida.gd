class_name FaseCorrida
extends Fase

@export var itens_garantidos: Array[String] = [];
@export var altura_da_morte: float = 1200.0;

var _caiu: bool = false;


func _ready() -> void:
	super();

	for id in itens_garantidos:
		if id != "" and not Progresso.tem(id):
			Progresso.pegar(id);


func _physics_process(_delta: float) -> void:
	if _caiu or jogador == null or not is_instance_valid(jogador):
		return;
	if jogador.global_position.y < altura_da_morte:
		return;

	_caiu = true;
	set_physics_process(false);
	await _cair_no_vazio();


func _cair_no_vazio() -> void:
	if jogador.has_method("morrer"):
		await jogador.call("morrer");
	else:
		await get_tree().create_timer(0.6).timeout;
	Fases.voltar_ao_ponto();
