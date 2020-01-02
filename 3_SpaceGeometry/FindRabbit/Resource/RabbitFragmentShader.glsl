#version 410 core

// 输入变量
in VS_OUT {
    // 顶点在相机空间中的法向量
    vec3 normal;
} fs_in;

// 输出变量
out vec4 color;

void main() {
    // 计算片段的单位法向量
    vec3 stdNormal = normalize(fs_in.normal);
    float grayScale = stdNormal.z;
    // 根据法向量的z轴分量值，即在观察方向上z轴的投影值设置片段的颜色
    color = vec4(vec3(grayScale), 1.0);
}
