

Shader "Custom/InteriorMapping(CubeMethod Master)"
{
	Properties 
	{
		_Interior2DTex("Interior 2D Texture", 2D) = "white"
		_InteriorCubemapTex("Interior Cubemap Texture", CUBE) = "white"
		_InteriorCubemapTex_Z("Interior Cubemap Texture Z Tile&Offset", Vector) = (1,1,0,0)
		_InteriorRoomSize("Interior Room Size", Vector) = (1,1,1,0)

		[KeywordEnum(TANGENT, LOCAL, WORLD)] _SPACE("Space", Float) = 0
		[KeywordEnum(MIX, TEXTURE2D, CUBEMAP)] _TEXTUREMAP("Texture Mapping", Float) = 0
	}


	CGINCLUDE
	#pragma multi_compile _SPACE_TANGENT _SPACE_LOCAL _SPACE_WORLD
	#pragma multi_compile _TEXTUREMAP_MIX _TEXTUREMAP_TEXTURE2D _TEXTUREMAP_CUBEMAP
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
			};

			v2f vert(appdata_tan i)
			{
				float3 worldPos = mul(unity_ObjectToWorld, i.vertex).xyz;

				v2f o;
				o.pos = mul(UNITY_MATRIX_VP, float4(worldPos, 1.0));
				o.uv = i.texcoord;

				// 視線算出（ワールド空間）
				o.rayDir = worldPos - _WorldSpaceCameraPos.xyz;

#if _SPACE_TANGENT
				// 接空間の姿勢（向き）→ ワールド空間にしておく
				float3 normal = UnityObjectToWorldNormal(i.normal);
				float3 tangent = mul(unity_ObjectToWorld, i.tangent.xyz);
				float3 binormal = cross(normal, tangent.xyz) * i.tangent.w * unity_WorldTransformParams.w;

				// 視線を ワールド空間 → 接空間 に変換
				float3x3 toTangentMatrix = float3x3(tangent.xyz, binormal, normal);
				o.rayDir = mul(toTangentMatrix, o.rayDir);
				o.rayDir.z *= -1;

				// 視線を ワールド空間 → 接空間 に変換（こちらの方が若干スマート）
				//o.rayDir = float3(dot(tangent.xyz, o.rayDir), dot(binormal, o.rayDir), dot(normal, o.rayDir));
				//o.rayDir.z *= -1;
#elif _SPACE_LOCAL
				// 視線 および 視線開始座標をローカル空間にする
				o.rayPos = i.vertex;
				o.rayDir = mul(unity_WorldToObject, o.rayDir);
#else // _SPACE_WORLD
				// 視線開始座標をワールド空間にする
				o.rayPos = worldPos;
#endif

				return o;
			}

			half4 frag(v2f i) : SV_TARGET
			{
				float3 rayDir = normalize(i.rayDir);

#if _SPACE_TANGENT
				float3 uvw = float3(frac(i.uv * _InteriorRoomSize.xy), -_InteriorRoomSize.z + 1.0);
#else
				// 視線開始座標をローカル（またはワールド）空間にする
				float3 uvw = frac(i.rayPos * 4.0 + i.rayDir * 1e-3);
#endif

				// 距離を算出
				float3 dist3 = (step(0.0, rayDir) - uvw) / rayDir;
				float dist = min(min(dist3.x, dist3.y), dist3.z);

				// 衝突場所の算出
				float3 rayHit = uvw + rayDir * dist;
				rayHit.z = (rayHit.z + _InteriorRoomSize.z - 1.0) / _InteriorRoomSize.z;
				float3 rayHitNormal = step(1.0 - 1e-3, abs(rayHit - 0.5) * 2.0);

#if _TEXTUREMAP_MIX || _TEXTUREMAP_TEXTURE2D
				// テクスチャ(2D)
				const float Tex2DTileSize = 1.0 / 4.0; // 4x4 の 16枚
				float2 texture2DUV = {0,0};

	#if _SPACE_TANGENT
				// テクスチャ(2D)
				{
					const float Tex2DTileSize = 1.0 / 4.0; // 4x4 の 16枚
					float2 texture2DUV = { 0,0 };

					// 人物/物（接空間のみ）
					float distPlane = 0.5 / rayDir.z;
					float3 rayHitPlane = uvw + rayDir * distPlane;

					texture2DUV += Tex2DTileSize * (rayHitPlane.xy + float2(2, 2));
					float4 planeColor = tex2D(_Interior2DTex, texture2DUV);

					if (0.5 < planeColor.a && distPlane < dist)
						return planeColor;

				}
	#endif
#endif

#if _TEXTUREMAP_TEXTURE2D
				//texture2DUV += rayHitNormal.x * Tex2DTileSize * (rayHit.zy + float2(3, 0)) ;                      // X軸壁に衝突
				//texture2DUV += rayHitNormal.y * Tex2DTileSize * (rayHit.xz + float2(0, 2 * step(0.5, rayHit.y))); // Y軸壁に衝突
				//texture2DUV += rayHitNormal.z * Tex2DTileSize * (rayHit.xy + float2(2, 0));                       // Z軸壁に衝突
				//return tex2D(_Interior2DTex, texture2DUV);

				// テクスチャ(2D)角のジャギー対策
				float3 c = { 0,0,0 };
					 if (1.0 - 1e-3 <= rayHitNormal.x) c = tex2D(_Interior2DTex, rayHitNormal.x * Tex2DTileSize * (rayHit.zy + float2(3, 0)));
				else if (1.0 - 1e-3 <= rayHitNormal.y) c = tex2D(_Interior2DTex, rayHitNormal.y * Tex2DTileSize * (rayHit.xz + float2(0, 2 * step(0.5, rayHit.y))));
				else if (1.0 - 1e-3 <= rayHitNormal.z) c = tex2D(_Interior2DTex, rayHitNormal.z * Tex2DTileSize * (rayHit.xy + float2(2, 0)));
				return float4(c, 1.0);
#else
				// テクスチャ(Cubemap)
				float3 cubemapUV = (rayHit - 0.5) * 2.0;
				cubemapUV.xy *= _InteriorCubemapTex_ST.xy;
				cubemapUV.xy += _InteriorCubemapTex_ST.zw;
				cubemapUV.z *= _InteriorCubemapTex_Z.x;
				cubemapUV.z += _InteriorCubemapTex_Z.z;
				return UNITY_SAMPLE_TEXCUBE_SAMPLER(_InteriorCubemapTex, _InteriorCubemapTex, cubemapUV);
#endif
			}
			ENDCG
		}
	}
}
