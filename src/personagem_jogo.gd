extends Sprite2D

@export var speed: float = 300.0

func _process(delta: float) -> void:
	var direction = Vector2.ZERO

	# Detecta as teclas WASD
	if Input.is_key_pressed(KEY_D):
		direction.x += 1
	if Input.is_key_pressed(KEY_A):
		direction.x -= 1
	if Input.is_key_pressed(KEY_S):
		direction.y += 1
	if Input.is_key_pressed(KEY_W):
		direction.y -= 1

	if direction != Vector2.ZERO:
		direction = direction.normalized()
		
	position += direction * speed * delta
