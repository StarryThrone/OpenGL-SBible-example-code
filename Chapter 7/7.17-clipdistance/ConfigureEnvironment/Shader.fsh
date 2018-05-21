#version 410 core

// Output
layout (location = 0) out vec4 color;

// Input from vertex shader
in VS_OUT {
    vec3 N;
    vec3 L;
    vec3 V;
} fs_in;

// 关于光照系统的理论知识在后面的文章中介绍，此处只需要关心用户自定义剪切空间知识
// Material properties
// 漫反射率
uniform vec3 diffuse_albedo = vec3(0.3, 0.5, 0.2);
// 镜面反射率
uniform vec3 specular_albedo = vec3(0.7);
// 高光强度
uniform float specular_power = 128.0;
// 边缘颜色
uniform vec3 rim_color = vec3(0.1, 0.2, 0.2);
// 边缘光强度
uniform float rim_power = 5.0;

vec3 calculate_rim(vec3 N, vec3 V) {
    float f = 1.0 - dot(N, V);
    f = smoothstep(0.0, 1.0, f);
    f = pow(f, rim_power);
    return f * rim_color;
}

void main() {
    // Normalize the incoming N, L and V cectors
    vec3 N = normalize(fs_in.N);
    vec3 L = normalize(fs_in.L);
    vec3 V = normalize(fs_in.V);

    // Calculate R locally
    vec3 R = reflect(-L, N);

    // Compute the diffuse and specular components for each fragment
    vec3 diffuse = max(dot(N,L), 0.0) * diffuse_albedo;
    vec3 specular = pow(max(dot(R, V), 0.0), specular_power) * specular_albedo;
    vec3 rim = calculate_rim(N, V);

    // Write final color to the framebuffer
    color = vec4(diffuse + specular + rim, 1.0);
}
