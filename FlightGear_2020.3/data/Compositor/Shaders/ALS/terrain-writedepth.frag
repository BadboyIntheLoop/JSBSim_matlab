#version 120

uniform float fg_Fcoef;

varying float flogz;

void main()
{
    gl_FragColor = vec4(1.0, 1.0, 1.0, 1.0);
    // logarithmic depth
    gl_FragDepth = log2(flogz) * fg_Fcoef * 0.5;
}
