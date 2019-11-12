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
uniform vec3 diffuseAlbedo = vec3(0.3, 0.5, 0.2);
uniform vec3 specularAlbedo = vec3(0.7);
uniform float specularPower = 128.0;
uniform vec3 rimColor = vec3(0.1, 0.7, 0.2);
uniform float rimPower = 5.0;

// 计算轮廓光颜色
vec3 calculateRimColor(vec3 N, vec3 V) {
    float f = 1.0 - dot(N, V);

    f = smoothstep(0.0, 1.0, f);
    f = pow(f, rimPower);
    return f * rimColor;
}

void main(void) {
    // 向量标准化
    vec3 N = normalize(fs_in.N);
    vec3 L = normalize(fs_in.L);
    vec3 V = normalize(fs_in.V);
    // 计算负光线入射向量的反射向量
    vec3 R = reflect(-L, N);

    // 计算漫射光颜色、反射光颜色、和轮廓光颜色
    vec3 diffuseColor = max(dot(N, L), 0.0) * diffuseAlbedo;
    vec3 specularColor = pow(max(dot(R, V), 0.0), specularPower) * specularAlbedo;
    vec3 rimColor = calculateRimColor(N, V);

    // 将颜色信息写入帧缓存
    color = vec4(diffuseColor + specularColor + rimColor, 1.0);
}

