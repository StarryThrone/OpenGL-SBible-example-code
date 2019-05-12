#version 410 core

out vec4 color;

in VS_OUT {
    vec2 tc;
} fs_in;

void main() {
    float val = abs(fs_in.tc.x + fs_in.tc.y) * 20.0f;
    color = vec4(fract(val) >= 0.5 ? 1.0 : 0.25);
}
