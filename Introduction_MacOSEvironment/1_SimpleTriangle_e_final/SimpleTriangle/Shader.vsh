#version 300 es

// 顶点属性，表示顶点的偏移值
layout (location = 0) in vec4 offset;
// 顶点属性，表示顶点的颜色
layout (location = 1) in vec4 color;

// Block类型数据
out VS_OUT {
    vec4 color;
} vs_out;

void main() {
    const vec4 vertices[3] = vec4[3](vec4(-0.5, 0.5, 0.5, 1.0),
                                     vec4(-0.5, -0.5, 0.5, 1.0),
                                     vec4(0.5, -0.5, 0.5, 1.0));
    gl_Position = vertices[gl_VertexID] + offset;
    vs_out.color = color;
}


