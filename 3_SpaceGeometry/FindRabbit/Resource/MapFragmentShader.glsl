#version 410 core

// 输入变量
// 纹理坐标
in VS_OUT {
    vec2 tc;
} fs_in;

// 统一变量
// 地砖纹理
uniform sampler2D floorTexture;

// 输出变量
out vec4 color;

void main(void) {
    color = vec4(texture(floorTexture, fs_in.tc).rgb, 1.0);
}

