﻿Shader "Custom/MeshParticle"
{
    Properties
    {
        _Color ("Color", Color) = (1,1,1,1)
        _MainTex ("Albedo (RGB)", 2D) = "white" {}
        _Glossiness ("Smoothness", Range(0,1)) = 0.5
        _Metallic ("Metallic", Range(0,1)) = 0.0
    }

	SubShader
	{
		CGINCLUDE
		#include "UnityCG.cginc"

		// Object rendering things
		float4x4 _PreviousVP;
		float4x4 _PreviousM;
		float4x4 _PreviousM2;
		bool _HasLastPositionData;
		float _MotionVectorDepthBias;

		struct MotionVectorData
		{
			float4 transferPos : TEXCOORD0;
			float4 transferPosOld : TEXCOORD1;
			float4 pos : SV_POSITION;
		};

		struct MotionVertexInput
		{
			float4 vertex : POSITION;
			float3 oldPos : NORMAL;
		};

		MotionVectorData VertMotionVectors(MotionVertexInput v)
		{
			MotionVectorData o;
			o.pos = UnityObjectToClipPos(v.vertex);

			// this works around an issue with dynamic batching
			// potentially remove in 5.4 when we use instancing
#if defined(UNITY_REVERSED_Z)
			o.pos.z -= _MotionVectorDepthBias * o.pos.w;
#else
			o.pos.z += _MotionVectorDepthBias * o.pos.w;
#endif
			o.transferPos = o.pos;
			o.transferPosOld = mul(_PreviousVP, mul(_PreviousM2, _HasLastPositionData ? float4(v.oldPos, 1) : v.vertex));
			return o;
		}

		half4 FragMotionVectors(MotionVectorData i) : SV_Target
		{
			float3 hPos = (i.transferPos.xyz / i.transferPos.w);
			float3 hPosOld = (i.transferPosOld.xyz / i.transferPosOld.w);

			// V is the viewport position at this pixel in the range 0 to 1.
			float2 vPos = (hPos.xy + 1.0f) / 2.0f;
			float2 vPosOld = (hPosOld.xy + 1.0f) / 2.0f;

#if UNITY_UV_STARTS_AT_TOP
			vPos.y = 1.0 - vPos.y;
			vPosOld.y = 1.0 - vPosOld.y;
#endif
			half2 uvDiff = vPos - vPosOld;
			return half4(uvDiff, 0, 1);
		}

		//Camera rendering things
		sampler2D_float _CameraDepthTexture;

		struct CamMotionVectors
		{
			float4 pos : SV_POSITION;
			float2 uv : TEXCOORD0;
			float3 ray : TEXCOORD1;
		};

		CamMotionVectors VertMotionVectorsCamera(float4 vertex : POSITION, float3 normal : NORMAL)
		{
			CamMotionVectors o;
			o.pos = UnityObjectToClipPos(vertex);

#ifdef UNITY_HALF_TEXEL_OFFSET
			o.pos.xy += (_ScreenParams.zw - 1.0) * float2(-1, 1) * o.pos.w;
#endif
			o.uv = ComputeScreenPos(o.pos);
			// we know we are rendering a quad,
			// and the normal passed from C++ is the raw ray.
			o.ray = normal;
			return o;
		}
		
		inline half2 CalculateMotion(float rawDepth, float2 inUV, float3 inRay)
		{
			float depth = Linear01Depth(rawDepth);
			float3 ray = inRay * (_ProjectionParams.z / inRay.z);
			float3 vPos = ray * depth;
			float4 worldPos = mul(unity_CameraToWorld, float4(vPos, 1.0));

			float4 prevClipPos = mul(_PreviousVP, worldPos);
			float2 prevHPos = prevClipPos.xy / prevClipPos.w;
			
			// V is the viewport position at this pixel in the range 0 to 1.
			float2 vPosPrev = (prevHPos.xy + 1.0f) / 2.0f;
#if UNITY_UV_STARTS_AT_TOP
			vPosPrev.y = 1.0 - vPosPrev.y;
#endif

			return inUV - vPosPrev;
		}

		half4 FragMotionVectorsCamera(CamMotionVectors i) : SV_Target
		{
 			float depth = SAMPLE_DEPTH_TEXTURE(_CameraDepthTexture, i.uv);
			return half4(CalculateMotion(depth, i.uv, i.ray), 0, 1);
		}

		half4 FragMotionVectorsCameraWithDepth(CamMotionVectors i, out float outDepth : SV_Depth) : SV_Target
		{
			float depth = SAMPLE_DEPTH_TEXTURE(_CameraDepthTexture, i.uv);
			outDepth = depth;
			return half4(CalculateMotion(depth, i.uv, i.ray), 0, 1);
		}
		ENDCG

		// 0 - Motion vectors
		Pass
		{
			Tags{ "LightMode" = "MotionVectors" }
			
			ZTest LEqual
			Cull Back
			ZWrite Off

			CGPROGRAM
			#pragma vertex VertMotionVectors
			#pragma fragment FragMotionVectors
			ENDCG
		}

		// 1 - Camera motion vectors
		Pass
		{
			ZTest Always
			Cull Off
			ZWrite Off
			
			CGPROGRAM
			#pragma vertex VertMotionVectorsCamera
			#pragma fragment FragMotionVectorsCamera
			ENDCG
		}

		// 2 - Camera motion vectors (With depth (msaa / no render texture))
		Pass
		{
			ZTest Always
			Cull Off
			ZWrite On
			
			CGPROGRAM
			#pragma vertex VertMotionVectorsCamera
			#pragma fragment FragMotionVectorsCameraWithDepth
			ENDCG
		}
	}



    SubShader
    {
        Tags { "RenderType"="Opaque" }

        CGPROGRAM

        #pragma surface surf Standard fullforwardshadows
        #pragma target 3.0

        sampler2D _MainTex;

        struct Input {
            float2 uv_MainTex;
        };

        half _Glossiness;
        half _Metallic;
        fixed4 _Color;

        void surf (Input IN, inout SurfaceOutputStandard o) {
            // Albedo comes from a texture tinted by color
            fixed4 c = tex2D (_MainTex, IN.uv_MainTex) * _Color;
            o.Albedo = c.rgb;
            // Metallic and smoothness come from slider variables
            o.Metallic = _Metallic;
            o.Smoothness = _Glossiness;
            o.Alpha = c.a;
        }
        ENDCG
    }
    FallBack "Diffuse"
}
