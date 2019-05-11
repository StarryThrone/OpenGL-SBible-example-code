#version 410 core

uniform mat4 mv_matrix;
uniform mat4 proj_matrix;
uniform vec3 light_pos = vec3(100.0, 100.0, 100.0);

layout (location = 0) in vec4 position;
layout (location = 1) in vec3 normal;

out VS_OUT {
    vec3 N;
    vec3 L;
    vec3 V;
} vs_out;

void main() {
    // Calculate view-space coordinate
    vec4 P = mv_matrix * position;
    
    // Calculate normal in view-space
    vs_out.N = mat3(mv_matrix) * normal;
    
    // Calculate light vector
    vs_out.L = light_pos - P.xyz;
    
    // Calculate view vector
    vs_out.V = - P.xyz;
    
    // Calculate the clip-space position of each vertex
    gl_Position = proj_matrix * P;
}
