#version 410 core
//设置数据精度
precision highp float;

in Fragment {
    vec4 color;
} fragment;

out vec4 color;

void main() {
    color = fragment.color;
}
