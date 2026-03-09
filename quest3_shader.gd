@tool
extends Node

# --- Exported TextureRects ---
@export var source: TextureRect      # Source TextureRect (containing Y/U/V planes)
@export var destination: TextureRect # Destination TextureRect for RGB output

# Optional parameters
@export var use_limited_range: bool = false
@export var chroma_scale: Vector2 = Vector2(0.5, 0.5)

# Internal ShaderMaterial
var shader_mat: ShaderMaterial

func _ready():
	if not source or not destination:
		push_warning("Please assign both source and destination TextureRects!")
		return

	# --- Create ShaderMaterial ---
	shader_mat = ShaderMaterial.new()
	shader_mat.shader = Shader.new()
	shader_mat.shader.code = """
        shader_type canvas_item;

        uniform sampler2D y_tex;
        uniform sampler2D u_tex;
        uniform sampler2D v_tex;
        uniform vec2 chroma_scale = vec2(0.5, 0.5);
        uniform int use_limited_range = 0;

        vec3 yuv_to_rgb_fullrange(float y, float u, float v) {
            float Y = y;
            float U = u - 0.5;
            float V = v - 0.5;
            return vec3(Y + 1.4020*V, Y - 0.344136*U - 0.714136*V, Y + 1.7720*U);
        }

        vec3 yuv_to_rgb_limited(float y, float u, float v) {
            float Y = max((y - 16.0/255.0) * 1.164383,0.0);
            float U = u - 0.5;
            float V = v - 0.5;
            return vec3(Y + 1.596027*V, Y - 0.391762*U - 0.812968*V, Y + 2.017232*U);
        }

        void fragment() {
            vec2 uv = UV;
            float Y = texture(y_tex, uv).r;
            vec2 cuv = uv * chroma_scale;
            float U = texture(u_tex, cuv).r;
            float V = texture(v_tex, cuv).r;

            vec3 rgb = (use_limited_range == 1)
                ? yuv_to_rgb_limited(Y,U,V)
                : yuv_to_rgb_fullrange(Y,U,V);

            COLOR = vec4(rgb,1.0);
        }
	"""

	# --- Assign dummy texture if destination has none ---
	if destination.texture == null:
		var dummy = ImageTexture.new()
		var img = Image.new()
		img.create(1, 1, false, Image.FORMAT_RGBA8)
		img.fill(Color(1,1,1,1))
		dummy.create_from_image(img)
		destination.texture = dummy

	# Assign shader material to destination
	destination.material = shader_mat

	# Initialize shader parameters
	_update_shader_params()

func _process(_delta):
	_update_shader_params()

func _update_shader_params():
	if not shader_mat:
		return

	# --- Fetch YUV textures from source ---
	# Expecting three children of source TextureRect: "Y", "U", "V"
	var y_tex = source.get_node_or_null("Y") as TextureRect
	var u_tex = source.get_node_or_null("U") as TextureRect
	var v_tex = source.get_node_or_null("V") as TextureRect

	if y_tex and y_tex.texture:
		shader_mat.set_shader_parameter("y_tex", y_tex.texture)
	if u_tex and u_tex.texture:
		shader_mat.set_shader_parameter("u_tex", u_tex.texture)
	if v_tex and v_tex.texture:
		shader_mat.set_shader_parameter("v_tex", v_tex.texture)

	shader_mat.set_shader_parameter("use_limited_range", int(use_limited_range))
	shader_mat.set_shader_parameter("chroma_scale", chroma_scale)
