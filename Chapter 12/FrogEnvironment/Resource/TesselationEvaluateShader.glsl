#version 410 core

// 曲面细分计算着色器特有的声明符，输入图元为四边形，曲面细分的模式为渐变基数模式
// 图元组装顺序为默认值逆时针ccw
layout (quads, fractional_odd_spacing) in;

// 输入变量
in TCS_OUT {
    vec2 tc;
} tes_in[];

// 统一变量
// 地形高度纹理采样器
uniform sampler2D tex_displacement;
// 地形高度放大系数
uniform float dmap_depth;
uniform mat4 mv_matrix;
uniform mat4 proj_matrix;

// 输出变量
out TES_OUT {
    vec2 tc;
    vec3 world_coord;
    vec3 eye_coord;
} tes_out;

void main() {
    // 计算曲面细分后的三角形图元顶点的纹理坐标
    vec2 tc1 = mix(tes_in[0].tc, tes_in[1].tc, gl_TessCoord.x);
    vec2 tc2 = mix(tes_in[2].tc, tes_in[3].tc, gl_TessCoord.x);
    vec2 tc = mix(tc2, tc1, gl_TessCoord.y);
    
    // 计算曲面细分后的三角形图元顶点的坐标
    vec4 p1 = mix(gl_in[0].gl_Position, gl_in[1].gl_Position, gl_TessCoord.x);
    vec4 p2 = mix(gl_in[2].gl_Position, gl_in[3].gl_Position, gl_TessCoord.x);
    vec4 p = mix(p2, p1, gl_TessCoord.y);
    // 根据地形贴图和高度放大系数，设置顶点的海拔高度
    p.y += texture(tex_displacement, tc).r * dmap_depth;
    
    // 计算顶点在视图空间中的坐标
    vec4 P_eye = mv_matrix * p;
    
    // 计算顶点纹理坐标
    tes_out.tc = tc;
    // 计算顶点在世界坐标系中的位置
    tes_out.world_coord = p.xyz;
    // 计算顶点在视图坐标系中的位置
    tes_out.eye_coord = P_eye.xyz;
    
    // 计算顶点在投影坐标系中的位置
    gl_Position = proj_matrix * P_eye;
}
