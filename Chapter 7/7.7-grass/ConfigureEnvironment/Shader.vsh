#version 410 core
// Incoming per vertex position，尽管传入的向量只有x、y的值，但默认z值为0，w值为1
in vec4 vVertex;

// Output varyings
out vec4 color;

uniform mat4 mvpMatrix;

// layout (binding = 0)
uniform sampler1D grasspalette_texture;
// layout (binding = 1)
uniform sampler2D length_texture;
// layout (binding = 2)
uniform sampler2D orientation_texture;
// layout (binding = 3)
uniform sampler2D grasscolor_texture;
// layout (binding = 4)
uniform sampler2D bend_texture;

int random(int seed, int iterations) {
    int value = seed;
    int n;
 
    for (n = 0; n < iterations; n++) {
        value = ((value >> 7) ^ (value << 9)) * 15485863;
    }
 
    return value;
}

vec4 random_vector(int seed) {
    int r = random(gl_InstanceID, 4);
    int g = random(r, 2);
    int b = random(g, 2);
    int a = random(b, 2);

    return vec4(float(r & 0x3FF) / 1024.0,
                float(g & 0x3FF) / 1024.0,
                float(b & 0x3FF) / 1024.0,
                float(a & 0x3FF) / 1024.0);
}

mat4 construct_rotation_matrix(float angle) {
    float st = sin(angle);
    float ct = cos(angle);
 
    return mat4(vec4(ct, 0.0, st, 0.0),
                vec4(0.0, 1.0, 0.0, 0.0),
                vec4(-st, 0.0, ct, 0.0),
                vec4(0.0, 0.0, 0.0, 1.0));
}

void main() {
    // 0x3FF为10个二进制位最大的值，gl_InstanceID最大值为20个2进制位，因此用前10位表示x坐标，后10位表示y坐标，并且平移5个2进制位，此时所有的实例以点（0，0，0）为圆形，每条边长1024的四边形分布
    // 此时offset取值x、y都为【-512，512】
    vec4 offset = vec4(float(gl_InstanceID >> 10) - 512.0,
                       0.0f,
                       float(gl_InstanceID & 0x3FF) - 512.0,
                       0.0f);
    
    // 生成一个随机数，该值可能很大，但是计算偏移时将其映射到0~1之间，这样每个草叶的位置都会有一定的偏移
    int number1 = random(gl_InstanceID, 3);
    int number2 = random(number1, 2);
    offset += vec4(float(number1 & 0xFF) / 256.0,
                   0.0f,
                   float(number2 & 0xFF) / 256.0,
                   0.0f);
    
    // 将位置映射至texcoord范围为【0，1】，纹理坐标即UV坐标，取值为这个范围
    vec2 texcoord = offset.xz / 1024.0 + vec2(0.5);
    // 计算绕z轴旋转角度，计算出旋转矩阵
    float angle = texture(orientation_texture, texcoord).r * 2.0 * 3.141592;
    mat4 rot = construct_rotation_matrix(angle);
    // 读取弯曲因子，计算弯曲量，这里并未使用旋转的方法，直接改变其z值达到倾斜效果，营造麦田怪圈效果
    float bend_factor = texture(bend_texture, texcoord).r * 2.0;
    float bend_amount = cos(vVertex.y);
    
    vec4 position = (rot * (vVertex + vec4(0.0, 0.0, bend_amount * bend_factor, 0.0))) + offset;
    // 拉伸草叶，通过放大y轴实现
    position *= vec4(1.0, texture(length_texture, texcoord).r * 0.9 + 0.3, 1.0, 1.0);
    // 确定顶点位置
    gl_Position = mvpMatrix * position; // (rot * position);
    color = vec4(random_vector(gl_InstanceID).xyz * vec3(0.1, 0.5, 0.1) + vec3(0.1, 0.4, 0.1), 1.0);
    
    // 此处没有颜色纹理，因此使用随机色
    // color = texture(orientation_texture, texcoord);
    // color = texture(grasspalette_texture, texture(grasscolor_texture, texcoord).r) + vec4(random_vector(gl_InstanceID).xyz * vec3(0.1, 0.5, 0.1), 1.0);
    
//    float tempLength = texture(length_texture, vec2(0.5, 0.5)).r;
//    float tempOrien = texture(orientation_texture, vec2(0.5, 0.5)).r;
//    float tempColor = texture(grasscolor_texture, vec2(0.5, 0.5)).r;
//    float tempBend = texture(bend_texture, vec2(0.5, 0.5)).r;
//
//    float colorTemp = tempBend;
//    color = vec4(colorTemp, colorTemp, colorTemp, 1.0);
}
