shader_type spatial;
render_mode depth_prepass_alpha;

uniform sampler2D mask : repeat_disable;
uniform vec4 my_color : source_color = vec4(1.0, 0.0, 0.0, 1.0);
uniform float glow_amount = 1.0; // Glow multiplier

void vertex() {
	vec3 face_vec3 = -MODEL_MATRIX[1].xyz;
	vec4 face_vec4 = -MODEL_MATRIX[1];
	
	float vec_dif = abs(dot(MODEL_MATRIX[0].xyz, CAMERA_DIRECTION_WORLD));
	
	MODELVIEW_MATRIX = VIEW_MATRIX * 
	mat4(
		vec4(normalize(cross(face_vec3, INV_VIEW_MATRIX[2].xyz)), 0.0),
		face_vec4,
		vec4(normalize(cross(INV_VIEW_MATRIX[0].xyz, face_vec3)), 0.0),
		MODEL_MATRIX[3]
	);
}


void fragment() {
    vec4 mask_texture = texture(mask, UV);
    ALBEDO = my_color.rgb;
    ALPHA = mask_texture.r;
    
    // Outputs values > 1.0 to trigger WorldEnvironment glow
    EMISSION = my_color.rgb * mask_texture.r * glow_amount;
}