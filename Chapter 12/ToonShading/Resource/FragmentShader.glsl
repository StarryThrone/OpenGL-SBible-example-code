#version 410 core

// 输入变量
in VS_OUT {
    vec3 normal;
    vec3 view;
} fs_in;

// 统一变量
// 颜色纹理采样器
uniform sampler1D tex_toon;
uniform vec3 light_pos = vec3(30.0, 30.0, 100.0);

// 输出变量
out vec4 color;

void main(void) {
    // 计算法向量和光源向量，并标准化处理
    vec3 N = normalize(fs_in.normal);
    vec3 L = normalize(light_pos - fs_in.view);

    // 根据光源向量和法向量的夹角，计算出纹理的坐标
    float tc = pow(max(0.0, dot(N, L)), 5.0);

    // 从卡通色纹理中采样，并适当弱化颜色
    color = texture(tex_toon, tc) * (tc * 0.8 + 0.2);
}
