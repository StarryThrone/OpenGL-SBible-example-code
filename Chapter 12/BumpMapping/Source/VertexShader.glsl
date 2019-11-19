#version 410 core

// 输入变量
layout (location = 0) in vec4 position;
layout (location = 1) in vec3 normal;
layout (location = 2) in vec3 tangent;
// 尽管模型文件中包含顶点属性bitangent，但是本示例为了演示计算过程，不使用这部分数据，而是通过法向量normal和切向量tangent计算
// layout (location = 3) in vec3 bitangent;
layout (location = 4) in vec2 texcoord;

// 输出变量
out VS_OUT {
    vec2 texcoord;
    vec3 eyeDir;
    vec3 lightDir;
} vs_out;

// 统一变量
uniform mat4 mv_matrix;
uniform mat4 proj_matrix;
uniform vec3 light_pos = vec3(0.0, 0.0, 100.0);

void main(void) {
    // 计算顶点在相机坐标系中的位置
    vec4 P = mv_matrix * position;

    // 将物体坐标系中的法向量和切向量向相机坐标系转换，并取标准向量
    vec3 V = P.xyz;
    vec3 N = normalize(mat3(mv_matrix) * normal);
    vec3 T = normalize(mat3(mv_matrix) * tangent);
    // 计算副切向量
    vec3 B = cross(N, T);

    // 计算相机坐标系中的光源向量，并通过左乘TBN矩阵，将其转换到切线坐标系中
    vec3 L = light_pos - P.xyz;
    vs_out.lightDir = normalize(vec3(dot(L, T), dot(L, B), dot(L, N)));

    // 视点向量意为相机空间内从兴趣点指向观察点点向量，直接取兴趣点在相机坐标系中的位置即可
    V = -P.xyz;
    // 通过左乘TBN矩阵，将其转换到切线坐标系中
    vs_out.eyeDir = normalize(vec3(dot(V, T), dot(V, B), dot(V, N)));

    // 直接向后传递纹理坐标，使片段着色器能够正确的抓取到法线贴图和颜色贴图中的数据
    vs_out.texcoord = texcoord;

    // 计算顶点在投影空间内的位置
    gl_Position = proj_matrix * P;
}
