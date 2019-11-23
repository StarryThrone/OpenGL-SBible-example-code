#version 410 core

// 输入变量
layout (location = 0) in vec4 position;
layout (location = 1) in vec3 normal;

// 统一变量：仿射矩阵
uniform mat4 mv_matrix;
uniform mat4 proj_matrix;

// 输出变量
out VS_OUT {
    vec3 normal;
    vec3 view;
} vs_out;

void main(void) {
    // 1. 计算顶点在视图坐标系中的坐标
    vec4 pos_vs = mv_matrix * position;
    // 2. 将顶点法向量转换到视图坐标系
    vs_out.normal = mat3(mv_matrix) * normal;
    // 3. 计算兴趣点点观察矩阵
    vs_out.view = pos_vs.xyz;
    // 4. 计算顶点在投影坐标系下的坐标
    gl_Position = proj_matrix * pos_vs;
}
