#version 140

uniform usampler3D fg_ClusteredLightGrid;
uniform usamplerBuffer fg_ClusteredLightIndices;
uniform int fg_ClusteredTileSize;
uniform float fg_ClusteredSliceScale;
uniform float fg_ClusteredSliceBias;

const bool debug = true;
const float shininess = 16.0;

struct PointLight {
    vec4 position;
    vec4 ambient;
    vec4 diffuse;
    vec4 specular;
    vec4 attenuation;
};

struct SpotLight {
    vec4 position;
    vec4 direction;
    vec4 ambient;
    vec4 diffuse;
    vec4 specular;
    vec4 attenuation;
    float cos_cutoff;
    float exponent;
};

layout (std140) uniform PointLightBlock {
    PointLight pointLights[256];
};
layout (std140) uniform SpotLightBlock {
    SpotLight spotLights[256];
};


vec3 addColors(vec3 a, vec3 b)
{
    return 0.14 * log(exp(a/0.14) + exp(b/0.14) - vec3(1.0));
}

// @param p Fragment position in view space.
// @param n Fragment normal in view space.
vec3 addClusteredLightsContribution(vec3 inputColor, vec3 p, vec3 n)
{
    int slice = int(max(log2(-p.z) * fg_ClusteredSliceScale
                        + fg_ClusteredSliceBias, 0.0));
    ivec3 clusterCoord = ivec3(gl_FragCoord.xy / fg_ClusteredTileSize, slice);
    uvec3 cluster = texelFetch(fg_ClusteredLightGrid,
                               clusterCoord,
                               0).rgb;
    uint startIndex = cluster.r;
    uint pointCount = cluster.g;
    uint spotCount  = cluster.b;

    vec3 color = vec3(0.0);

    for (uint i = uint(0); i < pointCount; ++i) {
        uint lightListIndex = texelFetch(fg_ClusteredLightIndices,
                                         int(startIndex + i)).r;
        PointLight light = pointLights[lightListIndex];

        float range = light.attenuation.w;
        vec3 toLight = light.position.xyz - p;
        // Ignore fragments outside the light volume
        if (dot(toLight, toLight) > (range * range))
            continue;

        ////////////////////////////////////////////////////////////////////////
        // Actual lighting

        float d = length(toLight);
        float att = 1.0 / (light.attenuation.x             // constant
                           + light.attenuation.y * d       // linear
                           + light.attenuation.z * d * d); // quadratic
        vec3 lightDir = normalize(toLight);
        float NdotL = max(dot(n, lightDir), 0.0);

        vec3 Iamb  = light.ambient.rgb;
        vec3 Idiff = light.diffuse.rgb * NdotL;
        vec3 Ispec = vec3(0.0);

        if (NdotL > 0.0) {
            vec3 halfVector = normalize(lightDir + normalize(-p));
            float NdotHV = max(dot(n, halfVector), 0.0);
            Ispec = light.specular.rgb * att * pow(NdotHV, shininess);
        }

        color += addColors(color, (Iamb + Idiff + Ispec) * att);
    }

    for (uint i = uint(0); i < spotCount; ++i) {
        uint lightListIndex = texelFetch(fg_ClusteredLightIndices,
                                         int(startIndex + i)).r;
        SpotLight light = spotLights[lightListIndex];

        vec3 toLight = light.position.xyz - p;

        ////////////////////////////////////////////////////////////////////////
        // Actual lighting

        float d = length(toLight);
        float att = 1.0 / (light.attenuation.x             // constant
                           + light.attenuation.y * d       // linear
                           + light.attenuation.z * d * d); // quadratic

        vec3 lightDir = normalize(toLight);

        float spotDot = dot(-lightDir, light.direction.xyz);
        if (spotDot < light.cos_cutoff)
            continue;

        att *= pow(spotDot, light.exponent);

        float NdotL = max(dot(n, lightDir), 0.0);

        vec3 Iamb  = light.ambient.rgb;
        vec3 Idiff = light.diffuse.rgb * NdotL;
        vec3 Ispec = vec3(0.0);

        if (NdotL > 0.0) {
            vec3 halfVector = normalize(lightDir + normalize(-p));
            float NdotHV = max(dot(n, halfVector), 0.0);
            Ispec = light.specular.rgb * att * pow(NdotHV, shininess);
        }

        color += (Iamb + Idiff + Ispec) * att;
    }

    return clamp(color + inputColor, 0.0, 1.0);
}
