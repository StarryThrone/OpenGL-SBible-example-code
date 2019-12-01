#version 410 core

// 输出变量
layout (location = 0) out vec4 color;

void main(void) {
    // 计算片段颜色
    color = vec4(gl_FragCoord.z);
}
