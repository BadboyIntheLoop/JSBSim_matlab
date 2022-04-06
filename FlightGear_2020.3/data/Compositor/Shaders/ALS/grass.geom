// -*-C++-*-
#version 120
#extension GL_EXT_geometry_shader4 : enable

#define MAX_LAYERS 20
#define MIN_LAYERS 8
#define MAX_MINUS_MIN_LAYERS 12

uniform float max_height;

varying in vec3 v_normal[3];

varying out vec2 g_rawpos;
varying out float g_distance_to_eye;
varying out float g_layer;

varying out float flogz;


uniform mat4 fg_LightMatrix_csm0;
uniform mat4 fg_LightMatrix_csm1;
uniform mat4 fg_LightMatrix_csm2;
uniform mat4 fg_LightMatrix_csm3;
varying out vec4 lightSpacePos[4];
void setupShadows(vec4 eyeSpacePos)
{
    lightSpacePos[0] = fg_LightMatrix_csm0 * eyeSpacePos;
    lightSpacePos[1] = fg_LightMatrix_csm1 * eyeSpacePos;
    lightSpacePos[2] = fg_LightMatrix_csm2 * eyeSpacePos;
    lightSpacePos[3] = fg_LightMatrix_csm3 * eyeSpacePos;
}

float min3(in float a, in float b, in float c)
{
    float m = a;
    if (m > b) m = b;
    if (m > c) m = c;
    return m;
}

void main()
{
    float distances[3];
    distances[0] = -(gl_ModelViewMatrix * gl_PositionIn[0]).z;
    distances[1] = -(gl_ModelViewMatrix * gl_PositionIn[1]).z;
    distances[2] = -(gl_ModelViewMatrix * gl_PositionIn[2]).z;
    float minDistance = min3(distances[0], distances[1], distances[2]);
    //float avgDistance = (distances[0]+distances[1]+distances[2])*0.33;

    int numLayers = MIN_LAYERS + int(smoothstep(500.0, 50.0, minDistance) * float(MAX_MINUS_MIN_LAYERS));

    float deltaLayer = 1.0 / float(numLayers);
    float currDeltaLayer = deltaLayer * 0.5;

    for (int layer = 0; layer < numLayers; ++layer) {
        for (int i = 0; i < 3; ++i) {
            vec4 pos = gl_PositionIn[i] + vec4(v_normal[i] * currDeltaLayer * max_height, 0.0);
            g_rawpos = gl_PositionIn[i].xy;
            g_distance_to_eye = distances[i];
            g_layer = currDeltaLayer;

            setupShadows(gl_ModelViewMatrix * pos);

            gl_Position = gl_ModelViewProjectionMatrix * pos;
            // logarithmic depth
            flogz = 1.0 + gl_Position.w;
            gl_TexCoord[0] = gl_TexCoordIn[i][0];
            EmitVertex();
        }
        EndPrimitive();

        currDeltaLayer += deltaLayer;
    }
}
