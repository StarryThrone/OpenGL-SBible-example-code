#version 410 core

// 输入变量
in VS_OUT {
    vec3 ray_origin;
    vec3 ray_direction;
} fs_in;

// 输出变量
// 当前轮光线追踪计算出的片段颜色
layout (location = 0) out vec3 color;
// 下一轮光线追踪时当前片段的射线起点
layout (location = 1) out vec3 rayOrigin;
// 下一轮光线追踪时当前片段的反射方向
layout (location = 2) out vec3 reflectedDirection;
// 下一轮光线追踪时当前片段的折射方向
layout (location = 3) out vec3 refractedDirection;
// 下一轮光线追踪时当前片段的颜色反射率
layout (location = 4) out vec3 reflectedColorAlbedo;
// 下一轮光线追踪时当前片段的颜色折射率
layout (location = 5) out vec3 refractedColorAlbedo;

void main(void) {
    color = vec3(0.0);
    rayOrigin = fs_in.ray_origin;
    reflectedDirection = fs_in.ray_direction;
    refractedDirection = vec3(0.0);
    reflectedColorAlbedo = vec3(1.0);
    refractedColorAlbedo = vec3(0.0);
}
