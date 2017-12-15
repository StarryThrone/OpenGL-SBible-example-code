//#version 410 core
//
//void main() {
//    const vec4 vertices[] = vec4[](vec4( 0.25, -0.25, 0.5, 1.0),
//                                   vec4(-0.25, -0.25, 0.5, 1.0),
//                                   vec4( 0.25,  0.25, 0.5, 1.0));
//    gl_Position = vertices[gl_VertexID];
//}

#version 410 core

out vec4 vs_color;
void main() {
    const vec4 vertices[] = vec4[](vec4( 0.25, -0.25, 0.5, 1.0),
                                   vec4(-0.25, -0.25, 0.5, 1.0),
                                   vec4( 0.25,  0.25, 0.5, 1.0));
    const vec4 colors[] = vec4[](vec4(1.0, 0.0, 0.0, 1.0),
                                 vec4(0.0, 1.0, 0.0, 1.0),
                                 vec4(0.0, 0.0, 1.0, 1.0));
    gl_Position = vertices[gl_VertexID];
    vs_color = colors[gl_VertexID];
}
