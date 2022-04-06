// -*-C++-*-


#version 120

uniform float hazeLayerAltitude;
uniform float terminator;
uniform float terrain_alt;
uniform float overcast;
uniform float ground_scattering;
uniform float eye_alt;
uniform float moonlight;
uniform float alt_agl;
uniform   float pitch;
uniform   float roll;
uniform float gear_clearance;



const float EarthRadius = 5800000.0;
const float terminator_width = 200000.0;

void rotationMatrixPR(in float sinRx, in float cosRx, in float sinRy, in float cosRy, out mat4 rotmat)
{
   rotmat = mat4(   cosRy ,   sinRx * sinRy ,   cosRx * sinRy,   0.0,
                           0.0   ,   cosRx        ,   -sinRx      ,   0.0,
                           -sinRy,   sinRx * cosRy,   cosRx * cosRy ,   0.0,
                           0.0   ,   0.0          ,   0.0           ,   1.0 );
}

/*

//Experimental - not used for now.  Seems to work functionally the same as rotationMatrixPR
void rotationMatrixRP(in float sinRx, in float cosRx, in float sinRy, in float cosRy, out mat4 rotmat)
{
   rotmat = mat4(   cosRy ,   sinRx * sinRy ,   -cosRx * sinRy,   0.0,
                           0.0   ,   cosRx        ,   sinRx      ,   0.0,
                           sinRy,   -sinRx * cosRy,   cosRx * cosRy ,   0.0,
                           0.0   ,   0.0          ,   0.0           ,   1.0 );
}
*/

float light_func (in float x, in float a, in float b, in float c, in float d, in float e)
{

if (x < -15.0) {return 0.0;}

return e / pow((1.0 + a * exp(-b * (x-c)) ),(1.0/d));
}

varying float alpha_correction;

void main()
{
    float start_fade = 0;
    float end_fade = 100;
    float diff = end_fade - start_fade;
    alpha_correction = 1.0 - smoothstep(start_fade, end_fade, alt_agl);

    gl_TexCoord[0] = gl_TextureMatrix[0] * gl_MultiTexCoord0;

    vec4 ep = gl_ModelViewMatrixInverse * vec4(0.0,0.0,0.0,1.0);
    vec3 relPos = gl_Vertex.xyz - ep.xyz;


    // compute the strength of light
    float vertex_alt = max(gl_Vertex.z,100.0);
    float scattering = ground_scattering + (1.0 - ground_scattering) * smoothstep(hazeLayerAltitude -100.0, hazeLayerAltitude + 100.0, vertex_alt);
    vec3 lightFull = (gl_ModelViewMatrixInverse * gl_LightSource[0].position).xyz;
    vec3 lightHorizon = normalize(vec3(lightFull.x,lightFull.y, 0.0));
    float yprime = -dot(relPos, lightHorizon);
    float yprime_alt = yprime - sqrt(2.0 * EarthRadius * vertex_alt);
    float earthShade = 0.6 * (1.0 - smoothstep(-terminator_width+ terminator, terminator_width + terminator, yprime_alt)) + 0.4;
    float lightArg = (terminator-yprime_alt)/100000.0;
    vec4 light_diffuse;
    light_diffuse.b = light_func(lightArg, 1.330e-05, 0.264, 3.827, 1.08e-05, 1.0);
    light_diffuse.g = light_func(lightArg, 3.931e-06, 0.264, 3.827, 7.93e-06, 1.0);
    light_diffuse.r = light_func(lightArg, 8.305e-06, 0.161, 3.827, 3.04e-05, 1.0);
    light_diffuse.a = 1.0;
    light_diffuse = light_diffuse * scattering;
    float shade_depth =  1.0 * smoothstep (0.6,0.95,ground_scattering) * (1.0-smoothstep(0.1,0.5,overcast)) * smoothstep(0.4,1.5,earthShade);

    light_diffuse.rgb = light_diffuse.rgb * (1.0 + 1.2 * shade_depth);

    //experiment
    light_diffuse.b = 1.0;
    light_diffuse.g = 1.0;
    light_diffuse.r = 1.0;
    light_diffuse.a = 1.0;

   //prepare rotation matrix
   mat4 RotMatPR;
   mat4 RotMatPR_tr;

   float _roll = roll;


   //if (_roll>90.0 || _roll < -90.0) //making roll=-roll when >90 is no longer necessary thanks to fix with transpose of rotation matrix.
    //{_roll = -_roll;}
   float cosRx = cos(radians(-_roll));
   float sinRx = sin(radians(-_roll));
   float cosRy = cos(radians(pitch));
   float sinRy = sin(radians(pitch));

   rotationMatrixPR(sinRx, cosRx, sinRy, cosRy, RotMatPR);
   //rotationMatrixRP(sinRx, cosRx, sinRy, cosRy, RotMatPR);

   RotMatPR_tr=transpose(RotMatPR); //RotMatPR works fine if pitch =0 or roll=0 but if say pitch=35 and roll=60 the rotation is all wrong. transpose(RotMatPR) however works perfectly.


    // project the shadow onto the ground
    //vec4 vertex =   RotMatPR * gl_Vertex;
    vec4 vertex =   RotMatPR_tr * gl_Vertex;
    vec4 pos = vertex;

    vec2 deltaxy = lightFull.xy * 0.95* (alt_agl + vertex.z + gear_clearance)/lightFull.z;  //This is the 'actual' location, taking into a account the full 3-D structure of the aircraft

    vec2 deltazeroxy = lightFull.xy * 0.95* (alt_agl + gear_clearance)/lightFull.z; //Instead of using the exact z value of this particularly point to determine the distance of the shadow & reposition & shrink it appropriately, we'll just use the origin (0,0,0) of the model instead.  This avoids a problem below, where varying vertex.z in deltaxy and then using deltaxy to calculate dist caused the shadow to sort of slant upwards, thanks to the varying z values used

    float dist = sqrt(deltazeroxy.x * deltazeroxy.x + deltazeroxy.y * deltazeroxy.y + alt_agl * alt_agl);    //could use function 'distance' instead, might be better?


    if (dist < 75)
    {

         pos.z = -0.9 * alt_agl + 0.05 * vertex.z;
         //pos.z  = 0.05 * (vertex.z + gear_clearance);

         pos.xy -= deltaxy;

    }
    else
    {
         //The code below to shrink the shadow while keeping it 75 m. away has some issues that need to be fixed. Making the shadow shrink at x^2 rate partly to cover up this problem until it can be solved . . .
         //The problem is that the aircraft isn't flat/parallel to the ground any more, but it appears to be at an angle to the ground.
         //The various shrinkages perhaps mess with the angles somehow, meaning that when the animations apply the roll & pitch corrections they just don't quite work as they should
         pos.z = (-0.9*75)*alt_agl/dist + 0.05 * vertex.z ; //if the shadow is more than about 75 meters from the aircraft it disappears so we are going to just keep it right at 75 m. & make it smaller to simulate greater distance.
         //(-0.9*75) is the same factor for altitude we were using above when dist=75.  *alt_agl/dist keeps it at the right height proportionally to simulate the location at a further distance, while actually just keeping it at 75 m. distance.

         //pos.z = 0.05 * vertex.z ; //if the shadow is more than about 75 meters from the aircraft it disappears so we are going to just keep it right at 75 m. & make it smaller to simulate greater distance.



         //shrink the size FIRST, THEN move where it needs to be.  If you shrink later you're also shrinking the deltaxy distance moved, which doesn't work well
         pos.xy = 75 / dist * pos.xy;  //shrinking the size of the shadow to simulate further distance.  Should be linear shrinkage but doing it ^2 for now to help ucover up the issues in code above.

         pos.xy -= 75 * deltaxy/dist; // Similarly to above, * deltaxy/dist; keeps it at the right XY position proportionally to simulate the location at a further distance, while actually just keeping it at 75 m. distance.

    }

   // pos.z = pos.z - offset;

   //if (dist>=75) pos = pos * 30/dist; //not sure why this doesn't work/ perhaps an overflow of some kind?
   
    gl_Position =  gl_ModelViewProjectionMatrix * pos;

    gl_FrontColor = light_diffuse;
    //light_diffuse.a=0;
    gl_BackColor = gl_FrontColor;
    //gl_BackColor = light_diffuse;
}
