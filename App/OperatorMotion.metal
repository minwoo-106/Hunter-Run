#include <metal_stdlib>
using namespace metal;

// Inverse sample mapping. The waist stays anchored and the torso expands by
// less than a pixel on most phones; the head moves coherently with the shoulders.
[[ stitchable ]] float2 operatorBreath(float2 position, float time, float2 size) {
    float2 uv = position / max(size, float2(1.0));
    float breath = sin(time * 1.35);
    float torso = smoothstep(0.25, 0.40, uv.y) * (1.0 - smoothstep(0.53, 0.72, uv.y));
    float upper = 1.0 - smoothstep(0.38, 0.73, uv.y);
    float2 displacement = float2((uv.x - 0.52) * size.x * 0.0035 * torso * breath,
                                 size.y * 0.0014 * upper * breath);
    return position - clamp(displacement, float2(-3.0), float2(3.0));
}
