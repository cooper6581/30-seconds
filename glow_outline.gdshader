shader_type canvas_item;

uniform float glow_strength : hint_range(0.0, 5.0) = 1.5;
uniform vec4 glow_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float outline_width : hint_range(0.0, 10.0) = 2.0;

void fragment() {
    vec2 size = TEXTURE_PIXEL_SIZE * outline_width;
    vec4 sprite = texture(TEXTURE, UV);
    
    float outline = 0.0;
    outline += texture(TEXTURE, UV + vec2(-size.x, 0)).a;
    outline += texture(TEXTURE, UV + vec2(size.x, 0)).a;
    outline += texture(TEXTURE, UV + vec2(0, -size.y)).a;
    outline += texture(TEXTURE, UV + vec2(0, size.y)).a;
    outline += texture(TEXTURE, UV + vec2(-size.x, -size.y)).a;
    outline += texture(TEXTURE, UV + vec2(size.x, -size.y)).a;
    outline += texture(TEXTURE, UV + vec2(-size.x, size.y)).a;
    outline += texture(TEXTURE, UV + vec2(size.x, size.y)).a;
    outline = min(outline, 1.0);
    
    vec4 color = sprite;
    if (sprite.a == 0.0 && outline > 0.0) {
        color = glow_color * glow_strength;
        color.a = outline * 0.5;
    }
    
    COLOR = color;
}