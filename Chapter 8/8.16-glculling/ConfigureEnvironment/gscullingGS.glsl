#version 410 core                                                       

layout (triangles) in;
layout (triangle_strip, max_vertices = 3) out;

in Vertex {
    vec3 normal;
    vec4 color;
} vertex[];

out vec4 color;

uniform vec3 vLightPosition;
uniform mat4 mvpMatrix;
uniform mat4 mvMatrix;

uniform vec3 viewpoint;

void main() {
    vec3 ab = gl_in[1].gl_Position.xyz - gl_in[0].gl_Position.xyz;
    vec3 ac = gl_in[2].gl_Position.xyz - gl_in[0].gl_Position.xyz;
    // 计算模型坐标系中的图元法向量
    vec3 normal = normalize(cross(ab, ac));
    // 计算模型坐标系中的视线逆向量
    vec4 worldspace = gl_in[0].gl_Position;
    vec3 vt = normalize(viewpoint - worldspace.xyz);
    
    // 如果图元法向量和设置的视线逆向量夹角大于90度，即认为图元法向量背离观察者，即剔除该图元
    if (dot(normal, vt) > 0.0) {
        for (int n = 0; n < 3; n++) {
            gl_Position = mvpMatrix * gl_in[n].gl_Position;
            color = vertex[n].color;
            EmitVertex();
        }
        EndPrimitive();
    }
}












