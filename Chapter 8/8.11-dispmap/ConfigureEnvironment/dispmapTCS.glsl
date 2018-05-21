#version 410 core
layout (vertices = 4) out;

in VS_OUT {
    vec2 tc;
} tcs_in[];

out TCS_OUT {
    vec2 tc;
} tcs_out[];

uniform mat4 mvp_matrix;

void main() {
    if (gl_InvocationID == 0) {
        vec4 p0 = mvp_matrix * gl_in[0].gl_Position;
        vec4 p1 = mvp_matrix * gl_in[1].gl_Position;
        vec4 p2 = mvp_matrix * gl_in[2].gl_Position;
        vec4 p3 = mvp_matrix * gl_in[3].gl_Position;
        p0 /= p0.w;
        p1 /= p1.w;
        p2 /= p2.w;
        p3 /= p3.w;
        // 此处模型坐标已经被转化为标准设备坐标NDC，而标准设备坐标系的z轴范围为1到-1，其中z轴正方向指向屏幕内部
        // 这里剔除了位于观察者后面的图形块，优化着色器性能。
        // 这种优化仍有瑕疵，当观察这位于十分陡峭的悬崖底部向上看时，单个patch会被拉伸，导致其部分位于观察者后，部分位于观察者视野内
        if (p0.z <= 0.0 || p1.z <= 0.0 || p2.z <= 0.0 || p3.z <= 0.0) {
            gl_TessLevelOuter[0] = 0.0;
            gl_TessLevelOuter[1] = 0.0;
            gl_TessLevelOuter[2] = 0.0;
            gl_TessLevelOuter[3] = 0.0;
        } else {
            // 此处投影到NDC不再考虑屏幕方向上的z轴，直接投影到xy平面进行曲面细分
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
    gl_out[gl_InvocationID].gl_Position = gl_in[gl_InvocationID].gl_Position;
    tcs_out[gl_InvocationID].tc = tcs_in[gl_InvocationID].tc;
}













