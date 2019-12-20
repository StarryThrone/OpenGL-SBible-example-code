#version 410 core

layout (triangles) in;
layout (points, max_vertices = 3) out;

void main() {
    for (int i = 0; i < gl_in.length(); i++) {
        gl_Position = gl_in[i].gl_Position;
        // Generate a vertex
        EmitVertex();
    }
    // Composite vertext to geometry as designed and clear canvas
    EndPrimitive();
}
