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
    // 计算顶点在视图坐标系中的坐标
    vec4 pos_vs = mv_matrix * position;

    // 计算视图空间中的法向量
    vs_out.normal = mat3(mv_matrix) * normal;
    vs_out.view = pos_vs.xyz;

    // 计算投影空间的顶点坐标
    gl_Position = proj_matrix * pos_vs;
}
