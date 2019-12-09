#version 410 core

// 输入变量
layout (location = 0) in vec4 position;
layout (location = 1) in vec3 normal;

// 统一变量
uniform mat4 mv_matrix;
uniform mat4 proj_matrix;
uniform vec3 light_pos = vec3(100.0, 100.0, 100.0);

// 输出变量
out VS_OUT {
    vec3 N;
    vec3 L;
    vec3 V;
} vs_out;

void main(void) {
    // 计算顶点在视图空间的位置
    vec4 P = mv_matrix * position;

    // 将法向量从物体坐标系转换到视图坐标系
    vs_out.N = mat3(mv_matrix) * normal;
    // 计算视图坐标系中的光源向量
    vs_out.L = light_pos - P.xyz;
    // 计算视图坐标系中的观察点向量
    vs_out.V = -P.xyz;

    // 计算顶点在投影坐标系中的坐标
    gl_Position = proj_matrix * P;
}
