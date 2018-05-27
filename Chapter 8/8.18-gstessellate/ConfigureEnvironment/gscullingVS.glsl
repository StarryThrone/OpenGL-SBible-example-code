#version 410 core
// Incoming per vertex... position and normal
layout (location = 0) in vec4 vVertex;

void main() {
    gl_Position = vVertex;
}

