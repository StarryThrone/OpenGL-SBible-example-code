#version 410 core

// 输入变量
in TES_OUT {
    vec2 tc;
    vec3 world_coord;
    vec3 eye_coord;
} fs_in;

// 统一变量
// 颜色纹理采样器
uniform sampler2D tex_color;
uniform bool enable_fog = true;
uniform vec4 fog_color = vec4(0.7, 0.8, 0.9, 0.0);

// 输出变量
out vec4 color;

// 雾化效果计算函数，传入参数为片段未开启雾化效果时的颜色
vec4 fog(vec4 c) {
    // 计算消光因子，当距离相同时，计算出的消光系数越小，能够穿透误区的光线越少
    float de = 0.025 * smoothstep(0.0, 6.0, 10.0 - fs_in.world_coord.y);
    // 计算内散射因子，当距离相同时，计算出的内散射系数越小，通过内散射产生的光越多
    float di = 0.045 * smoothstep(0.0, 40.0, 20.0 - fs_in.world_coord.y);
    
    // 计算光线到达观测点需要传播的距离，消光系数，和内散色系数
    float z = length(fs_in.eye_coord);
    float extinction = exp(-z * de);
    float inscattering = exp(-z * di);
    
    // 计算经过雾化效果后片段的颜色
    return c * extinction + fog_color * (1.0 - inscattering);
}

void main() {
    // 从颜色纹理贴图中查询片段颜色
    vec4 landscape = texture(tex_color, fs_in.tc);
    
    // 根据设置进行必要的雾化处理
    if (enable_fog) {
        color = fog(landscape);
    } else {
        color = landscape;
    }
}
