#version 410 core

in vec4 position;
uniform mat4 mv_matrix;

void main() {
    gl_Position = mv_matrix * position;
}
