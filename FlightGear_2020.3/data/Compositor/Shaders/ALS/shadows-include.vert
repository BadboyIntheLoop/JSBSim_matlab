#version 120

uniform bool shadows_enabled;

uniform mat4 fg_LightMatrix_csm0;
uniform mat4 fg_LightMatrix_csm1;
uniform mat4 fg_LightMatrix_csm2;
uniform mat4 fg_LightMatrix_csm3;

varying vec4 lightSpacePos[4];


void setupShadows(vec4 eyeSpacePos)
{
    if (!shadows_enabled)
        return;

    float normalOffset = 0.005;

    float costheta = clamp(dot(gl_Normal, gl_LightSource[0].position.xyz), 0.0, 1.0);
    float slopeScale = 1.0 - costheta;
    normalOffset *= slopeScale;

    vec4 offsetPos = gl_ModelViewMatrix *
        (gl_Vertex + vec4(gl_Normal, 0.0) * normalOffset);

    vec4 offsets[4];
    offsets[0] = fg_LightMatrix_csm0 * offsetPos;
    offsets[1] = fg_LightMatrix_csm1 * offsetPos;
    offsets[2] = fg_LightMatrix_csm2 * offsetPos;
    offsets[3] = fg_LightMatrix_csm3 * offsetPos;

    lightSpacePos[0] = fg_LightMatrix_csm0 * eyeSpacePos;
    lightSpacePos[1] = fg_LightMatrix_csm1 * eyeSpacePos;
    lightSpacePos[2] = fg_LightMatrix_csm2 * eyeSpacePos;
    lightSpacePos[3] = fg_LightMatrix_csm3 * eyeSpacePos;

    // Offset only in UV space
    // lightSpacePos[0].xy = offsets[0].xy;
    // lightSpacePos[1].xy = offsets[1].xy;
    // lightSpacePos[2].xy = offsets[2].xy;
    // lightSpacePos[3].xy = offsets[3].xy;
}
