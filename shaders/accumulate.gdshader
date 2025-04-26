shader_type canvas_item;


uniform int NumRenderedFrames;
uniform sampler2D oldTex : hint_screen_texture;
uniform sampler2D newTex;

void fragment() {
	vec4 oldRender = texture(oldTex, UV);
	vec4 newRender = texture(newTex, UV);


	float weight = 1.0 / float(NumRenderedFrames + 1);
	vec4 accumulatedAverage = oldRender * (1.0 - weight) + newRender * weight * 2.0;

	COLOR = accumulatedAverage;
}
