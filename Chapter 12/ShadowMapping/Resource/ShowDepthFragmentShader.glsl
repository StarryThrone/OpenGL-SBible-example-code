#version 410

// 输入变量
in VS_OUT {
    vec2 shadow_coord;
} fs_in;

// 统一变量：深度纹理
uniform sampler2D tex_depth;

// 输出变量
layout (location = 0) out vec4 color;

void main(void) {
    // 从深度纹理中采样数据，由于深度纹理内部数据为GL_DEPTH_COMPONENT32F，此处仅取r通道有效
    float depth = texture(tex_depth, fs_in.shadow_coord).r;
    // 由于投影矩阵计算，并修正后的深度值在[0, 1]区间内并不是线型变化，因此其深度值都接近1，并且变化很剧烈，需要通过如下方式放大观察其变化
    depth = (depth - 0.95) * 15.0;
    // 使用深度值作为片段的最终颜色，预览深度贴图
    color = vec4(vec3(depth), 1.0);
}
