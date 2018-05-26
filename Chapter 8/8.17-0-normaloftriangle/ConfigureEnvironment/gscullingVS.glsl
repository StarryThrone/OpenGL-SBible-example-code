#version 410 core

layout (location = 0) in vec3 position;
layout (location = 2) in vec3 color;

out vec3 vertexColor;

void main() {
    gl_Position = vec4(position, 1.0);
    vertexColor = color;
}
