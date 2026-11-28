// Style « encre et papier » (étape 26) : passe plein écran sur la scène 3D (l'interface n'est pas touchée).
// Couleurs d'origine posées en lavis (fondues et éclaircies vers le papier), traits d'encre au pinceau,
// stries de pinceau sec sur les foncés, grain du papier, fond de papier blanc avec un soleil rouge en lavis.
// Prototype : check/encre.py.
shader_type spatial;
render_mode unshaded, cull_disabled, depth_test_disabled, depth_draw_never, fog_disabled;

uniform sampler2D screen_tex : hint_screen_texture, filter_linear;
uniform sampler2D depth_tex : hint_depth_texture, filter_nearest;
uniform vec3 paper : source_color = vec3(0.97, 0.955, 0.93);
uniform vec3 ink : source_color = vec3(0.08, 0.075, 0.075);
uniform vec3 sun_color : source_color = vec3(0.8, 0.14, 0.13);
uniform float sun = 1.0;  // soleil au jardin seulement

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

void vertex() {
	POSITION = vec4(VERTEX.xy, 1.0, 1.0);  // quad 2 × 2 collé à l'écran
}

void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 px = 1.0 / VIEWPORT_SIZE;
	vec3 c = texture(screen_tex, uv).rgb;
	// lavis : couleur un peu fondue, éclaircie vers le papier
	vec3 b = (c * 2.0 + texture(screen_tex, uv + vec2(px.x, 0.0)).rgb + texture(screen_tex, uv - vec2(px.x, 0.0)).rgb
			+ texture(screen_tex, uv + vec2(0.0, px.y)).rgb + texture(screen_tex, uv - vec2(0.0, px.y)).rgb) / 6.0;
	vec3 col = mix(b, paper, 0.18);
	float lum = dot(pow(c, vec3(1.0 / 2.2)), vec3(0.3, 0.59, 0.11));  // luminosité perçue
	// traits d'encre (contours) : densité qui varie par touches, comme au pinceau
	if (lum < 0.15) {
		col = mix(col, ink, 0.6 + 0.4 * hash(floor(uv * VIEWPORT_SIZE / 6.0)));
	}
	// pinceau sec : fines stries horizontales sur les zones foncées
	if (lum < 0.35) {
		col *= 0.85 + 0.15 * hash(vec2(floor(uv.y * VIEWPORT_SIZE.y / 2.0), 3.1));
	}
	// fond (rien de dessiné : profondeur nulle en Z inversé) : papier et grand soleil rouge en lavis
	if (texture(depth_tex, uv).r == 0.0) {
		vec2 q = (uv - vec2(0.68, 0.2)) * vec2(VIEWPORT_SIZE.x / VIEWPORT_SIZE.y, 1.0);
		float s = 1.0 - smoothstep(0.16, 0.175, length(q));
		s *= 0.9 - 0.55 * clamp((uv.y - 0.03) / 0.35, 0.0, 1.0);  // plus pâle vers le bas, comme un lavis
		col = mix(paper, sun_color, s * sun);
	}
	col *= 1.0 + (hash(floor(uv * VIEWPORT_SIZE)) - 0.5) * 0.036;  // grain du papier
	ALBEDO = col;
}
