// 指定了OpenGL版本为 4.1 Core Profile
#version 410 core
void main() {
    // 通常顶点数据是通过外部传入，这里简单示例采用另外一种方式gl_VertexID，它检查外面调用的方法glDrawArrays(GL_TRIANGLES, 0, 3)；
    // 从第一个参数开始取顶点，直到最后一个参数定义的顶点数量。
    // The gl_VertexID input starts counting from the value given by the first parameter of glDrawArrays()
    // and counts upwards one vertex at a time for count vertices (the third parameter of glDrawArrays())
    const vec4 vertices[3] = vec4[3](vec4( 0.25, -0.25, 0.5, 1.0),
                                     vec4(-0.25, -0.25, 0.5, 1.0),
                                     vec4( 0.25, 0.25, 0.5, 1.0));
    gl_Position = vertices[gl_VertexID];
}
