#version 300 es
// Chromatic aberration — subtle directional RGB channel split
// Red channel shifted left, blue shifted right

precision highp float;

in vec2 v_texcoord;
out vec4 fragColor;

uniform sampler2D tex;

// Offset in UV space (~1.5px at 1920 width)
#define OFFSET 0.00075

void main() {
    float r = texture(tex, v_texcoord + vec2(OFFSET, 0.0)).r;
    float g = texture(tex, v_texcoord).g;
    float b = texture(tex, v_texcoord + vec2(-OFFSET, 0.0)).b;
    fragColor = vec4(r, g, b, 1.0);
}
