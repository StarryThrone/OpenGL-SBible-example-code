#version 410 core

layout (location = 0) in vec4 position;
layout (location = 1) in vec3 normal;

out VS_OUT {
    vec3 normal;
} vs_out;

void main() {
    gl_Position = position;
    vs_out.normal = normal;
}
