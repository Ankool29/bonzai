// Feuillage : petites images pixel art (PixelLab) toujours tournées vers la caméra, une par instance
// de MultiMesh. INSTANCE_CUSTOM.x = variante dans l'atlas, .y = rotation dans le plan de l'image,
// COLOR = teinte (saison, ombre, sélection).
shader_type spatial;
render_mode cull_disabled, unshaded;

uniform sampler2D atlas : source_color, filter_nearest;
uniform float frames = 3.0;

varying float frame;

void vertex() {
	float r = INSTANCE_CUSTOM.y;
	VERTEX.xy = mat2(vec2(cos(r), sin(r)), vec2(-sin(r), cos(r))) * VERTEX.xy;
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
	MODELVIEW_MATRIX = MODELVIEW_MATRIX * mat4(
		vec4(length(MODEL_MATRIX[0].xyz), 0.0, 0.0, 0.0),
		vec4(0.0, length(MODEL_MATRIX[1].xyz), 0.0, 0.0),
		vec4(0.0, 0.0, length(MODEL_MATRIX[2].xyz), 0.0),
		vec4(0.0, 0.0, 0.0, 1.0));
	frame = INSTANCE_CUSTOM.x;
}

void fragment() {
	vec4 c = texture(atlas, vec2((clamp(UV.x, 0.0, 0.999) + floor(frame + 0.5)) / frames, UV.y));
	ALBEDO = c.rgb * COLOR.rgb;
	ALPHA = c.a;
	ALPHA_SCISSOR_THRESHOLD = 0.5;
}
