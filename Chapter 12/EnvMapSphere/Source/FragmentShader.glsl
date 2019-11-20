#version 410 core

// 统一变量，环境贴图采样器
uniform sampler2D tex_envmap;

// 输入变量
in VS_OUT {
    vec3 normal;
    vec3 view;
} fs_in;

// 输出变量
out vec4 color;

void main(void) {
    // 计算标准观测向量
    vec3 u = normalize(fs_in.view);

    // 计算观测向量于法向量的反射向量
    vec3 r = reflect(u, normalize(fs_in.normal));
    
    // 假设球面贴图上存在点A，由于球面贴图的制作原理，认为球面上的
    // 每个点都是无穷远处观察到的反射景色，因此从观测点到球面任意一点
    // 的单位观测向量都可以认为是（0，0，-1），即对于每个兴趣点视点向
    // 量都为(0, 0, 1)，片段的单位反射向量和该向量之和标准化后即可得
    // 到球面贴图中的法向量，即可以用于确定片段的颜色
    vec3 sphericalR = normalize(r + vec3(0, 0, 1));

    // 标准向量的三个分量的取值范围为[-1,1]，需要将其值映射到[0,1]的
    // 区间才能正确的计算出纹理坐标对于单位球面上的点A，其在球形纹理贴
    // 图中的投影坐标可以由其x和y值表示
    color = texture(tex_envmap, sphericalR.xy * 0.5 + vec2(0.5));
}

