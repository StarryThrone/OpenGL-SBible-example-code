#version 410 core

// 统一变量
uniform mat4 vpMatrix;

// 输出变量
// 纹理坐标
out VS_OUT {
    vec2 tc;
} vs_out;

void main() {
    // 定义单个地砖的顶点坐标
    const vec4 vertices[] = vec4[](vec4(-0.5, 0.0, -0.5, 1.0),
                                   vec4( 0.5, 0.0, -0.5, 1.0),
                                   vec4(-0.5, 0.0,  0.5, 1.0),
                                   vec4( 0.5, 0.0,  0.5, 1.0));
    // 绘制128*128个地砖，根据当前着色器调用批次序号计算每个地砖相对于世界坐标系原点在xz轴上的索引
    int x = gl_InstanceID & 127;
    int z = gl_InstanceID >> 7;
    // 根据索引偏移xz坐标分量，计算各个顶点在世界坐标系中的位置，铺设地板
    vec4 offsetPosition = vertices[gl_VertexID] + vec4(float(x - 64), 0.0, float(z - 64), 0.0);
    // 计算顶点在投影坐标系中的位置
    gl_Position = vpMatrix * offsetPosition;
    
    // 每个地砖映射一个纹理，计算每个顶点的纹理采样坐标
    vs_out.tc = vertices[gl_VertexID].xz + vec2(0.5);
}

