#version 410 core

// 输出变量
layout (location = 0) out vec4 color;

// 输入变量
in VS_OUT {
    vec3 color;
} fs_in;

void main(void) {
    // 将颜色信息写入帧缓存
    color = vec4(fs_in.color, 1.0);
}
