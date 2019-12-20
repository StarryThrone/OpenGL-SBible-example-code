#version 410 core

void main() {
    const vec4 vertices[3] = vec4[3](vec4( 0.9, -0.9, 0.5, 1.0),
                                     vec4(-0.9, -0.9, 0.5, 1.0),
                                     vec4( 0.9,  0.9, 0.5, 1.0));
    gl_Position = vertices[gl_VertexID];
}
