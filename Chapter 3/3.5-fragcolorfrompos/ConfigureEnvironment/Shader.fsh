//#version 410 core
//
//out vec4 color;
//
//void main() {
//    color = vec4(sin(gl_FragCoord.x * 0.25) * 0.5 + 0.5,
//                 cos(gl_FragCoord.y * 0.25) * 0.5 + 0.5,
//                 sin(gl_FragCoord.x * 0.15) * cos(gl_FragCoord.y * 0.1),
//                 1.0);
//}

#version 410 core

in vec4 vs_color;
out vec4 color;

void main() {
    color = vs_color;
}
