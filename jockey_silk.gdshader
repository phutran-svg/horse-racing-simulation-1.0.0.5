shader_type spatial;
// Jockey body: the outfit albedo (one of the 40 catalogue silks, or the base outfit for other owners), the shared
// fabric normal / roughness-metal maps, owner colours painted over the shirt and cap areas (masks from the
// texture set, fabric folds kept from the shading map) and the JRA bracket cap overlay.

uniform sampler2D albedo_tex : source_color, filter_linear_mipmap, repeat_disable;
uniform sampler2D normal_tex : hint_normal, filter_linear_mipmap, repeat_disable;
uniform sampler2D pbr_tex : hint_default_white, filter_linear_mipmap, repeat_disable;   // G roughness, B metal (glTF)
uniform sampler2D cap_tex : source_color, hint_default_transparent, filter_linear_mipmap, repeat_disable;
uniform sampler2D shirt_mask : hint_default_black, filter_linear_mipmap, repeat_disable;
uniform sampler2D cap_mask : hint_default_black, filter_linear_mipmap, repeat_disable;
uniform sampler2D shade_tex : hint_default_white, filter_linear_mipmap, repeat_disable;
uniform float tint_shirt = 0.0;
uniform float tint_cap = 0.0;
uniform vec3 shirt_col : source_color = vec3(1.0);
uniform vec3 cap_col : source_color = vec3(1.0);
uniform float use_cap_tex = 0.0;

void fragment() {
	vec3 a = texture(albedo_tex, UV).rgb;
	float shade = texture(shade_tex, UV).r * 1.99;          // mean of the shading map is ~0.5
	a = mix(a, shirt_col * shade, texture(shirt_mask, UV).r * tint_shirt);
	a = mix(a, cap_col * shade, texture(cap_mask, UV).r * tint_cap);
	vec4 c = texture(cap_tex, UV);
	a = mix(a, c.rgb, c.a * use_cap_tex);
	ALBEDO = a;
	vec3 p = texture(pbr_tex, UV).rgb;
	ROUGHNESS = p.g;
	METALLIC = p.b;
	NORMAL_MAP = texture(normal_tex, UV).rgb;
}
