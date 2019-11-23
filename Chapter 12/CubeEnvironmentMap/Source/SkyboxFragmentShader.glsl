#version 410 core

//MARK: TODO 立方体贴图纹理无法正常工作
uniform samplerCube tex_cubemap;
//MARK: TODO 临时纹理
uniform sampler2D tempTexture;

in VS_OUT {
    vec3    tc;
} fs_in;

layout (location = 0) out vec4 color;

void main(void) {
//    color = texture(tex_cubemap, fs_in.tc);
    
    color = texture(tempTexture, fs_in.tc.xy);
}
