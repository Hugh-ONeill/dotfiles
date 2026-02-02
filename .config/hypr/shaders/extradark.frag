#version 300 es
// Extra dark / blue light filter shader
// values from https://reshade.me/forum/shader-discussion/3673-blue-light-filter-similar-to-f-lux

precision mediump float;

in vec2 v_texcoord;
out vec4 fragColor;

uniform sampler2D tex;

void main() {
    vec4 pixColor = texture(tex, v_texcoord);
    pixColor[0] *= 0.7;  // red
    pixColor[1] *= 0.6;  // green
    pixColor[2] *= 0.5;  // blue
    fragColor = pixColor;
}
