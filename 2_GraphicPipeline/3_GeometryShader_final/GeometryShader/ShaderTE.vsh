#version 410 core

layout (triangles, equal_spacing, cw) in;

void main() {
    vec4 firstVertex = gl_in[0].gl_Position;
    vec4 secondVertex = gl_in[1].gl_Position;
    vec4 thirdVertex = gl_in[2].gl_Position;
    gl_Position = (gl_TessCoord.x * firstVertex + gl_TessCoord.y * secondVertex + gl_TessCoord.z * thirdVertex);
}
