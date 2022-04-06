#version 120

uniform sampler2DShadow shadow_tex;

uniform bool shadows_enabled;
uniform int sun_atlas_size;

varying vec4 lightSpacePos[4];

const float depth_bias = 0.0005;

// Ideally these should be passed as an uniform, but we don't support uniform
// arrays yet
const vec2 uv_shifts[4] = vec2[4](
    vec2(0.0, 0.0), vec2(0.5, 0.0),
    vec2(0.0, 0.5), vec2(0.5, 0.5));
const vec2 uv_factor = vec2(0.5, 0.5);


float checkWithinBounds(vec2 coords, vec2 bottomLeft, vec2 topRight)
{
    vec2 r = step(bottomLeft, coords) - step(topRight, coords);
    return r.x * r.y;
}

float sampleOffset(vec4 pos, vec2 offset, vec2 invTexelSize)
{
    return shadow2DProj(
        shadow_tex, vec4(
            pos.xy + offset * invTexelSize * pos.w,
            pos.z - depth_bias,
            pos.w)).r;
}

// OptimizedPCF from https://github.com/TheRealMJP/Shadows
// Original by Ignacio Castaño for The Witness
// Released under The MIT License
float sampleOptimizedPCF(vec4 pos)
{
    vec2 invTexelSize = vec2(1.0 / float(sun_atlas_size));

    vec2 uv = pos.xy * sun_atlas_size;
    vec2 base_uv = floor(uv + 0.5);
    float s = (uv.x + 0.5 - base_uv.x);
    float t = (uv.y + 0.5 - base_uv.y);
    base_uv -= vec2(0.5);
    base_uv *= invTexelSize;
    pos.xy = base_uv.xy;

    float sum = 0.0;

    float uw0 = (4.0 - 3.0 * s);
    float uw1 = 7.0;
    float uw2 = (1.0 + 3.0 * s);

    float u0 = (3.0 - 2.0 * s) / uw0 - 2.0;
    float u1 = (3.0 + s) / uw1;
    float u2 = s / uw2 + 2.0;

    float vw0 = (4.0 - 3.0 * t);
    float vw1 = 7.0;
    float vw2 = (1.0 + 3.0 * t);

    float v0 = (3.0 - 2.0 * t) / vw0 - 2.0;
    float v1 = (3.0 + t) / vw1;
    float v2 = t / vw2 + 2.0;

    sum += uw0 * vw0 * sampleOffset(pos, vec2(u0, v0), invTexelSize);
    sum += uw1 * vw0 * sampleOffset(pos, vec2(u1, v0), invTexelSize);
    sum += uw2 * vw0 * sampleOffset(pos, vec2(u2, v0), invTexelSize);

    sum += uw0 * vw1 * sampleOffset(pos, vec2(u0, v1), invTexelSize);
    sum += uw1 * vw1 * sampleOffset(pos, vec2(u1, v1), invTexelSize);
    sum += uw2 * vw1 * sampleOffset(pos, vec2(u2, v1), invTexelSize);

    sum += uw0 * vw2 * sampleOffset(pos, vec2(u0, v2), invTexelSize);
    sum += uw1 * vw2 * sampleOffset(pos, vec2(u1, v2), invTexelSize);
    sum += uw2 * vw2 * sampleOffset(pos, vec2(u2, v2), invTexelSize);

    return sum / 144.0;
}

float sampleShadowMap(int n)
{
    float s = 1.0;
    if (n < 4) {
        vec4 pos = lightSpacePos[n];
        pos.xy *= uv_factor;
        pos.xy += uv_shifts[n];
        s = sampleOptimizedPCF(pos);
    }
    return s;
}

// Get a value between 0.0 and 1.0 where 0.0 means shadowed and 1.0 means lit
float getShadowing()
{
    if (!shadows_enabled)
        return 1.0;

    const float band_size = 0.2;
    const vec2 bandBottomLeft = vec2(band_size);
    const vec2 bandTopRight   = vec2(1.0 - band_size);

    for (int i = 0; i < 4; ++i) {
        if (checkWithinBounds(lightSpacePos[i].xy, vec2(0.0), vec2(1.0)) > 0.0 &&
            (lightSpacePos[i].z / lightSpacePos[i].w) <= 1.0) {
            if (checkWithinBounds(lightSpacePos[i].xy, bandBottomLeft, bandTopRight) < 1.0) {
                vec2 s =
                    smoothstep(vec2(0.0), bandBottomLeft, lightSpacePos[i].xy) -
                    smoothstep(bandTopRight, vec2(1.0), lightSpacePos[i].xy);
                float blend = 1.0 - s.x * s.y;
                return mix(sampleShadowMap(i), sampleShadowMap(i+1), blend);
            }
            return sampleShadowMap(i);
        }
    }

    return 1.0;
}
