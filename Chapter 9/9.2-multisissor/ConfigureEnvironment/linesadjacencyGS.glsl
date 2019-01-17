#version 410 core

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

void main(void) {
    for (int i = 0; i < gl_in.length(); i++) {
//        gs_out.color = gs_in[i].color;
        // 同样的，这里颜色不能正确的从顶点着色器传递到几何着色器，后续需要继续研究
        gs_out.color = vec4(1.0, 1.0, 1.0, 1.0);
        gl_Position = mvp_matrix[gl_InvocationID] *
                      gl_in[i].gl_Position;
        gl_ViewportIndex = gl_InvocationID;
        EmitVertex();
    }
    EndPrimitive();
}
