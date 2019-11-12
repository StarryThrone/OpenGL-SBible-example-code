#version 410 core

// 顶点属性输入变量
layout (location = 0) in vec4 position;
layout (location = 1) in vec3 normal;

// 仿射矩阵
uniform mat4 modelViewMatrix;
uniform mat4 projectionMatrix;

// 输出变量
out VS_OUT {
    vec3 N;
    vec3 L;
    vec3 V;
} vs_out;

// 光源位置
uniform vec3 lightPosition = vec3(100.0, 100.0, 100.0);

void main(void) {
    // 计算顶点在相机空间的位置
    vec4 P = modelViewMatrix * position;
    // 计算相机空间的顶点法向量
    vs_out.N = mat3(modelViewMatrix) * normal;
    // 计算相机空间的光源向量
    vs_out.L = lightPosition - P.xyz;
    // 计算观察点向量
    vs_out.V = -P.xyz;

    // 计算每个顶点位于裁剪空间内的位置
    gl_Position = projectionMatrix * P;
}
