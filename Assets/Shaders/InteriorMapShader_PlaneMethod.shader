

Shader "Custom/InteriorMapping(PlaneMethod)" 
{
	Properties 
	{
		_MainTex("Main Texture", 2D) = "white"
		_HeightTex("Height Texture", 2D) = "black"
		_FloorTexSizeAndOffset ("Floor Texture Size And Offset", Vector) = (1,1,0,0)
		_CeilTexSizeAndOffset ("Ceil Texture Size And Offset", Vector) = (1,1,0,0)
		_WallTexSizeAndOffset ("Wall Texture Size And Offset", Vector) = (1,1,0,0)
		_ObjectTexSizeAndOffset ("Object Texture Size And Offset", Vector) = (1,1,0,0)
		_CenterOffset ("Center Offset", Vector) = (0,0,0,0)
		_ObjectOffset ("Object Offset", Vector) = (0,0,0,0)
		_Tiles ("Tiles", Float) = 4
		_DistanceBetweenFloors ("Distance Between Floors", Float) = 0.25
		_DistanceBetweenWalls ("Distance Between Walls", Float) = 0.25
		_DistanceBetweenObject ("Distance Between Object", Float) = 0.5
		_Height ("Height", Float) = 0.5

		[KeywordEnum(TANGENT, LOCAL)] _SPACE("Space", Float) = 0
	}


	CGINCLUDE
	#include "UnityCG.cginc"
	#include "Noise.cginc"
	#pragma multi_compile _SPACE_TANGENT _SPACE_LOCAL _SPACE_WORLD
	#define INTERSECT_INF 999

	sampler2D _MainTex;
	sampler2D _HeightTex;
	float4 _FloorTexSizeAndOffset;
	float4 _CeilTexSizeAndOffset;
	float4 _WallTexSizeAndOffset;
	float4 _ObjectTexSizeAndOffset;
	float4 _CenterOffset;
	float4 _ObjectOffset;
	float _Tiles;
	float _DistanceBetweenFloors;
	float _DistanceBetweenWalls;
	float _DistanceBetweenObject;
	float _Height;


	struct v2f
	{
		float4 pos : SV_POSITION;
		float3 objectViewDir : TEXCOORD1;
		float3 objectPos : TEXCOORD2;
	};
	
	//---------------------------------------------------
	
	float3 GetRandomTiledUV(float3 uvw, float between, float tile)
	{
		float r = rand(floor((uvw + 0.00001) / between)); // 微妙に内側に入れることでZファイティングを防ぐ
		r = floor(r * 10000) % tile;
		
		uvw.xy = frac(uvw.xy / between);
		uvw.x += floor(r / (tile / 2));
		uvw.y += floor(r % (tile / 2));
		uvw.xy = uvw.xy / (tile / 2);
		uvw.z = r;
		
		return uvw;
	}
	
	//---------------------------------------------------

	float2 GetCeilUV(float3 uvw)
	{
		uvw = GetRandomTiledUV(uvw, _DistanceBetweenWalls, _Tiles);
		uvw.x = (uvw.x - 1.0) * _CeilTexSizeAndOffset.x - _CeilTexSizeAndOffset.z;
		uvw.y = (uvw.y) * _CeilTexSizeAndOffset.y - _CeilTexSizeAndOffset.w;
		return float2(-uvw.x, uvw.y);
	}

	float2 GetFloorUV(float3 uvw)
	{
		uvw = GetRandomTiledUV(uvw, _DistanceBetweenWalls, _Tiles);
		uvw.x = (uvw.x) * _FloorTexSizeAndOffset.x + _FloorTexSizeAndOffset.z;
		uvw.y = (uvw.y) * _FloorTexSizeAndOffset.y + _FloorTexSizeAndOffset.w;
		return uvw.xy;
	}

	float2 GetLeftWallUV(float3 uvw)
	{
		uvw = GetRandomTiledUV(uvw, _DistanceBetweenWalls, _Tiles);
		uvw.x = (uvw.x) * _WallTexSizeAndOffset.x + _WallTexSizeAndOffset.z;
		uvw.y = (uvw.y) * _WallTexSizeAndOffset.y + _WallTexSizeAndOffset.w;
		return uvw.xy;
	}

	float2 GetRightWallUV(float3 uvw)
	{
		uvw = GetRandomTiledUV(uvw, _DistanceBetweenWalls, _Tiles);
		uvw.x = (uvw.x - 1.0) * _WallTexSizeAndOffset.x - _WallTexSizeAndOffset.z;
		uvw.y = (uvw.y) * _WallTexSizeAndOffset.y + _WallTexSizeAndOffset.w;
		return float2(-uvw.x, uvw.y);
	}

	float2 GetFrontWallUV(float3 uvw)
	{
		uvw = GetRandomTiledUV(uvw, _DistanceBetweenWalls, _Tiles);
		uvw.x = (uvw.x) * _WallTexSizeAndOffset.x + _WallTexSizeAndOffset.z;
		uvw.y = (uvw.y) * _WallTexSizeAndOffset.y + _WallTexSizeAndOffset.w;
		return uvw.xy;
	}

	float2 GetBackWallUV(float3 uvw)
	{
		uvw = GetRandomTiledUV(uvw, _DistanceBetweenWalls, _Tiles);
		uvw.x = (uvw.x - 1.0) * _WallTexSizeAndOffset.x - _WallTexSizeAndOffset.z;
		uvw.y = (uvw.y) * _WallTexSizeAndOffset.y + _WallTexSizeAndOffset.w;
		return float2(-uvw.x, uvw.y);
	}

	//---------------------------------------------------

	float4 GetCeilColor(float3 uvw)      { return tex2D(_MainTex, GetCeilUV(uvw)); }
	float4 GetFloorColor(float3 uvw)     { return tex2D(_MainTex, GetFloorUV(uvw)); }
	float4 GetLeftWallColor(float3 uvw)  { return tex2D(_MainTex, GetLeftWallUV(uvw)); }
	float4 GetRightWallColor(float3 uvw) { return tex2D(_MainTex, GetRightWallUV(uvw)); }
	float4 GetFrontWallColor(float3 uvw) { return tex2D(_MainTex, GetFrontWallUV(uvw)); }
	float4 GetBackWallColor(float3 uvw)  { return tex2D(_MainTex, GetBackWallUV(uvw)); }

	float GetCeilHeight(float3 uvw)      { return tex2D(_HeightTex, GetCeilUV(uvw)).x; }
	float GetFloorHeight(float3 uvw)     { return tex2D(_HeightTex, GetFloorUV(uvw)).x; }
	float GetLeftWallHeight(float3 uvw)  { return tex2D(_HeightTex, GetLeftWallUV(uvw)).x; }
	float GetRightWallHeight(float3 uvw) { return tex2D(_HeightTex, GetRightWallUV(uvw)).x; }
	float GetFrontWallHeight(float3 uvw) { return tex2D(_HeightTex, GetFrontWallUV(uvw)).x; }
	float GetBackWallHeight(float3 uvw)  { return tex2D(_HeightTex, GetBackWallUV(uvw)).x; }

	//---------------------------------------------------
	
	float4 GetLeftObjectColor(float3 uvw)
	{
		uvw = GetRandomTiledUV(uvw, _DistanceBetweenWalls, _Tiles);
		uvw.x = (uvw.x) * _ObjectTexSizeAndOffset.x + _ObjectTexSizeAndOffset.z;
		uvw.y = (uvw.y) * _ObjectTexSizeAndOffset.y + _ObjectTexSizeAndOffset.w;
		return tex2D(_MainTex, uvw.xy);
	}

	float4 GetRightObjectColor(float3 uvw)
	{
		uvw = GetRandomTiledUV(uvw, _DistanceBetweenWalls, _Tiles);
		uvw.x = (uvw.x - 1.0) * _ObjectTexSizeAndOffset.x - _ObjectTexSizeAndOffset.z;
		uvw.y = (uvw.y) * _ObjectTexSizeAndOffset.y + _ObjectTexSizeAndOffset.w;
		return tex2D(_MainTex, float2(-uvw.x, uvw.y));
	}

	float4 GetFrontObjectColor(float3 uvw)
	{
		uvw = GetRandomTiledUV(uvw, _DistanceBetweenWalls, _Tiles);
		uvw.x = (uvw.x) * _ObjectTexSizeAndOffset.x + _ObjectTexSizeAndOffset.z;
		uvw.y = (uvw.y) * _ObjectTexSizeAndOffset.y + _ObjectTexSizeAndOffset.w;
		return tex2D(_MainTex, uvw.xy);
	}

	float4 GetBackObjectColor(float3 uvw)
	{
		uvw = GetRandomTiledUV(uvw, _DistanceBetweenWalls, _Tiles);
		uvw.x = (uvw.x - 1.0) * _ObjectTexSizeAndOffset.x - _ObjectTexSizeAndOffset.z;
		uvw.y = (uvw.y) * _ObjectTexSizeAndOffset.y + _ObjectTexSizeAndOffset.w;
		return tex2D(_MainTex, float2(-uvw.x, uvw.y));
	}

	//---------------------------------------------------

	// 線分と無限平面の衝突位置算出
	// http://www.scratchapixel.com/lessons/3d-basic-rendering/minimal-ray-tracer-rendering-simple-shapes/ray-plane-and-ray-disk-intersection
	// rayPos : レイの開始地点
	// rayDir : レイの向き
	// planePos : 平面の座標
	// planeNormal : 平面の法線
	float GetIntersectLength(float3 rayPos, float3 rayDir, float3 planePos, float3 planeNormal)
	{
		// 処理効率悪いので使用する側でカバー
		//if (dot(rayDir, planeNormal) <= 0)
		//	return INTERSECT_INF;

		// (p - p0)       ・n = 0
		// (L0 + L*t - p0)・n = 0
		// L*t・n + (L0 - p0)・n = 0
		// (L0 - p0)・n = - L*t・n
		// ((L0 - p0)・n) / (L・n) = -t
		// ((p0 - L0)・n) / (L・n) = t
		return dot(planePos - rayPos, planeNormal) / dot(rayDir, planeNormal);
	}

	v2f vert(appdata_tan i)
	{
		v2f o;
		o.pos = UnityObjectToClipPos(i.vertex);

#if _SPACE_LOCAL
		// カメラから頂点位置への方向を求める（オブジェクト空間）
		o.objectViewDir = -ObjSpaceViewDir(i.vertex);
		o.objectPos = i.vertex;
#else
		float3 normal = i.normal;
		float3 tangent = i.tangent;
		float3 binormal = cross(i.normal, i.tangent) * i.tangent.w * unity_WorldTransformParams.w;
		float3x3 localToTangentMatrix = float3x3(i.tangent.xyz, binormal, i.normal);

		o.objectViewDir = mul(localToTangentMatrix, -ObjSpaceViewDir(i.vertex));
		o.objectPos = i.texcoord * 1.0 - 0.5;
#endif

		return o;
	}

	half4 frag(v2f i) : SV_TARGET
	{
		float3 rayDir = normalize(i.objectViewDir);
		float3 rayPos = i.objectPos + rayDir * 0.0001; // 微妙に内側に入れることでZファイティングを防ぐ

		float3 planePos = float3(0, 0, 0);
		float3 planeNormal = float3(0, 0, 0);
		float intersect = INTERSECT_INF;
		float3 color = float3(1,1,1);

		const float3 UpVec = float3(0, 1, 0);
		const float3 RightVec = float3(1, 0, 0);
		const float3 FrontVec = float3(0, 0, 1);

		rayPos += _CenterOffset;

		// 床と天井
		{
			float which = step(0.0, dot(rayDir, UpVec));
			planeNormal = float3(0, lerp(1, -1, which), 0);
			planePos.xz = 0.0;
			planePos.y = ceil(rayPos.y / _DistanceBetweenFloors);
			planePos.y -= lerp(1.0, 0.0, which);
			planePos.y *= _DistanceBetweenFloors;

			float i = GetIntersectLength(rayPos, rayDir, planePos, planeNormal);
			if (i < intersect)
			{
				intersect = i;

				float3 pos = rayPos + rayDir * i + 0.5;
				float3 uvw = pos.xzy;
				float height = lerp(GetFloorHeight(uvw), GetCeilHeight(uvw), which);
				uvw.xy = uvw.xy + -rayDir.xz * height * _Height;
				color = lerp(GetFloorColor(uvw), GetCeilColor(uvw), which);
			}
		}

		// 左右の壁
		{
			float which = step(0.0, dot(rayDir, RightVec));
			planeNormal = float3(lerp(1, -1, which), 0, 0);
			planePos.yz = 0.0;
			planePos.x = ceil(rayPos.x / _DistanceBetweenWalls);
			planePos.x -= lerp(1.0, 0.0, which);
			planePos.x *= _DistanceBetweenWalls;

			float i = GetIntersectLength(rayPos, rayDir, planePos, planeNormal);
			if (i < intersect)
			{
				intersect = i;

				float3 pos = rayPos + rayDir * i + 0.5;
				float3 uvw = pos.zyx;
				color = lerp(GetLeftWallColor(uvw), GetRightWallColor(uvw), which);
			}
		}

		// 奥の壁
		{
			float which = step(0.0, dot(rayDir, FrontVec));
			planeNormal = float3(0, 0, lerp(1, -1, which));
			planePos.xy = 0.0;
			planePos.z = ceil(rayPos.z / _DistanceBetweenWalls);
			planePos.z -= lerp(1.0, 0.0, which);
			planePos.z *= _DistanceBetweenWalls;

			float i = GetIntersectLength(rayPos, rayDir, planePos, planeNormal);
			if (i < intersect)
			{
				intersect = i;

				float3 pos = rayPos + rayDir * i + 0.5;
				float3 uvw = pos.xyz;
				color = lerp(GetBackWallColor(uvw), GetFrontWallColor(uvw), which);
			}
		}

		rayPos -= _CenterOffset;
		rayPos += _ObjectOffset;

		/*
		// 左右のオブジェクト(人/観葉植物等)
		{
			float which = step(0.0, dot(rayDir, RightVec));
			planeNormal = float3(lerp(1, -1, which), 0, 0);
			planePos.yz = 0.0;
			planePos.x = ceil(rayPos.x / _DistanceBetweenObject);
			planePos.x -= lerp(1.0, 0.0, which);
			planePos.x *= _DistanceBetweenObject;

			float i = GetIntersectLength(rayPos, rayDir, planePos, planeNormal);
			if (i < intersect)
			{
				float3 pos = rayPos + rayDir * i + 0.5;
				float3 uvw = pos.zyx;
				float4 c = lerp(GetLeftObjectColor(uvw), GetRightObjectColor(uvw), which);
				
				if(0.5 < c.a)
				{
					intersect = i;
					color = c;
				}
			}
		}*/

		// 奥のオブジェクト(人/観葉植物等)
		{
			float which = step(0.0, dot(rayDir, FrontVec));
			planeNormal = float3(0, 0, lerp(1, -1, which));
			planePos.xy = 0.0;
			planePos.z = ceil(rayPos.z / _DistanceBetweenObject);
			planePos.z -= lerp(1.0, 0.0, which);
			planePos.z *= _DistanceBetweenObject;

			float i = GetIntersectLength(rayPos, rayDir, planePos, planeNormal);
			if (i < intersect)
			{

				float3 pos = rayPos + rayDir * i + 0.5;
				float3 uvw = pos.xyz;
				float4 c = lerp(GetBackObjectColor(uvw), GetFrontObjectColor(uvw), which);
				
				if(0.5 < c.a)
				{
					intersect = i;
					color = c;
				}
			}
		}

		return half4(color, 1);// * intersect;
	}
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
			#pragma target 2.0
			#pragma vertex vert
			#pragma fragment frag
			ENDCG
		}
	}
}

