#version 460 core
#include <flutter/runtime_effect.glsl>

uniform vec2 uResolution;
uniform vec2 uLightPos;
uniform float uTime;
uniform float uFresnelIntensity;
uniform vec4 uBorderColor;

out vec4 fragColor;

void main() {
    vec2 uv = FlutterFragCoord().xy / uResolution;
    vec2 p = uv - vec2(0.5, 0.5);
    
    float edgeDist = length(p * 2.0);
    float fresnel = pow(clamp(edgeDist, 0.0, 1.0), 3.0) * uFresnelIntensity;
    
    vec2 lightDir = normalize(uLightPos - uv);
    float specular = max(dot(normalize(p), lightDir), 0.0);
    specular = pow(specular, 12.0) * 0.4;
    
    fragColor = uBorderColor * (fresnel + specular);
}
