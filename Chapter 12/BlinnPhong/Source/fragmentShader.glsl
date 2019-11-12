#version 410 core

// 输出变量
layout (location = 0) out vec4 color;

// 输入变量
in VS_OUT {
    vec3 N;
    vec3 L;
    vec3 V;
} fs_in;

// 材质属性
uniform vec3 diffuseAlbedo = vec3(0.5, 0.2, 0.7);
uniform vec3 specularAlbedo = vec3(0.7);
uniform float specularPower = 200.0;

void main(void) {
    // 向量标准化
    vec3 N = normalize(fs_in.N);
    vec3 L = normalize(fs_in.L);
    vec3 V = normalize(fs_in.V);
    // 计算冯氏宾氏着色模型中的中间向量H
    vec3 H = normalize(L + V);

    // 计算漫射光和反射光
    vec3 diffuse = max(dot(N, L), 0.0) * diffuseAlbedo;
    vec3 specular = pow(max(dot(N, H), 0.0), specularPower) * specularAlbedo;

    // 将颜色信息写入帧缓存
    color = vec4(diffuse + specular, 1.0);
}

