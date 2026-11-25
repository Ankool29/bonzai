// Éclairage en aplats façon estampe : trois tons par couleur, ombre teintée indigo.
shader_type spatial;
render_mode unshaded, cull_disabled;

uniform vec4 tint : source_color = vec4(1.0);
uniform vec3 sun = vec3(0.45, 0.8, 0.4);

varying vec3 world_normal;

void vertex() {
	world_normal = (MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz;
}

void fragment() {
	vec3 base = COLOR.rgb * tint.rgb;
	float l = dot(normalize(world_normal), normalize(sun));
	vec3 shade = base * vec3(0.52, 0.56, 0.74);
	vec3 mid = mix(shade, base, 0.55);
	ALBEDO = l > 0.4 ? base : (l > -0.05 ? mid : shade);
}
