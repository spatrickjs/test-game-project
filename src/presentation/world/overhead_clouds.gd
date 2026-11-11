extends Sprite2D
## World-space decoration. Independent of the simulation and its RNG streams.

var _drift: Vector2 = Vector2.ZERO


func _ready() -> void:
	z_index = 80
	centered = false
	var noise: FastNoiseLite = FastNoiseLite.new()
	noise.seed = 731
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.frequency = 0.012
	noise.fractal_octaves = 3
	var cloud_texture: NoiseTexture2D = NoiseTexture2D.new()
	cloud_texture.width = 512
	cloud_texture.height = 512
	cloud_texture.seamless = true
	cloud_texture.noise = noise
	texture = cloud_texture
	var cloud_material: ShaderMaterial = ShaderMaterial.new()
	cloud_material.shader = preload("res://src/presentation/world/overhead_clouds.gdshader")
	cloud_material.set_shader_parameter("cloud_noise", cloud_texture)
	material = cloud_material


func cover_overview(center: Vector2, overview_size: Vector2) -> void:
	global_position = center - overview_size * 0.5
	scale = overview_size / Vector2(512, 512)
	material.set_shader_parameter("world_origin", global_position)
	material.set_shader_parameter("world_size", overview_size)


func _process(delta: float) -> void:
	_drift += Vector2(9.0, 3.0) * delta
	_drift.x = fposmod(_drift.x, 1500.0)
	_drift.y = fposmod(_drift.y, 1500.0)
	material.set_shader_parameter("drift", _drift)
