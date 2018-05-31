#version 410 core

// 在几何着色器内部启用多次调用颜色值不能正确传递进入片段着色器，后续研究
layout (triangles, invocations = 4) in;
layout (triangle_strip, max_vertices = 3) out;

layout (std140) uniform transform_block {
    mat4 mvp_matrix[4];
};

in VS_OUT {
    vec4 color;
} gs_in[];

out GS_OUT {
    vec4 color;
} gs_out;

void main() {
    for (int i = 0; i < gl_in.length(); i++) {
        gl_Position = mvp_matrix[gl_InvocationID] * gl_in[i].gl_Position;
        gs_out.color = gs_in[i].color;
        // 在几何着色器内部启用多次调用颜色值不能正确传递进入片段着色器，后续研究
        gs_out.color = vec4(1.0);
        gl_ViewportIndex = gl_InvocationID;
        EmitVertex();
    }
    EndPrimitive();
}
