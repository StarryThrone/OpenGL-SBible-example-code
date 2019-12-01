#version 410 core

// 输入变量
layout (location = 0) in vec4 position;

// 统一变量
uniform mat4 mvp;

void main(void) {
    // 计算顶点在投影空间的位置
    gl_Position = mvp * position;
}
