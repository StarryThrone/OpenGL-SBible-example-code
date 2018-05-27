#version 410 core

flat in vec4 color;

out vec4 output_color;

void main() {
    output_color = color;
//    output_color = vec4(1.0);

}
