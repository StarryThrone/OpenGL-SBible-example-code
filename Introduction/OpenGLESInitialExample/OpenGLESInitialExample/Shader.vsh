#version 300 es

layout(location = 0) in vec4 vPosition;

void main() {
    const vec4 vertices[3] = vec4[3](vec4( 0.25, -0.25, 0.5, 1.0),
                                     vec4(-0.25, -0.25, 0.5, 1.0),
                                     vec4( 0.25, 0.25, 0.5, 1.0));
    gl_Position = vertices[gl_VertexID];
}
