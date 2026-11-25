// Passe plein écran : contour d'un pixel couleur encre autour des silhouettes (saut de profondeur)
// et fond papier washi légèrement grainé.
shader_type spatial;
render_mode unshaded, depth_draw_never, depth_test_disabled, cull_disabled, shadows_disabled;

uniform sampler2D depth_tex : hint_depth_texture, filter_nearest;
uniform vec3 ink : source_color = vec3(0.22, 0.17, 0.15);
uniform vec3 paper : source_color = vec3(0.93, 0.89, 0.81);

void vertex() {
	POSITION = vec4(VERTEX.xy, 1.0, 1.0);
}

float lin_depth(vec2 uv, mat4 inv_proj) {
	float d = texture(depth_tex, uv).r;
	vec4 v = inv_proj * vec4(uv * 2.0 - 1.0, d, 1.0);
	return -v.z / v.w;
}

void fragment() {
	vec2 px = 1.0 / VIEWPORT_SIZE;
	ALPHA = 1.0;  // passe transparente : la seule qui peut lire la profondeur
	float c = lin_depth(SCREEN_UV, INV_PROJECTION_MATRIX);
	if (c > 15.0) {
		float g = fract(sin(dot(floor(FRAGCOORD.xy), vec2(12.9898, 78.233))) * 43758.5453);
		ALBEDO = paper * (0.975 + 0.025 * g);
	} else {
		float m = 0.0;
		m = max(m, lin_depth(SCREEN_UV + vec2(px.x, 0.0), INV_PROJECTION_MATRIX) - c);
		m = max(m, lin_depth(SCREEN_UV - vec2(px.x, 0.0), INV_PROJECTION_MATRIX) - c);
		m = max(m, lin_depth(SCREEN_UV + vec2(0.0, px.y), INV_PROJECTION_MATRIX) - c);
		m = max(m, lin_depth(SCREEN_UV - vec2(0.0, px.y), INV_PROJECTION_MATRIX) - c);
		if (m < 0.01 + c * 0.03) {
			discard;
		}
		ALBEDO = ink;
	}
}
