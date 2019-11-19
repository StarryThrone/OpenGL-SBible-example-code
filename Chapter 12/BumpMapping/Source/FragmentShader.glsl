#version 410 core

// 输出变量
out vec4 color;

// 统一变量，颜色和纹理贴图
uniform sampler2D tex_color;
uniform sampler2D tex_normal;

// 输入变量
in VS_OUT {
    vec2 texcoord;
    vec3 eyeDir;
    vec3 lightDir;
} fs_in;

void main(void) {
    // 求切线空间的标准光源向量
    vec3 L = normalize(fs_in.lightDir);
    // 从法线贴图中读取法向量，并标准化
    // 由于颜色数据的取值为[0, 1]，而坐标数据取值为[-1, 1]，需要简单映射
    // 法线贴图中的法向量都位于切线空间
    vec3 N = normalize(texture(tex_normal, fs_in.texcoord).rgb * 2.0 - vec3(1.0));
    // 解开下面这行的注释使用曲面法向量，关闭法线贴图技术
//    N = vec3(0.0, 0.0, 1.0);

    // 从颜色纹理中抓取漫反射系数
    vec3 diffuse_albedo = texture(tex_color, fs_in.texcoord).rgb;
    // 计算漫反射光的颜色
    vec3 diffuse = max(dot(N, L), 0.0) * diffuse_albedo;
    // 解开下面一行代码注释关闭漫射光
//    diffuse = vec3(0.0);

    // 计算入射光线基于法向量的折射光线，用于冯氏照明计算
    vec3 R = reflect(-L, N);
    // 求切线空间的标准视点向量
    vec3 V = normalize(fs_in.eyeDir);
    // 假定反射光系数为全反射，光源为白色，即反射白光
    vec3 specular_albedo = vec3(1.0);
    // 计算冯氏着色模型中的反射光
    vec3 specular = max(pow(dot(R, V), 20.0), 0.0) * specular_albedo;
    // 解开下面一行代码注释关闭折射光
//    specular = vec3(0.0);

    // 计算最终片段颜色 = 漫射光 + 折射光
    color = vec4(diffuse + specular, 1.0);
}
