#version 120

varying float flogz;

void main()
{
    gl_Position = ftransform();
    // logarithmic depth
    flogz = 1.0 + gl_Position.w;
}
