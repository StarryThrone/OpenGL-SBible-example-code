#version 410 core

layout (location = 3) in int alien_index;
out VS_OUT {
    flat int alien;
    vec2 tc;
} vs_out;

// 在droplets应该使用自定义结构体使得变量名更直观，但是当使用自定义结构体时，通过droplet数组获取成员变量时只能使用droplet[0]这里数字表示法，不能使用int a = 1，droplet[a]方式，后期研究
struct droplet_t {                                                    
    float x_offset;
    float y_offset;
    float orientation;
    float unused;
};

layout (std140) uniform droplets {
    vec4 droplet[256];
};

void main() {
    const vec2[4] position = vec2[4](vec2(-0.5, -0.5),
                                     vec2( 0.5, -0.5),
                                     vec2(-0.5,  0.5),
                                     vec2( 0.5,  0.5));
//    vs_out.tc = position[gl_VertexID].xy + vec2(0.5);
    float co = cos(droplet[alien_index].z);
    float so = sin(droplet[alien_index].z);
    mat2 rot = mat2(vec2(co, so), vec2(-so, co));
    vec2 pos = 0.25 * rot * position[gl_VertexID];
    gl_Position = vec4(pos.x + droplet[alien_index].x,
                       pos.y + droplet[alien_index].y,
                       0.5, 1.0);
    // 该行代码过于靠前会导致数据错乱，推测是并发原因导致，具体还需要验证
    vs_out.tc = position[gl_VertexID].xy + vec2(0.5);
    vs_out.alien = alien_index % 64;
}
