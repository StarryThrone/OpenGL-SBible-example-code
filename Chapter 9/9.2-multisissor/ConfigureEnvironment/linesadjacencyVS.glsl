#version 410 core

in vec4 position;

out VS_OUT {
    vec4 color;
} vs_out;

void main() {
    gl_Position = position;
//    vs_out.color = position * 2.0 + vec4(0.5, 0.5, 0.5, 0.0);
    vs_out.color = vec4(1.0, 1.0, 1.0, 1.0);
}
