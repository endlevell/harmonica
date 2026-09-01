#version 440

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float progress;
    float aspect;
    float rippleStrength;
};

layout(binding = 1) uniform sampler2D source;

void main() {
    vec2 centered = qt_TexCoord0 - vec2(0.5);
    vec2 metric = centered * vec2(aspect, 1.0);
    float distanceFromCenter = length(metric);
    float maximumRadius = 0.5 * length(vec2(aspect, 1.0));
    float edge = progress * maximumRadius;
    float edgeDistance = distanceFromCenter - edge;

    vec2 direction = distanceFromCenter > 0.0001
        ? metric / distanceFromCenter : vec2(0.0);
    float envelope = exp(-abs(edgeDistance) * 34.0);
    float wave = sin(edgeDistance * 92.0) * envelope * rippleStrength;
    vec2 displacement = direction * wave / vec2(aspect, 1.0);
    vec2 samplePosition = clamp(qt_TexCoord0 + displacement,
        vec2(0.001), vec2(0.999));

    float softness = max(0.003, maximumRadius * 0.008);
    float irisAlpha = 1.0 - smoothstep(edge - softness,
        edge + softness, distanceFromCenter);
    fragColor = texture(source, samplePosition) * irisAlpha * qt_Opacity;
}
