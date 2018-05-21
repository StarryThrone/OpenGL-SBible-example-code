#version 410 core
// This input vector contains the vertex position in xyz, and the // mass of the vertex in w
layout (location = 0) in vec4 position_mass;
// This is the current velocity of the vertex
layout (location = 1) in vec3 velocity;
// This is our connection vector
layout (location = 2) in ivec4 connection;

// This is TBO that will be bound to the same buffer as the position_mass input attribute, which can access any vertex instead of current one as position_mass input attribute do.
uniform samplerBuffer tex_position;

// The outputs of the vertex shader are the same as the inputs
out vec4 tf_position_mass;
out vec3 tf_velocity;

// A uniform to hold the time-step. The application can update this
uniform float t = 0.07;

// The global spring constant
uniform float k = 7.1;

// Gravity
const vec3 gravity = vec3(0.0, -0.08, 0.0);

// Global damping constant
uniform float c = 2.8;

// Spring resting length
uniform float rest_length = 0.88;

void main() {
    //需要注意的是合力的计算方式应该是所有向量力的和，弹簧力由于原书中使用的是作用点到施力点的标准向量和形变距离的负数，因此需要添加负号，而阻尼力又和速度的方向相反，因此也需要取负。
    vec3 p = position_mass.xyz;     // p can be our position
    float m = position_mass.w;      // m is the mass of our vertex
    vec3 u = velocity;              // u is the initial velocity
    vec3 F = gravity * m - c * u;   // F is the force on the mass excepting spring force
    bool fixed_node = true;         // Becomes false when force is applied

    // 计算所有弹簧产生的合力
    for (int i = 0; i < 4; i++) {
        if (connection[i] != -1) {
            // q is the position of the other vertex
            vec3 q = texelFetch(tex_position, connection[i]).xyz;
            vec3 d = q - p;
            float x = length(d);
            //需要注意的是合力的计算方式应该是所有向量力的和，弹簧力由于原书中使用的是作用点到施力点的标准向量和形变距离的负数，因此需要添加负号，而阻尼力又和速度的方向相反，因此也需要取负。
            F += -k * (rest_length - x) * normalize(d);
            fixed_node = false;
        }
    }
    
    // If this is a fixed node, reset force to zero
    if (fixed_node) {
        F = vec3(0.0);
    }

    // Acceleration due to force
    vec3 a = F / m;

    // Displacement
    vec3 s = u * t + 0.5 * a * t * t;

    // Final velocity
    vec3 v = u + a * t;

    // Constrain the absolute value of the displacement per step
    s = clamp(s, vec3(-25.0), vec3(25.0));

    // Write the outputs
    tf_position_mass = vec4(p + s, m);
    tf_velocity = v;
}

