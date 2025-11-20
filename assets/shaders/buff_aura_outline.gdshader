shader_type canvas_item;

// アウトラインの色（赤）
uniform vec4 outline_color : source_color = vec4(1.0, 0.0, 0.0, 1.0);
// アウトラインの幅（ピクセル単位）
uniform float outline_width : hint_range(0.0, 10.0) = 2.0;
// アウトラインの明滅強度（0.0-1.0）
uniform float pulse_intensity : hint_range(0.0, 1.0) = 0.5;

void fragment() {
	// COLORには既にmodulateが適用されている（赤色点滅を保持）
	vec4 modulated_color = COLOR;

	// 元のテクスチャの色を取得（アルファ値チェック用）
	vec4 texture_color = texture(TEXTURE, UV);

	// テクスチャのサイズを取得
	vec2 texture_size = vec2(textureSize(TEXTURE, 0));
	vec2 pixel_size = 1.0 / texture_size;

	// 周囲8方向をサンプリングしてアウトラインを検出
	float outline = 0.0;

	// 現在のピクセルが透明な場合のみアウトラインを描画
	if (texture_color.a < 0.1) {
		for (float x = -outline_width; x <= outline_width; x += 1.0) {
			for (float y = -outline_width; y <= outline_width; y += 1.0) {
				// 中心は除外
				if (x == 0.0 && y == 0.0) continue;

				// 周囲のピクセルをサンプリング
				vec2 offset = vec2(x, y) * pixel_size;
				float alpha = texture(TEXTURE, UV + offset).a;

				// 不透明なピクセルが周囲にあればアウトラインとして検出
				if (alpha > 0.1) {
					// 距離に応じてアウトラインの強度を調整（中心ほど強く）
					float dist = length(vec2(x, y)) / outline_width;
					outline = max(outline, (1.0 - dist) * alpha);
				}
			}
		}
	}

	// 元の色とアウトラインを合成
	if (texture_color.a > 0.1) {
		// 元のピクセルが不透明な場合、modulateが適用された色を表示（赤色点滅を維持）
		COLOR = modulated_color;
	} else if (outline > 0.0) {
		// 透明なピクセルでアウトラインが検出された場合、赤いオーラを描画
		// 明滅効果を適用（pulse_intensityで強度を調整）
		float alpha = outline * outline_color.a * pulse_intensity;
		COLOR = vec4(outline_color.rgb, alpha);
	} else {
		// アウトラインがない透明ピクセルはそのまま透明
		COLOR = vec4(0.0, 0.0, 0.0, 0.0);
	}
}
