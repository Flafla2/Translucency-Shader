#ifndef DICE_TRANSLUCENCY_INCLUDED
#define DICE_TRANSLUCENCY_INCLUDED

#include "UnityCG.cginc"
#include "UnityDeferredLibrary.cginc"
#include "UnityPBSLighting.cginc"
#include "UnityStandardUtils.cginc"
#include "UnityStandardBRDF.cginc"

// Used to have compatibility with default (Unity) lights, and a custom deferred shader.
#ifndef _LIGHTSCALE
#define _LIGHTSCALE 1
#endif

#ifndef _TRANSLIGHTCOLOR
#define _TRANSLIGHTCOLOR _LightColor
#endif

#ifndef LIGHT_PARAMS_FUNC
#define LIGHT_PARAMS_FUNC UnityDeferredCalculateLightParams
#endif

sampler2D _CameraGBufferTexture0;
sampler2D _CameraGBufferTexture1;
sampler2D _CameraGBufferTexture2;
		
half4 CalculateLight (unity_v2f_deferred i)
{
	float3 wpos;
	float2 uv;
	float atten, fadeDist;
	UnityLight light;
	UNITY_INITIALIZE_OUTPUT(UnityLight, light);
	LIGHT_PARAMS_FUNC (i, wpos, uv, light.dir, atten, fadeDist);

	half4 gbuffer0 = tex2D (_CameraGBufferTexture0, uv);
	half4 gbuffer1 = tex2D (_CameraGBufferTexture1, uv);
	half4 gbuffer2 = tex2D (_CameraGBufferTexture2, uv);

	light.color = _TRANSLIGHTCOLOR.rgb * atten;
	half3 baseColor = gbuffer0.rgb;

	half translucent = 1-gbuffer2.a;

	// If we have translucency enabled, there is only 1 specular term (ie specularity is grayscale).
	// So essentially if the translucent flag is enabled specColor = gbuffer1.rrr
	half3 specColor = half3(gbuffer1.r,lerp(gbuffer1.g,gbuffer1.r,translucent),lerp(gbuffer1.b,gbuffer1.r,translucent));
	half oneMinusRoughness = gbuffer1.a;
	half3 normalWorld = gbuffer2.rgb * 2 - 1;
	normalWorld = normalize(normalWorld);
	float3 eyeVec = normalize(wpos-_WorldSpaceCameraPos);
	half oneMinusReflectivity = 1 - SpecularStrength(specColor.rgb);
	light.ndotl = LambertTerm (normalWorld, light.dir);

	UnityIndirect ind;
	UNITY_INITIALIZE_OUTPUT(UnityIndirect, ind);
	ind.diffuse = 0;
	ind.specular = 0;

    half4 res = UNITY_BRDF_PBS (baseColor, specColor, oneMinusReflectivity, oneMinusRoughness, normalWorld, -eyeVec, light, ind);

	// DICE Translucency Calculation
	// http://www.gdcvault.com/play/1014538/Approximating-Translucency-for-a-Fast

	half3 vLTLight = -light.dir + normalWorld * gbuffer1.g; // gbuffer1.g = distortion
	half fLTDot = pow(saturate(dot(eyeVec, -vLTLight)), gbuffer1.b*10) * _LIGHTSCALE; // gbuffer1.b = power
	half3 fLT = atten * fLTDot * gbuffer0.a; // gbuffer0.a = thickness, ignoring ambient term
	res += float4(baseColor * _TRANSLIGHTCOLOR.rgb * fLT,0) * translucent;

	// End DICE Translucency Calculation

	return res;
}

#endif // DICE_TRANSLUCENCY_INCLUDED