#version 410 core

layout (triangles) in;
layout (points, max_vertices = 3) out;

void main(void) {
    int i;
    for (i = 0; i < gl_in.length(); i++) {
        gl_Position = gl_in[i].gl_Position;
        // 生成一个顶点
        EmitVertex();
    }
    // 将顶点组合成points定义的图元并清空画布
    EndPrimitive();
}
