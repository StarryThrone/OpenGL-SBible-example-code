#version 410 core

layout (triangles) in;
layout (triangle_strip, max_vertices = 3) out;

in VS_OUT {
    vec3 normal;
} gs_in[];

out GS_OUT {
    vec3 normal;
} gs_out;

uniform float explode_factor = 0.1;

void main() {
    vec3 ab = gl_in[1].gl_Position.xyz - gl_in[0].gl_Position.xyz;
    vec3 ac = gl_in[2].gl_Position.xyz - gl_in[0].gl_Position.xyz;
    // 这里三角形图元的法向量被乘以-1，是因为输入图元可能为顺时针
    vec3 face_normal = -normalize(cross(ab, ac));
    for (int i = 0; i < gl_in.length(); i++) {
        // 在裁剪坐标系下，将兔子模型的图元沿着法向量进行平移，模拟爆炸效果
        gl_Position = gl_in[i].gl_Position + vec4(face_normal * explode_factor, 0.0);
        gs_out.normal = gs_in[i].normal;
        EmitVertex();
    }
    EndPrimitive();
}












