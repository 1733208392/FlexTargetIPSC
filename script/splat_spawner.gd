extends Node2D

@export var pool_size: int = 24
@export var base_splat_size: int = 128
@export var min_splat_radius: float = 48.0
@export var draw_layer: NodePath = NodePath("CanvasLayer")

var rng := RandomNumberGenerator.new()
var pool: Array = []
var noise_tex: Texture2D
var base_splat_texture: Texture2D
var splat_shader: Shader
var draw_parent: Node

func _ready():
	rng.randomize()
	splat_shader = load("res://shader/splat.gdshader")
	_make_noise_texture(32)
	base_splat_texture = _make_base_splat_image(base_splat_size)
	_create_pool()
	draw_parent = get_node_or_null(draw_layer)
	if not draw_parent:
		draw_parent = self

func _input(event):
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		spawn_splat(event.position, randf_range(min_splat_radius, 96.0), Color.from_hsv(rng.randf(), 0.8, 0.9))

func _make_noise_texture(size: int):
	var img = Image.create(size, size, false, Image.FORMAT_R8)
	for y in range(size):
		for x in range(size):
			var v = rng.randf()
			img.set_pixel(x, y, Color(v, 0, 0))
	noise_tex = ImageTexture.create_from_image(img)

func _make_base_splat_image(size: int) -> Texture2D:
	var img = Image.create(size, size, false, Image.FORMAT_RGBA8)
	var center = Vector2(float(size) / 2.0, float(size) / 2.0)
	for y in range(size):
		for x in range(size):
			var d = center.distance_to(Vector2(x, y)) / (size * 0.5)
			var a = clamp(1.0 - d, 0.0, 1.0)
			a = pow(a, 1.4)
			img.set_pixel(x, y, Color(1, 1, 1, a))
	return ImageTexture.create_from_image(img)

func _create_pool():
	for i in range(pool_size):
		var inst = _create_splat_instance()
		add_child(inst)
		pool.append(inst)

func _get_pooled() -> Node2D:
	for s in pool:
		var sprite = s.get_node_or_null("Sprite") as Sprite2D
		if sprite and not sprite.visible:
			return s
	var inst = _create_splat_instance()
	add_child(inst)
	pool.append(inst)
	return inst

func _create_splat_instance() -> Node2D:
	var inst := Node2D.new()
	var sprite = _configure_sprite(inst)
	sprite.visible = false
	return inst

func _configure_sprite(inst: Node2D) -> Sprite2D:
	var sprite = inst.get_node_or_null("Sprite") as Sprite2D
	if not sprite:
		sprite = Sprite2D.new()
		sprite.name = "Sprite"
		inst.add_child(sprite)
	if base_splat_texture:
		sprite.texture = base_splat_texture
	var mat = sprite.material
	if mat and mat is ShaderMaterial:
		if splat_shader and mat.shader != splat_shader:
			mat.shader = splat_shader
	else:
		mat = ShaderMaterial.new()
		mat.shader = splat_shader
		sprite.material = mat
	if mat and splat_shader:
		mat.set_shader_parameter("noise_tex", noise_tex)
	sprite.centered = true
	return sprite

func spawn_splat(global_pos: Vector2, radius := 64.0, color := Color(1, 0.2, 0.2)):
	var inst = _get_pooled()
	var sprite = inst.get_node_or_null("Sprite") as Sprite2D
	if not sprite:
		sprite = _configure_sprite(inst)
	sprite.visible = true
	var sscale = clamp(radius / float(base_splat_size) * 2.0, 0.2, 3.0)
	inst.scale = Vector2.ONE * sscale
	var mat = sprite.material
	if mat and mat is ShaderMaterial:
		mat.set_shader_parameter("seed", rng.randf())
		mat.set_shader_parameter("rim", rng.randf_range(0.7, 1.0))
		mat.set_shader_parameter("edge_rough", rng.randf_range(0.6, 1.2))
		mat.set_shader_parameter("noise_scale", rng.randf_range(3.0, 8.0))
		mat.set_shader_parameter("splat_color", color)
	if inst.get_parent() != draw_parent:
		if inst.get_parent():
			inst.get_parent().remove_child(inst)
		if draw_parent:
			draw_parent.add_child(inst)
		else:
			add_child(inst)
	inst.position = global_pos

func randf_range(a, b):
	return rng.randf() * (b - a) + a
