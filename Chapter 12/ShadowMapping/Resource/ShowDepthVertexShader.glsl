#version 410 core                                              

// 输出变量
out VS_OUT {
    vec2 shadow_coord;
} vs_out;

void main(void) {
    // 1. 准备顶点位置
    const vec4 vertices[] = vec4[](vec4(-1.0, -1.0, 0.5, 1.0), 
                                   vec4( 1.0, -1.0, 0.5, 1.0), 
                                   vec4(-1.0,  1.0, 0.5, 1.0), 
                                   vec4( 1.0,  1.0, 0.5, 1.0));
    // 2. 准备纹理坐标
    const vec2 coordinates[] = vec2[](vec2(0.0, 0.0),
                                      vec2(1.0, 0.0),
                                      vec2(0.0, 1.0),
                                      vec2(1.0, 1.0));
    // 3. 计算顶点的纹理坐标
    vs_out.shadow_coord = coordinates[gl_VertexID];
    // 4. 计算顶点在投影空间的位置
    gl_Position = vertices[gl_VertexID];                       
}                                                              
