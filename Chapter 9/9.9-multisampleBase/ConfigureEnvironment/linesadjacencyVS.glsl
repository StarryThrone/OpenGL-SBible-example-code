#version 410 core

in vec4 position;

uniform mat4 mv_matrix;
uniform mat4 proj_matrix;

void main() {
    gl_Position = proj_matrix * mv_matrix * position;
}
