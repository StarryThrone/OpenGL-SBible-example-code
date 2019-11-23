#version 410 core

// 统一变量，仿射矩阵
uniform mat4 view_matrix;

// 输出变量
out VS_OUT {
    vec3    tc;
} vs_out;

void main(void) {
    // 1. 定义一个全窗口的矩形模型
    vec3[4] vertices = vec3[4](vec3(-1.0, -1.0, 1.0),
                               vec3( 1.0, -1.0, 1.0),
                               vec3(-1.0,  1.0, 1.0),
                               vec3( 1.0,  1.0, 1.0));
    // 2. 计算采样纹理坐标
    // 立方体纹理使用的采样纹理坐标是观察向量，这个向量没有必要是标准向量，
    // 只要指定了方向，OpenGL的纹理采样器就能够获取到正确的像素颜色
    vs_out.tc = mat3(view_matrix) * vertices[gl_VertexID];

    // 3. 计算顶点在投影空间的位置
    // 绘制全窗口的矩形不涉及到投影变换，因此这里直接使用设置好的顶点坐标
    gl_Position = vec4(vertices[gl_VertexID], 1.0);
}
