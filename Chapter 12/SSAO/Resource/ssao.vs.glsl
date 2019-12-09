#version 410 core

void main(void) {
    // 声明四边形的四个顶点在投影坐标系中的位置
    const vec4 vertices[] = vec4[]( vec4(-1.0, -1.0, 0.5, 1.0),
                                    vec4( 1.0, -1.0, 0.5, 1.0),
                                    vec4(-1.0,  1.0, 0.5, 1.0),
                                    vec4( 1.0,  1.0, 0.5, 1.0));
    // 确定当前顶点的坐标
    gl_Position = vertices[gl_VertexID];
}
