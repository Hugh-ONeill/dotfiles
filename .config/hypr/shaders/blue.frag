#version 300 es
// Blue filter shader

precision mediump float;

in vec2 v_texcoord;
out vec4 fragColor;

uniform sampler2D tex;
uniform float time;
uniform vec2 topLeft;
uniform vec2 fullSize;

void main() {
    vec4 pixColor = texture(tex, v_texcoord);
    pixColor[0] *= 0.7;
    fragColor = pixColor;
}
