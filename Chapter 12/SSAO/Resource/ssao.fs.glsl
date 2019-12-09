#version 410 core

// 统一变量
// 上一个OpenGL程序生成的颜色纹理贴图、法线-深度纹理贴图
uniform sampler2D sColor;
uniform sampler2D sNormalDepth;

// 控制SSAO效果的变量
// 环境光系数，控制环境光的多少
uniform float ssao_level = 1.0;
// 物体光系数，控制物体由光源直接照射产生的光的多少
uniform float object_level = 1.0;
// 遮挡查询半径，在确定某个片段遮挡系数时，该值和步长成正比，
uniform float ssao_radius = 5.0;
// 遮挡查询向量数，在确定某个片段遮挡系数时，需要查询的随机方向数
uniform uint point_count = 8;
// 是否开启随机步长
uniform bool randomize_points = true;

// 统一闭包变量
// 包含256哥随机单位方向(x,y,z,0)，X\Y\Z的取值为[0,1]
layout (std140) uniform SAMPLE_POINTS {
    vec4 pos[256];
} points;

// 包含256个完全随机的向量，每个分量取值为[0,1]
layout (std140) uniform SAMPLE_VEVTORS {
    vec4 random_vectors[256];
} vectors;

// 输出变量
layout (location = 0) out vec4 color;

void main(void) {
    // 根据当前片段在窗口坐标系中的位置。和法线-深度纹理的大小，计算当前片段对应的纹理采样坐标
    vec2 P = gl_FragCoord.xy / textureSize(sNormalDepth, 0);
    // 提取法向量-深度数据
    vec4 ND = textureLod(sNormalDepth, P, 0);
    vec3 N = ND.xyz;
    float my_depth = ND.w;

    // 通过片段在窗口坐标系中的坐标xy分量，以及片段深度生成的随机数
    int n = (int(gl_FragCoord.x * 7123.2315 + 125.232) *
             int(gl_FragCoord.y * 3137.1519 + 234.8)) ^
             int(my_depth);
    // 获取一个随机向量
    vec4 v = vectors.random_vectors[n & 255];

    // 生成随机种子，取值为[0.3, 0.4], 0.5
    float r = (v.r + 3.0) * 0.1;
    if (!randomize_points) {
        r = 0.5;
    }
    
    // 被遮挡样本数量
    float occ = 0.0;
    // 总样本数量
    float total = 0.0;

    // 根据指定的随机向量数量循环计算该片段的环境光遮蔽量
    for (int i = 0; i < point_count; i++) {
        // 确定随机向量方向
        vec3 dir = points.pos[i].xyz;

        // 确保随机向量的方向在法向量指向的半球
        if (dot(N, dir) < 0.0) {
            dir = -dir;
        }

        // 距离系数
        float f = 0.0;
        // 插值得到的深度
        float z = my_depth;

        // 在每个方向上采样4次，因此定义每迭代一个随机方向，总采样样本数+4
        total += 4.0;
        // 在每个方向上采样4次，计算环境光遮蔽量
        for (int j = 0; j < 4; j++) {
            // 计算当前采样的距离系数
            f += r;
            // 投影坐标系中的深度值靠近近平面为负，靠近远平面未正，和相机坐标系的z轴反向，因此这里计算深度值时需要取负
            // 沿着随机向量的方向，和一定的距离系数计算插值后在视图空间内片段的深度
            // 纹理坐标的采样步长和深度的采样步长不同步，是因为xy方向是采样纹理坐标，而z轴方向是采样视图坐标系深度坐标
            z -= dir.z * f;

            // 从法向量-深度纹理中读取对应的插值点显示在最终场景内的深度
            // 纹理采样坐标取值空间为[0,1]
            float their_depth = textureLod(sNormalDepth, (P + dir.xy * f * ssao_radius), 0).w;

            // 如果插值得到的深度，比插值点在最终场景内显示深度大，则表示插值点被其他片段遮挡
            if ((z - their_depth) > 0.0) {
                // 根据当前片段深度和插值点在最终场景内的深度差来对遮挡量进行调整，深度值差越大，认为遮挡量越小
                float d = abs(their_depth - my_depth);
                d *= d;

                // 计算片段的遮挡量，这里对遮挡量进行放大，放大系数为4
                occ += 4.0 / (1.0 + d);
            }
        }
    }

    // 计算环境光的比例
    float ao_amount = (1.0 - occ / total);

    // 从颜色纹理贴图中读取当前片段的颜色
    vec4 object_color = textureLod(sColor, P, 0);

    // 混合物体颜色，和环境光颜色得到最终的片段颜色
    color = object_level * object_color + mix(vec4(0.2), vec4(ao_amount), ssao_level);
}
