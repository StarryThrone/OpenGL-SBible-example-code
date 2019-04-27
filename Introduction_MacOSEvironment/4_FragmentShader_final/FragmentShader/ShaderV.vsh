#version 410 core

out vec4 vs_color;

void main() {
    const vec4 vertices[3] = vec4[3](vec4(-0.8,  0.8, 0.5, 1),
                                     vec4(-0.8, -0.8, 0.5, 1),
                                     vec4( 0.8, -0.8, 0.5, 1));
    const vec4 color[3] = vec4[3](vec4(1, 0, 0, 1),
                                  vec4(0, 1, 0, 1),
                                  vec4(0, 0, 1, 1));
    gl_Position = vertices[gl_VertexID];
    vs_color = color[gl_VertexID];
}
