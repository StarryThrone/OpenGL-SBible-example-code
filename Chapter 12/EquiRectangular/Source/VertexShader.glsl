#version 410 core

// 输入变量
layout (location = 0) in vec4 position;
layout (location = 1) in vec3 normal;

// 统一变量
uniform mat4 mv_matrix;
uniform mat4 proj_matrix;

// 输出变量
out VS_OUT {
    vec3 normal;
    vec3 view;
} vs_out;

void main(void) {
    // 计算顶点在相机空间中的位置
    vec4 pos_vs = mv_matrix * position;

    // 将模型坐标系的法向量向视图坐标系转换
    vs_out.normal = mat3(mv_matrix) * normal;
    // 计算观测向量
    vs_out.view = pos_vs.xyz;

    // 计算顶点在投影空间中的位置
    gl_Position = proj_matrix * pos_vs;
}
