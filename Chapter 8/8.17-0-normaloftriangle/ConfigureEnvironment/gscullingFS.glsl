#version 410 core

in vec3 primitiveColor;

out vec4 color;

void main() {
    color = vec4(primitiveColor, 1.0);
}
