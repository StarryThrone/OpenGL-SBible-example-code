#version 410 core

out vec4 color;

in GS_OUT {
    vec4 color;
} fs_in;

void main() {
    color = fs_in.color;
}
