#version 410 core

uniform sampler2D s;
uniform float exposure;

out vec4 color;

void main() {
    color = texture(s, 2.0 * gl_FragCoord.xy/ textureSize(s, 0));
}
