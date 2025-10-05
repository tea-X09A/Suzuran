shader_type canvas_item;

uniform float fade_width : hint_range(0.0, 1.0) = 0.2;
uniform float direction : hint_range(-1.0, 1.0) = 1.0; // 1.0 = right, -1.0 = left

void fragment() {
	vec4 color = COLOR;

	// 画面座標を0.0-1.0に正規化
	float x = UV.x;

	// 方向に応じてフェード計算
	float fade = 1.0;

	if (direction > 0.0) {
		// 右方向: 左端をフェード
		fade = smoothstep(0.0, fade_width, x);
	} else {
		// 左方向: 右端をフェード
		fade = smoothstep(1.0, 1.0 - fade_width, x);
	}

	COLOR = vec4(color.rgb, color.a * fade);
}
