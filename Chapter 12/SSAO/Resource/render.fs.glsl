#version 410 core

// 输入变量
in VS_OUT {
    vec3 N;
    vec3 L;
    vec3 V;
} fs_in;

// 统一变量
// 材质属性
uniform vec3 diffuse_albedo = vec3(0.8, 0.8, 0.9);
uniform vec3 specular_albedo = vec3(0.01);
uniform float specular_power = 128.0;
// 着色程度
uniform float shading_level = 1.0;

// 输出变量
layout (location = 0) out vec4 color;
layout (location = 1) out vec4 normal_depth;

void main(void) {
    // 计算单位法向量、光源向量，观察点向量
    vec3 N = normalize(fs_in.N);
    vec3 L = normalize(fs_in.L);
    vec3 V = normalize(fs_in.V);

    // 计算入射光向量绕法向量的折射向量
    vec3 R = reflect(-L, N);

    // 计算漫反射色，和镜面高光
    vec3 diffuse = max(dot(N, L), 0.0) * diffuse_albedo;
    diffuse *= diffuse;
    vec3 specular = pow(max(dot(R, V), 0.0), specular_power) * specular_albedo;

    // 将计算得到的颜色写入到颜色附件1
    color = mix(vec4(0.0), vec4(diffuse + specular, 1.0), shading_level);
    // 将片段的法向量，和片段在视图空间内深度的负值写入到颜色附件2
    // 这里存储的深度值是片段在视图空间内坐标z轴分量的负值，视图空间z轴指向屏幕外，而深度比较时认为朝向屏幕外深度值减小，因此这里需要使用负值
    normal_depth = vec4(N, fs_in.V.z);
}
