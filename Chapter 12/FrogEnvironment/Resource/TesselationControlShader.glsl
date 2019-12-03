#version 410 core

// 曲面细分控制着色器特有标示符，指定每个曲面细分块的顶点数
layout (vertices = 4) out;

// 输入变量，这里必须使用数组，其大小和单个曲面细分块的顶点数相同
in VS_OUT {
    vec2 tc;
} tcs_in[];

// 统一变量
uniform mat4 mvp_matrix;

// 输出变量，这里也必须使用数组，其大小和指定输出的顶点数量相同
out TCS_OUT {
    vec2 tc;
} tcs_out[];

void main() {
    if (gl_InvocationID == 0) {
        // 只有在第一次调用时才需要设置曲面细分的系数
        // 计算每个顶点在投影坐标系中的坐标
        vec4 p0 = mvp_matrix * gl_in[0].gl_Position;
        vec4 p1 = mvp_matrix * gl_in[1].gl_Position;
        vec4 p2 = mvp_matrix * gl_in[2].gl_Position;
        vec4 p3 = mvp_matrix * gl_in[3].gl_Position;
        // 将顶点坐标转换到标准设备坐标NDC，而标准设备坐标系的z轴范围为1到-1，其中z轴正方向指向屏幕内部
        p0 /= p0.w;
        p1 /= p1.w;
        p2 /= p2.w;
        p3 /= p3.w;
        // 这里剔除了位于观察者背后的曲面块，优化着色器性能
        // 但这样会使得切割近投影面的块不可见
        if (p0.z < -1.0 || p1.z < -1.0 || p2.z < -1.0 || p3.z <= -1.0) {
            gl_TessLevelOuter[0] = 0.0;
            gl_TessLevelOuter[1] = 0.0;
            gl_TessLevelOuter[2] = 0.0;
            gl_TessLevelOuter[3] = 0.0;
        } else {
            // 此处投影到NDC不再考虑屏幕方向上的z轴，直接投影到xy平面进行曲面细分
            // 即在屏幕区域上显示的区域越大，曲面细分的力度越大
            float l0 = length(p2.xy - p0.xy) * 16.0 + 1.0;
            float l1 = length(p3.xy - p2.xy) * 16.0 + 1.0;
            float l2 = length(p3.xy - p1.xy) * 16.0 + 1.0;
            float l3 = length(p1.xy - p0.xy) * 16.0 + 1.0;
            gl_TessLevelOuter[0] = l0;
            gl_TessLevelOuter[1] = l1;
            gl_TessLevelOuter[2] = l2;
            gl_TessLevelOuter[3] = l3;
            gl_TessLevelInner[0] = min(l1, l3);
            gl_TessLevelInner[1] = min(l0, l2);
        }
    }
    // 计算控制点在模型空间中的位置（因为模型矩阵设置为了单位矩阵，相当于这里计算的是世界坐标系中的坐标）
    gl_out[gl_InvocationID].gl_Position = gl_in[gl_InvocationID].gl_Position;
    // 计算每个控制点的纹理采样索引
    tcs_out[gl_InvocationID].tc = tcs_in[gl_InvocationID].tc;
}
