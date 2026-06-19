shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_front, shadows_disabled, depth_test_disabled;

uniform sampler2D albedo_texture : source_color, filter_linear_mipmap;
uniform sampler2D depth_texture : hint_depth_texture, filter_nearest;
uniform vec4 albedo_color : source_color = vec4(1.0);
uniform float normal_threshold : hint_range(0.0, 1.0) = 0.5;

void fragment() {
	// Sample depth buffer at this screen pixel
	float depth = textureLod(depth_texture, SCREEN_UV, 0.0).r;

	// Reconstruct view-space position from screen UV + depth
	vec4 ndc = vec4(SCREEN_UV * 2.0 - 1.0, depth, 1.0);
	vec4 view_pos = INV_PROJECTION_MATRIX * ndc;
	view_pos.xyz /= view_pos.w;

	// View space -> World space
	vec3 world_pos = (INV_VIEW_MATRIX * vec4(view_pos.xyz, 1.0)).xyz;

	// World space -> Local space of the decal box
	vec3 local_pos = (inverse(MODEL_MATRIX) * vec4(world_pos, 1.0)).xyz;

	// Reject pixels outside the unit cube [-0.5, 0.5]
	if (abs(local_pos.x) > 0.5 || abs(local_pos.y) > 0.5 || abs(local_pos.z) > 0.5) {
		discard;
	}

	// Reconstruct world-space surface normal from depth derivatives
	vec3 ddx_wp = dFdx(world_pos);
	vec3 ddy_wp = dFdy(world_pos);
	vec3 cross_norm = cross(ddx_wp, ddy_wp);
	vec3 world_normal = vec3(0.0, 1.0, 0.0);
	if (length(cross_norm) > 0.0001) {
		world_normal = normalize(cross_norm);
	}

	// Get the decal's projection axis (local Y) in world space
	vec3 decal_up = normalize((MODEL_MATRIX * vec4(0.0, 1.0, 0.0, 0.0)).xyz);

	// Reject surfaces too steep relative to the projection axis
	// A threshold of 0.5 rejects surfaces steeper than ~60 degrees from horizontal
	if (abs(dot(world_normal, decal_up)) < normal_threshold) {
		discard;
	}

	// Project local XZ onto UV coordinates [0.0, 1.0]
	vec2 uv = local_pos.xz + 0.5;
	vec4 tex_color = texture(albedo_texture, uv);

	ALBEDO = tex_color.rgb * albedo_color.rgb;
	ALPHA = tex_color.a * albedo_color.a;
	
}
