#version 410 core

// 输入变量
in VS_OUT {
    vec3 normal;
    vec3 view;
} fs_in;

// 统一变量：立方体环境纹理采样器
uniform samplerCube tex_cubemap;

// 输出变量
out vec4 color;

void main(void) {
    // 1. 计算片段的反射向量，追踪光源位置
    vec3 r = reflect(fs_in.view, normalize(fs_in.normal));

    // 2. 使用反射向量在立方体环境纹理中采样，计算出该片段应该反射的环境颜色
    // 再乘以其材质属性的漫反射率得到最终的颜色
    color = texture(tex_cubemap, r) * vec4(0.95, 0.80, 0.45, 1.0);
}
