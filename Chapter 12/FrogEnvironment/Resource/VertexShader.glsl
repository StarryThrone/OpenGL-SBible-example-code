#version 410 core

// 输出变量：纹理坐标
out VS_OUT {
    vec2 tc;
} vs_out;

void main() {
    // 定义单个块，即四边形的4个顶点位置
    const vec4 vertices[] = vec4[](vec4(-0.5, 0.0, -0.5, 1.0),
                                   vec4( 0.5, 0.0, -0.5, 1.0),
                                   vec4(-0.5, 0.0,  0.5, 1.0),
                                   vec4( 0.5, 0.0,  0.5, 1.0));
    // 地面由64*64共4096个四边形块组成，每个块都会被曲面细分为多个更小的三角形图元
    // 计算每个顶点的偏移量，使得4096个块按8*8分布于世界中心
    int x = gl_InstanceID & 63;
    int y = gl_InstanceID >> 6;
    vec2 offs = vec2(x, y);
    
    // 纹理坐标取值范围为[0,1]，需要使得64*64个块刚好匹配单个纹理
    vs_out.tc = (vertices[gl_VertexID].xz + offs + vec2(0.5)) / 64.0;
    // 计算每个顶点在模型空间中的位置（因为模型矩阵设置为了单位矩阵，相当于这里计算的是世界坐标系中的坐标）
    gl_Position = vertices[gl_VertexID] + vec4(float(x - 32), 0.0, float(y - 32), 0.0);
}
