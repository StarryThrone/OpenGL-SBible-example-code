#version 410 core

in GS_OUT {
    vec4 color;
    vec3 normal;
} fs_in;

out vec4 color;

void main() {
    // 法向量的计算存在一定问题
//    color = vec4(abs(fs_in.normal.z) * fs_in.color.rgb, 1.0);
    color = fs_in.color;
}
