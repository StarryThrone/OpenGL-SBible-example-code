#version 100

attribute vec4 position;
attribute vec3 color;
attribute vec4 offset;

varying vec4 vs_color;

void main() {
    gl_Position = position + offset;
    vs_color = vec4(color, 1.0);
}
