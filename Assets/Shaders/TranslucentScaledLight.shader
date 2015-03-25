Shader "CustomLights/PointTranslucent" {
	SubShader {
		Tags { "Queue"="Transparent-1" }
CGINCLUDE

float4 _LightParams;
half4 _CustomLightColor;

#define _LIGHTSCALE _LightParams.x
#define _LIGHTSIZE _LightParams.y
#define _LIGHTINVSQUARERADIUS _LightParams.z
#define _TRANSLIGHTCOLOR _CustomLightColor
#define LIGHT_PARAMS_FUNC TranslucentCalculateLightParams
#define POINT // for UnityDeferredLibrary.cginc

#include "UnityCG.cginc"
#include "UnityDeferredLibrary.cginc"

// Calculates some basic light parameters used later to calculate lighting
void TranslucentCalculateLightParams (
	unity_v2f_deferred i,
	out float3 outWorldPos,
	out float2 outUV,
	out half3 outLightDir,
	out float outAtten,
	out float outFadeDist)
{
	// Ray from the camera to the given pixel
	i.ray = i.ray * (_ProjectionParams.z / i.ray.z);
	// Screen-space UV of this pixel
	float2 uv = i.uv.xy / i.uv.w;
	
	// read depth and reconstruct world position
	float depth = SAMPLE_DEPTH_TEXTURE(_CameraDepthTexture, uv);
	depth = Linear01Depth (depth);
	// Camera-space position of this pixel
	float4 vpos = float4(i.ray * depth,1);
	// World-space position of this pixel
	float3 wpos = mul (_CameraToWorld, vpos).xyz;
	
	// Position of the light in world space
	float3 lightPos = float3(_Object2World[0][3], _Object2World[1][3], _Object2World[2][3]);

	// Point light
	float3 tolight = wpos - lightPos;
	half3 lightDir = -normalize (tolight);
	
	// att is the distance from this pixel to the light
	// ||tolight||^2 / radius^2, because a self dot product = square of magnitude
	float att = dot(tolight, tolight) * _LIGHTINVSQUARERADIUS;
	// Light attenuation data is stored in a texture from unity.  att.rr is a Vector2 of distance
	float atten = tex2D (_LightTextureB0, att.rr).UNITY_ATTEN_CHANNEL;

	outWorldPos = wpos;
	outUV = uv;
	outLightDir = lightDir;
	outAtten = atten;
	outFadeDist = 0;
}

#include "DICETranslucency.cginc"

ENDCG
		
		Pass {			
			Fog { Mode Off }
			ZTest Always Cull Front ZWrite Off
			Blend One One
			// For some dumbshit reason we need to use the stencil buffer to fix edit mode.
			// If we don't do this, then edit mode has a giant black sphere around the light.
			Stencil {
				ref [_StencilNonBackground]
				readmask [_StencilNonBackground]
				// Normally just comp would be sufficient, but there's a bug and only front face stencil state is set (case 583207)
				compback equal
				compfront equal
			}


CGPROGRAM
#pragma target 3.0
#pragma vertex vert
#pragma fragment frag
#pragma exclude_renderers nomrt

unity_v2f_deferred vert (float4 vertex : POSITION)
{
	unity_v2f_deferred o;
	o.pos = mul(UNITY_MATRIX_MVP, vertex);
	o.uv = ComputeScreenPos (o.pos);
	o.ray = mul (UNITY_MATRIX_MV, vertex).xyz * float3(-1,-1,1);
	return o;
}

half4 frag (unity_v2f_deferred i) : SV_Target
{
	half4 c = CalculateLight(i);
	return c;
}
			
ENDCG
		} // Pass
	} // Subshader
	FallBack Off
} // Shader
