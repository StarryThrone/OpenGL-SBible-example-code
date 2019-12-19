#version 410

// 统一变量
uniform float yAspect = 0.75;

// 输出变量
out VS_OUT {
    vec3 ray_origin;
    vec3 ray_direction;
} vs_out;

void main(void) {
    // 在屏幕空间内的绘制范围为整个窗口
    vec4 vertices[4] = vec4[4](vec4(-1.0, -1.0, 1.0, 1.0),
                               vec4( 1.0, -1.0, 1.0, 1.0),
                               vec4(-1.0,  1.0, 1.0, 1.0),
                               vec4( 1.0,  1.0, 1.0, 1.0));
    vec4 pos = vertices[gl_VertexID];

    gl_Position = pos;
    // 视图空间内射线的起点为原点
    vs_out.ray_origin = vec3(0.0);
    // TODO：模型位于视野边缘时发生形变
    // 计算在视图坐标系中的投影平面四个顶点的光线追踪向量
    // 为了和窗口的尺寸成比例，这里需要对y轴进行缩放，另外光线追踪方向朝向z轴负方向，因此z轴需要反向
    vs_out.ray_direction = pos.xyz * vec3(1.0, yAspect, -1.0);
}
