#version 300 es
// Invert colors shader

precision mediump float;

in vec2 v_texcoord;
out vec4 fragColor;

uniform sampler2D tex;

void main() {
    vec4 pixColor = texture(tex, v_texcoord);
    pixColor.rgb = 1.0 - pixColor.rgb;
    fragColor = pixColor;
}
