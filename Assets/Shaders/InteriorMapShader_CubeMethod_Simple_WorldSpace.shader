

Shader "Custom/InteriorMapping(CubeMethod Simple WorldSpace)"
{
	Properties 
	{
		_Interior2DTex("Interior 2D Texture", 2D) = "white"
		_InteriorCubemapTex("Interior Cubemap Texture", CUBE) = "white"
		_InteriorCubemapTex_Z("Interior Cubemap Texture Z Tile&Offset", Vector) = (1,1,0,0)
		_InteriorRoomSize("Interior Room Size", Vector) = (1,1,1,0)
	}


	CGINCLUDE
	#include "UnityCG.cginc"
	#include "Noise.cginc"
	sampler2D _Interior2DTex;
	UNITY_DECLARE_TEXCUBE(_InteriorCubemapTex);
	float4 _InteriorCubemapTex_ST;
	float3 _InteriorCubemapTex_Z;
	float3 _InteriorRoomSize;
	ENDCG


	
	SubShader 
	{
		Tags
		{
			"RenderType"="Opaque"
		}
		
		Pass
		{
			CGPROGRAM
			#pragma vertex vert
			#pragma fragment frag

			struct v2f
			{
				float4 pos : SV_POSITION;
				float3 rayDir : TEXCOORD0;
				float2 uv : TEXCOORD1;
				float3 rayPos : TEXCOORD2;
				float3 test : TEXCOORD3;
			};

			v2f vert(appdata_tan i)
			{
				float3 worldPos = mul(unity_ObjectToWorld, i.vertex).xyz;

				v2f o;
				o.pos = mul(UNITY_MATRIX_VP, float4(worldPos, 1.0));
				o.uv = i.texcoord;

				// 接空間の姿勢（向き）→ ワールド空間にしておく
				float3 normal = UnityObjectToWorldNormal(i.normal);
				float3 tangent = mul(unity_ObjectToWorld, i.tangent.xyz);
				float3 binormal = cross(normal, tangent.xyz) * i.tangent.w * unity_WorldTransformParams.w;

				// 視線算出（ワールド空間）
				o.rayDir = worldPos - _WorldSpaceCameraPos.xyz;

				// 視線開始座標をワールド空間にする
				o.rayPos = worldPos;

				return o;
			}

			half4 frag(v2f i) : SV_TARGET
			{
				// 視線開始座標をローカル（またはワールド）空間にする
				float3 uvw = frac(i.rayPos * 4.0 + i.rayDir * 1e-3);
				float3 rayDir = normalize(i.rayDir);

				// 距離を算出
				float3 dist3 = (step(0.0, rayDir) - uvw) / rayDir;
				float dist = min(min(dist3.x, dist3.y), dist3.z);

				// 衝突場所の算出
				float3 rayHit = uvw + rayDir * dist;
				rayHit.z = (rayHit.z + _InteriorRoomSize.z - 1.0) / _InteriorRoomSize.z;

				// テクスチャ(Cubemap)
				float3 cubemapUV = (rayHit - 0.5) * 2.0;
				cubemapUV.xy *= _InteriorCubemapTex_ST.xy;
				cubemapUV.xy += _InteriorCubemapTex_ST.zw;
				cubemapUV.z *= _InteriorCubemapTex_Z.x;
				cubemapUV.z += _InteriorCubemapTex_Z.z;
				return UNITY_SAMPLE_TEXCUBE_SAMPLER(_InteriorCubemapTex, _InteriorCubemapTex, cubemapUV);
			}
			ENDCG
		}
	}
}
