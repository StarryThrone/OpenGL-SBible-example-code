#version 410 core

layout (triangles) in;
layout (triangle_strip, max_vertices = 3) out;

uniform float explode_factor = 0.5;
uniform mat4 proj_matrix;

in vec3 vertexColor[];

out vec3 primitiveColor;

void main() {
    vec3 ab = gl_in[1].gl_Position.xyz - gl_in[0].gl_Position.xyz;
    vec3 ac = gl_in[2].gl_Position.xyz - gl_in[0].gl_Position.xyz;
    vec3 face_normal = normalize(cross(ab, ac));
    for (int i = 0; i < gl_in.length(); i++) {
        vec4 temp = gl_in[i].gl_Position + gl_in[i].gl_Position + vec4(face_normal * explode_factor, 0.0);
        gl_Position = proj_matrix * temp;
        primitiveColor = vertexColor[i];
        EmitVertex();
    }
    EndPrimitive();
}
