#version 410

// 统一变量
uniform int num_spheres = 7;
uniform int num_planes = 6;
uniform int num_lights = 5;
uniform mat4 viewMatrix;
uniform float maxTraceTime = 1000000.0;
uniform float maxTraceDistanceZ = 1000000.0;

uniform sampler2D tex_origin;
uniform sampler2D tex_direction;
uniform sampler2D tex_color;

struct ray {
    vec3 origin;
    vec3 direction;
};

struct sphere {
    // 前3个float分量表示球心坐标，第4个float分量表示球半径
    vec4 centerRadius;
    vec4 color;
};

struct light {
    vec3 position;
};

layout (std140) uniform SPHERES {
    sphere      S[128];
};

layout (std140) uniform PLANES {
    vec4        P[128];
};

layout (std140) uniform LIGHTS {
    light       L[120];
} lights;

// 输出变量
// 当前轮光线追踪计算出的片段颜色
layout (location = 0) out vec3 color;
// 下一轮光线追踪时当前片段的射线起点
layout (location = 1) out vec3 rayOrigin;
// 下一轮光线追踪时当前片段的反射方向
layout (location = 2) out vec3 reflectedDirection;
// 下一轮光线追踪时当前片段的折射方向
layout (location = 3) out vec3 refractedDirection;
// 下一轮光线追踪时当前片段的颜色反射率
layout (location = 4) out vec3 reflectedColorAlbedo;
// 下一轮光线追踪时当前片段的颜色折射率
layout (location = 5) out vec3 refractedColorAlbedo;

// 测试某个射线是否和某个球相交，并返回交点，及交点在球面的法向量
// 射线R的起点为O，方向为D，球心为C，半径为r
// 则从射线起点出发，经过时间t和球面相交满足如下公式
// t = (-B +- (B^2 - 4*A*C)^(1/2)) / 2*A
// 其中A = D * D
//    B = 2 * (O - C) * D
//    C = (O - C) * (O - C) - r^2
// 当t存在正解时在射线方向和球体存在交点
// 当D为单位向量时，上式可以进一步简写为 t = (-B +- (B^2 - 4*C)^(1/2)) / 2
bool intersect_ray_sphere(ray R, sphere S, out vec3 hitpos, out vec3 normal) {
    vec3 sphereCenterInViewSpace = (viewMatrix * vec4(S.centerRadius.xyz, 1.0)).xyz;
    vec3 centerToOrigin = R.origin - sphereCenterInViewSpace;
    
    float B = 2.0 * dot(centerToOrigin, R.direction);
    float C = dot(centerToOrigin, centerToOrigin) - (S.centerRadius.w * S.centerRadius.w);

    float factorA = B * B - 4.0 * C;
    if (factorA < 0.0) {
        // 如果根号下的等式计算出的值小于0，则方程无解，射线R和球体不会存在交点
        return false;
    }
    factorA = sqrt(factorA);

    float t1 = (-B + factorA) * 0.5;
    float t2 = (-B - factorA) * 0.5;
    float t;
    if (t1 <= 0.0) {
        // 如果到达第一个交点需要的耗时不为正值，则认为该射线方向不会和球体相交
        // 取第二个交点耗时和0的最大值
        t = max(0, t2);
    } else {
        if (t2 <= 0.0) {
            // 如果到达第二个交点需要的耗时不为正值，则认为该射线方向不会和球体相交
            // 取第1个交点耗时和0的最大值
            t = max(0, t1);
        } else {
            // 如果两个交点的耗时都为正值，表示两个焦点都在射线前方，取最近的交点
            t = min(t1, t2);
        }
    }

    if (t <= 0.0 || t > maxTraceTime) {
        // 如果到达交点的耗时不为正值，认为射线不会和球体相交
        // 如果耗时超过了最大能够追踪的市场，认为超出视野范围
        return false;
    }

    // 计算在视图坐标系中的交点坐标
    hitpos = R.origin + t * R.direction;
    // 计算在视图坐标系总交点在球面的法向量
    normal = normalize(hitpos - sphereCenterInViewSpace);
    
    return true;
}

// 测试某个射线是否和某个平面相交，并返回交点，及交点在平面的法向量
// 射线R的起点为O，方向为D，平面法向量为N，坐标系原点到平面的垂直距离为d
// 则从射线起点出发，经过时间t和平面面相交满足如下公式
// t = -(O * N + d) / D * N
// 当t存在正解时在射线方向和平面存在交点
bool intersect_ray_plane(ray R, vec4 P, out vec3 hitpos, out vec3 normal) {
    vec3 O = R.origin;
    vec3 D = R.direction;
    // 在视图空间进行计算，需要进行坐标系转换
    vec3 N = (viewMatrix * vec4(P.xyz, 0.0)).xyz;
    float d = P.w;

    float denom = dot(D, N);
    if (denom == 0.0) {
        // 射线向量和平面平行，则一定没有交点
        return false;
    }
    float t = -(dot(O, N) + d) / denom;
    if (t <= 0.0) {
        // 如果计算出的耗时不为正值，则认为和平面无交点
        return false;
    }

    hitpos = O + t * D;
    normal = N;

    return true;
}

// 检测某个点是否对光源可见
bool point_visible_to_light(vec3 point, vec3 L) {
    return true;
    int i;
    ray R;
    vec3 normal;
    vec3 hitpos;

    R.direction = normalize(L - point);
    R.origin = point + R.direction * 0.001;

    for (i = 0; i < num_spheres; i++) {
        if (intersect_ray_sphere(R, S[i], hitpos, normal)) {
            return false;
        }
    }
    
    for (i = 0; i < num_planes; i++) {
        if (intersect_ray_plane(R, P[i], hitpos, normal)) {
            return false;
        }
    }

    return true;
}

// 计算某个点在某个光照下的颜色
vec3 light_point(vec3 position, vec3 normal, vec3 V, light l) {
    vec3 ambient = vec3(0.0);

    if (!point_visible_to_light(position, l.position)) {
        return ambient;
    } else {
        // vec3 V = normalize(-position);
        vec3 L = normalize(l.position - position);
        vec3 N = normal;
        vec3 R = reflect(-L, N);

        float rim = clamp(dot(N, V), 0.0, 1.0);
        rim = smoothstep(0.0, 1.0, 1.0 - rim);
        float diff = clamp(dot(N, L), 0.0, 1.0);
        float spec = pow(clamp(dot(R, N), 0.0, 1.0), 260.0);

        vec3 rim_color = vec3(0.0); // , 0.2, 0.2);
        vec3 diff_color = vec3(0.125); // , 0.8, 0.8);
        vec3 spec_color = vec3(0.1);

        return ambient + rim_color * rim + diff_color * diff + spec_color * spec;
    }
}

void main(void) {
    // 1. 如果输入的原始颜色比vec3(0.05)小，则不再继续光线追踪
    vec3 input_color = texelFetch(tex_color, ivec2(gl_FragCoord.xy), 0).rgb;
    if (all(lessThan(input_color, vec3(0.05)))) {
        color = vec3(0.0);
        rayOrigin = vec3(0.0);
        reflectedDirection = vec3(0.0);
        refractedDirection = vec3(0.0);
        reflectedColorAlbedo = vec3(0.0);
        refractedColorAlbedo = vec3(0.0);
        
        color = vec3(1.0);
        return;
    }
    
    // 2. 确定光线追踪的射线
    ray R;
    R.origin = texelFetch(tex_origin, ivec2(gl_FragCoord.xy), 0).xyz;
    R.direction = normalize(texelFetch(tex_direction, ivec2(gl_FragCoord.xy), 0).xyz);
    
    // 3. 假定光线和最近模型曲面的交点为hit_position
    // 先假定相交于最大视野处
    vec3 hit_position = vec3(0.0, 0.0, -maxTraceDistanceZ);
    vec3 hit_normal = vec3(0.0);
    
    // 4. 测试光线和所有的球模型的交点
    vec3 hitpos;
    vec3 normal;
    int sphere_index = 0;
    for (int i = 0; i < num_spheres; i++) {
        if (intersect_ray_sphere(R, S[i], hitpos, normal)) {
            if (hitpos.z > hit_position.z) {
                hit_position = hitpos;
                hit_normal = normal;
                sphere_index = i;
            }
        }
    }
    
    // 5. 测试光线和所有的平面模型的交点
    for (int i = 0; i < 6; i++) {
        if (intersect_ray_plane(R, P[i], hitpos, normal)) {
            if (hitpos.z > hit_position.z) {
                hit_position = hitpos;
                hit_normal = normal;
                sphere_index = i * 25;
            }
        }
    }
    
    // 计算片段点颜色，和下一轮光线追踪的必要参数
    if (hit_position.z > -maxTraceDistanceZ) {
        // 如果经过模型相交测试后得到的交点值小于最大可追踪Z轴距离，则认为找到了交点
        // 计算当前轮光线追踪计算出的片段颜色
        vec3 my_color = vec3(0.0);
        for (int i = 0; i < num_lights; i++) {
            my_color += light_point(hit_position, hit_normal, -R.direction, lights.L[i]);
        }
        my_color *= S[sphere_index].color.rgb;
        color = input_color * my_color;
        
        // 计算下一轮光线追踪时当前片段的射线起点
        rayOrigin = hit_position;

        // 计算下一轮光线追踪时当前片段的反射方向
        reflectedDirection = reflect(R.direction, hit_normal);
        // 计算下一轮光线追踪时当前片段的颜色反射率
        reflectedColorAlbedo = S[sphere_index].color.rgb * 0.5;
        
        // 计算下一轮光线追踪时当前片段的折射方向
        refractedDirection = refract(R.direction, hit_normal, 1.73);
        // 计算下一轮光线追踪时当前片段的颜色折射率
        refractedColorAlbedo = input_color * S[sphere_index].color.rgb * 0.5;
    } else {
        color = vec3(0.0);
        rayOrigin = vec3(0.0);
        reflectedDirection = vec3(0.0);
        refractedDirection = vec3(0.0);
        reflectedColorAlbedo = vec3(0.0);
        refractedColorAlbedo = vec3(0.0);
    }
}
