// -*- mode: C; -*-
// Licence: GPL v2
// based on
// © Emilian Huminiuc and Vivian Meazza 2011
// addition for wingflex mesh distortion by Thorsten Renk 2015

#version 120

varying	vec3	rawpos;
varying	vec3	VNormal;
varying	vec3	VTangent;
varying	vec3	VBinormal;
varying	vec3	vViewVec;
varying	vec3	reflVec;
varying vec3 	vertVec;

varying	float	alpha;

varying float flogz;

attribute	vec3	tangent;
attribute	vec3	binormal;

uniform	float		pitch;
uniform	float		roll;
uniform	float		hdg;
uniform float 		wingflex_alpha;
uniform float 		wingflex_trailing_alpha;
uniform float 		wingsweep_factor;
uniform	int  		refl_dynamic;
uniform int  		nmap_enabled;
uniform int  		shader_qual;
uniform int			rembrandt_enabled;

//////Fog Include///////////
// uniform	int 	fogType;
// void	fog_Func(int type);
////////////////////////////

void	rotationMatrixPR(in float sinRx, in float cosRx, in float sinRy, in float cosRy, out mat4 rotmat)
{
	rotmat = mat4(	cosRy ,	sinRx * sinRy ,	cosRx * sinRy,	0.0,
									0.0   ,	cosRx        ,	-sinRx * cosRx,	0.0,
									-sinRy,	sinRx * cosRy,	cosRx * cosRy ,	0.0,
									0.0   ,	0.0          ,	0.0           ,	1.0 );
}

void	rotationMatrixH(in float sinRz, in float cosRz, out mat4 rotmat)
{
	rotmat = mat4(	cosRz,	-sinRz,	0.0,	0.0,
									sinRz,	cosRz,	0.0,	0.0,
									0.0  ,	0.0  ,	1.0,	0.0,
									0.0  ,	0.0  ,	0.0,	1.0 );
}

void	main(void)
{
		vec4 vertex = gl_Vertex;


		float body_width = 0.7;
		float arm_reach = 4.8;

		float x_factor = max((abs(vertex.x) - body_width),0);
		float y_factor = max(vertex.y,0.0);
		float flex_factor1 = wingflex_alpha * (1.0 - wingsweep_factor);
		float flex_factor2 = wingflex_trailing_alpha * (1.0 -wingsweep_factor);


		if (flex_factor1<0.0) {flex_factor1 *=0.7;}
		if (flex_factor2<0.0) {flex_factor1 *=0.7;}

		// basic flapping motion is linear to arm_reach, then parabolic

		float intercept_point = 0.1 * arm_reach * arm_reach * flex_factor1;
	
		if (x_factor < arm_reach)
			{
			vertex.z += x_factor/arm_reach * intercept_point;
			}

		else	
			{		
			vertex.z += 0.1 * x_factor * x_factor * flex_factor1;
			}

		// upward stroke is slightly forward-swept, downward stroke a bit backward
		vertex.y += -0.25 * abs(x_factor) * flex_factor1;

		//trailing edge lags the motion
		vertex.z += 0.2 * y_factor * x_factor * flex_factor2;


		// if the wings are folded, we sweep them back
		vertex.y += 0.5 * x_factor * wingsweep_factor;
		float sweep_x = 0.5;
		if (vertex.x > 0.0) {sweep_x = - 0.5;}

		vertex.x+= sweep_x * (1.0 + 0.5 *x_factor) *   wingsweep_factor;


		rawpos = vertex.xyz;
		vec4 ecPosition = gl_ModelViewMatrix * vertex;

		VNormal = normalize(gl_NormalMatrix * gl_Normal);

		vec3 n = normalize(gl_Normal);
		vec3 tempTangent = cross(n, vec3(1.0,0.0,0.0));
		vec3 tempBinormal = cross(n, tempTangent);

		if (nmap_enabled > 0){
			tempTangent = tangent;
			tempBinormal  = binormal;
		}

		VTangent = normalize(gl_NormalMatrix * tempTangent);
		VBinormal = normalize(gl_NormalMatrix * tempBinormal);
		vec3 t = tempTangent;
		vec3 b = tempBinormal;

    // Super hack: if diffuse material alpha is less than 1, assume a
	// transparency animation is at work
		if (gl_FrontMaterial.diffuse.a < 1.0)
			alpha = gl_FrontMaterial.diffuse.a;
		else
			alpha = gl_Color.a;

    // Vertex in eye coordinates
		vertVec = ecPosition.xyz;
		vViewVec.x = dot(t, vertVec);
		vViewVec.y = dot(b, vertVec);
		vViewVec.z = dot(n, vertVec);

    // calculate the reflection vector
		vec4 reflect_eye = vec4(reflect(vertVec, VNormal), 0.0);
		vec3 reflVec_stat = normalize(gl_ModelViewMatrixInverse * reflect_eye).xyz;
		if (refl_dynamic > 0){
			//prepare rotation matrix
			mat4 RotMatPR;
			mat4 RotMatH;
			float _roll = roll;
			if (_roll>90.0 || _roll < -90.0)
			{
				_roll = -_roll;
			}
			float cosRx = cos(radians(_roll));
			float sinRx = sin(radians(_roll));
			float cosRy = cos(radians(-pitch));
			float sinRy = sin(radians(-pitch));
			float cosRz = cos(radians(hdg));
			float sinRz = sin(radians(hdg));
			rotationMatrixPR(sinRx, cosRx, sinRy, cosRy, RotMatPR);
			rotationMatrixH(sinRz, cosRz, RotMatH);
			vec3 reflVec_dyn = (RotMatH * (RotMatPR * normalize(gl_ModelViewMatrixInverse * reflect_eye))).xyz;

			reflVec = reflVec_dyn;
		} else {
			reflVec = reflVec_stat;
		}

		if(rembrandt_enabled < 1){
		gl_FrontColor = gl_FrontMaterial.emission + gl_Color
					  * (gl_LightModel.ambient + gl_LightSource[0].ambient);
		} else {
		  gl_FrontColor = gl_Color;
		}
		gl_Position = gl_ModelViewProjectionMatrix * vertex;
        // logarithmic depth
        flogz = 1.0 + gl_Position.w;
		//gl_Position = ftransform();
		gl_TexCoord[0] = gl_TextureMatrix[0] * gl_MultiTexCoord0;
}
