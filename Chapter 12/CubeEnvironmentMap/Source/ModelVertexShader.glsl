#version 410 core

layout (location = 0) in vec4 position;
layout (location = 1) in vec3 normal;

uniform mat4 mv_matrix;
uniform mat4 proj_matrix;

out VS_OUT {
    vec3 normal;
    vec3 view;
} vs_out;

void main(void) {
    vec4 pos_vs = mv_matrix * position;

    vs_out.normal = mat3(mv_matrix) * normal;
    vs_out.view = pos_vs.xyz;

    gl_Position = proj_matrix * pos_vs;
}
