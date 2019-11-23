#version 410 core

// 统一变量：立方体环境贴图采样器
uniform samplerCube tex_cubemap;

// 输入变量
in VS_OUT {
    vec3    tc;
} fs_in;

// 输出变量
layout (location = 0) out vec4 color;

void main(void) {
    // 计算该片段的最终颜色
    color = texture(tex_cubemap, fs_in.tc);
}
