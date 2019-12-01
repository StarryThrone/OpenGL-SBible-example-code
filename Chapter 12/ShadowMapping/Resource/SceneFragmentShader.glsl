#version 410 core

// 输入变量
in VS_OUT {
    vec4 shadow_coord;
    vec3 N;
    vec3 L;
    vec3 V;
} fs_in;

// 统一变量
uniform vec3 diffuse_albedo = vec3(0.9, 0.8, 1.0);
uniform vec3 specular_albedo = vec3(0.7);
uniform float specular_power = 300.0;
uniform bool full_shading = true;
// 阴影贴图采样器
uniform sampler2DShadow shadow_tex;
// 如果不使用OpenGL提供的阴影判断函数，需要解开该行注释，并从中手动查询纹理数据
//uniform sampler2D shadow_tex;

// 输出变量
layout (location = 0) out vec4 color;

void main(void) {
    // 1. 对输入变量进行标准化操作
    vec3 N = normalize(fs_in.N);
    vec3 L = normalize(fs_in.L);
    vec3 V = normalize(fs_in.V);

    // 2. 计算光照向量的反射向量
    vec3 R = reflect(-L, N);

    // 3. 计算每个片段的漫反射色和镜面高光色
    vec3 diffuse = max(dot(N, L), 0.0) * diffuse_albedo;
    vec3 specular = pow(max(dot(R, V), 0.0), specular_power) * specular_albedo;
    vec4 lightRenderedColor = vec4(diffuse + specular, 1.0);

    // 4. 使用函数textureProj处理坐标fs_in.shadow_coord，将其xyz除以w，并使用处理后的xy分量在shadow_tex中查询纹理数据和z比较，如果更大则返回1，否则返回0
    // 计算该片段的最终颜色
    color = textureProj(shadow_tex, fs_in.shadow_coord) * mix(vec4(1.0), lightRenderedColor, bvec4(full_shading));

    // 需要手动判断深度时可以解开下面代码的注释
//    vec4 standardCoordinate = fs_in.shadow_coord / fs_in.shadow_coord.w;
//    vec3 adjustedCoordinate = standardCoordinate.xyz * 0.5 + vec3(0.5);
//    float refrenceDepth = texture(shadow_tex, adjustedCoordinate.xy).r;
//    float currentDepth = adjustedCoordinate.z;
//    if (currentDepth < refrenceDepth) {
//        color = lightRenderedColor;
//    } else {
//        color = vec4(0.0);
//    }
}
