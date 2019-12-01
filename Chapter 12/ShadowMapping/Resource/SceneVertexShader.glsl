#version 410 core

// 输入变量
layout (location = 0) in vec4 position;
layout (location = 1) in vec3 normal;

// 统一变量
uniform mat4 mv_matrix;
uniform mat4 proj_matrix;
uniform mat4 shadow_matrix;
uniform vec3 light_pos = vec3(100.0, 100.0, 100.0);

// 输出变量
out VS_OUT {
    vec4 shadow_coord;
    vec3 N;
    vec3 L;
    vec3 V;
} vs_out;


void main(void) {
    // 1. 计算顶点在视图空间内的位置
    vec4 P = mv_matrix * position;

    // 2. 将法向量从模型空间转换到视图空间
    vs_out.N = mat3(mv_matrix) * normal;
    // 3. 计算光源向量
    vs_out.L = light_pos - P.xyz;
    // 4. 计算观测点向量
    vs_out.V = -P.xyz;
    // 5. 计算顶点在以光源为观察点的投影空间位置，用于确定顶点是否位于阴影内
    vs_out.shadow_coord = shadow_matrix * position;
    
    // 6. 计算顶点在投影空间的位置
    gl_Position = proj_matrix * P;
}
