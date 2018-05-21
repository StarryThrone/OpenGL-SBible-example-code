#version 410 core

in vec4 position;
uniform mat4 mvp_matrix;

void main() {
    gl_Position = mvp_matrix * position;
}
