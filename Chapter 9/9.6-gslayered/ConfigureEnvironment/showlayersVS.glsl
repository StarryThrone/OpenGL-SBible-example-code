#version 410 core

out VS_OUT {
    vec3 tc;
} vs_out;

void main() {
    int vid = gl_VertexID;
    int iid = gl_InstanceID;
    const vec4 vertices[] = vec4[](vec4(-0.5, -0.5, 0.0, 1.0),
                                   vec4( 0.5, -0.5, 0.0, 1.0),
                                   vec4( 0.5,  0.5, 0.0, 1.0),
                                   vec4(-0.5,  0.5, 0.0, 1.0));
    
    int colum = iid % 4;
    int row = iid >> 2;
    vec4 offs = vec4(-0.75 + colum * 0.5, -0.75 + row * 0.5, 0.0, 0.0);
    gl_Position = vertices[vid] * vec4(0.25, 0.25, 1.0, 1.0) + offs;
    vs_out.tc = vec3(vertices[vid].xy + vec2(0.5), float(iid));
}
