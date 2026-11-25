// Voxels : trois tons fixes selon la face (dessus clair, côtés moyens, dessous sombre).
shader_type spatial;
render_mode unshaded;

varying vec3 world_normal;

void vertex() {
	world_normal = (MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz;
}

void fragment() {
	vec3 n = normalize(world_normal);
	float tone = n.y > 0.5 ? 1.1 : (n.y < -0.5 ? 0.55 : (abs(n.x) > 0.5 ? 0.86 : 0.72));
	ALBEDO = COLOR.rgb * tone;
}
