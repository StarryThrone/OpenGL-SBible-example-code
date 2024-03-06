#version 100

precision mediump float;

varying vec4 vs_color;

void main() {
    gl_FragColor = vs_color;
}
