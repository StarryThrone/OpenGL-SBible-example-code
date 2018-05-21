#version 410 core

// Incoming per vertex... position and normal
layout (location = 0) in vec4 vVertex;
layout (location = 1) in vec3 vNormal;
in vec3 vNormal1;

out Vertex {
    vec3 normal;
    vec4 color;
} vertex;
// 本实例中视图坐标系和世界坐标系重合，此处可以理解为光源在世界坐标系中的位置
uniform vec3 vLightPosition = vec3(-10.0, 40.0, 200.0);
uniform mat4 mvMatrix;

void main() {
    // Get surface normal in eye coordinates
    vec3 vEyeNormal = mat3(mvMatrix) * normalize(vNormal);
    // Get vertex position in eye coordinates
    vec4 vPosition4 = mvMatrix * vVertex;
    vec3 vPosition3 = vPosition4.xyz / vPosition4.w;
    // Get vector to light source，在视图坐标系中光线的入射向量逆向量
    vec3 vLightDir = normalize(vLightPosition - vPosition3);
    // Dot product gives us diffuse intensity
    vertex.color = vec4(0.7, 0.6, 1.0, 1.0) * abs(dot(vEyeNormal, vLightDir)) * 0.5;
    vertex.normal = vNormal;
    
    gl_Position = vVertex;
}
