#version 410 core

// 顶点属性输入变量
layout (location = 0) in vec4 position;
layout (location = 1) in vec3 normal;

// 仿射矩阵
layout (std140) uniform transformMatrixs {
    mat4 viewMatrix;
    mat4 modelViewMatrix;
    mat4 projectionMatrix;
};

// 光源和材质属性
uniform vec3 lightPosition = vec3(100.0, 100.0, 100.0);
uniform vec3 diffuseAlbedo = vec3(0.5, 0.2, 0.7);
uniform vec3 specularAlbedo = vec3(0.7);
uniform float specularPower = 128.0;
uniform vec3 ambientColor = vec3(0.1, 0.1, 0.1);

// 输出变量
out VS_OUT {
    vec3 color;
} vs_out;

void main(void) {
    // 计算顶点在相机空间的位置
    vec4 P = modelViewMatrix * position;

    // 计算相机空间的顶点法向量
    vec3 N = mat3(modelViewMatrix) * normal;
    // 计算相机空间的光源向量
    vec3 L = lightPosition - P.xyz;
    // 计算观察点向量
    vec3 V = -P.xyz;

    // 向量标准化
    N = normalize(N);
    L = normalize(L);
    V = normalize(V);
    // 计算负光线入射向量的反射向量
    vec3 R = reflect(-L, N);

    // 计算漫射光和反射光
    vec3 diffuseColor = max(dot(N, L), 0.0) * diffuseAlbedo;
    vec3 specularColor = pow(max(dot(R, V), 0.0), specularPower) * specularAlbedo;

    // 计算顶点的最终输出颜色
    vs_out.color = ambientColor + diffuseColor + specularColor;

    // 计算每个顶点位于裁剪空间内的位置
    gl_Position = projectionMatrix * P;
}
