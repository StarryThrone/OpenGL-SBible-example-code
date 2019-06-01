#version 410 core

flat in vec4 startColor;

out vec4 color;

uniform sampler2D tex_star;

void main() {
    color = startColor * texture(tex_star, gl_PointCoord);
}
