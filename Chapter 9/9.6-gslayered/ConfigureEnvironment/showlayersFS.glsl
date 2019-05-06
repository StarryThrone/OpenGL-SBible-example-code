#version 410 core

uniform sampler2DArray texArray;

out vec4 color;

in VS_OUT {
    vec3 tc;
} fs_in;

void main() {
    color = texture(texArray, fs_in.tc);
}
