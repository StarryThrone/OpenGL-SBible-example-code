#version 410 core

// 顶点属性
layout (location = 0) in vec4 position;
layout (location = 1) in vec3 normal;

// 统一变量
// 观察矩阵
uniform mat4 viewMatrix;
// 投影矩阵
uniform mat4 perspectiveMatrix;

// 模型矩阵闭包数据
layout (std140) uniform ModelMatrixs {
    mat4 matrixs[64];
} modelMatrixs;

// 输出变量
out VS_OUT {
    // 顶点在相机空间中的法向量
    vec3 normal;
} vs_out;

void main() {
    // 计算顶点在投影坐标系中的位置
    gl_Position = perspectiveMatrix * viewMatrix * modelMatrixs.matrixs[gl_InstanceID] * position;
    // 计算顶点在相机空间中的法向量
    vs_out.normal = mat3(viewMatrix) * mat3(modelMatrixs.matrixs[gl_InstanceID]) * normal;
}
