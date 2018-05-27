#version 410 core

layout (triangles) in;
layout (triangle_strip, max_vertices = 12) out;

uniform float stretch = 0.3;

// 这里意味这演示变量不会被线性插值，https://stackoverflow.com/questions/27581271/flat-qualifier-in-glsl
flat out vec4 color;

uniform mat4 mvMatrix;
uniform mat4 mvpMatrix;

void make_face(vec3 a, vec3 b, vec3 c) {
    vec3 face_normal = normalize(cross(c - a, c - b));
    vec4 face_color = vec4(1.0, 0.2, 0.4, 1.0) * (mat3(mvMatrix) * face_normal).z;
    gl_Position = mvpMatrix * vec4(a, 1.0);
    color = face_color;
    EmitVertex();

    gl_Position = mvpMatrix * vec4(b, 1.0);
    color = face_color;
    EmitVertex();

    gl_Position = mvpMatrix * vec4(c, 1.0);
    color = face_color;
    EmitVertex();

    EndPrimitive();
}

void main() {
    int n;
    vec3 a = gl_in[0].gl_Position.xyz;
    vec3 b = gl_in[1].gl_Position.xyz;
    vec3 c = gl_in[2].gl_Position.xyz;

    // 此处计算三角形从一个顶点连向对边中点及其延长线上的向量，a+b为原点到ab边中点构成的向量*2
    vec3 d = (a + b) * stretch;
    vec3 e = (b + c) * stretch;
    vec3 f = (c + a) * stretch;

    a *= (2.0 - stretch);
    b *= (2.0 - stretch);
    c *= (2.0 - stretch);

    // 此处将单个三角形图元分解为四个小的三角形图元
    make_face(a, d, f);
    make_face(d, b, e);
    make_face(e, c, f);
    make_face(d, e, f);

    EndPrimitive();
}
