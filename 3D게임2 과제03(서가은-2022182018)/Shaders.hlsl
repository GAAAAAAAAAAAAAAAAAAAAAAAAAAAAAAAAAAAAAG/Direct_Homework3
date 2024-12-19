struct MATERIAL
{
	float4					m_cAmbient;
	float4					m_cDiffuse;
	float4					m_cSpecular; //a = power
	float4					m_cEmissive;
};

cbuffer cbCameraInfo : register(b1)
{
	matrix		gmtxView : packoffset(c0);
	matrix		gmtxProjection : packoffset(c4);
    matrix      gmtxInverseView : packoffset(c8);
	float3		gvCameraPosition : packoffset(c12);
};

cbuffer cbGameObjectInfo : register(b2)
{
	matrix		gmtxGameObject : packoffset(c0);
	MATERIAL	gMaterial : packoffset(c4);
	uint		gnTexturesMask : packoffset(c8);
};

// 추가-----
cbuffer cbFrameworkInfo : register(b3)
{
    float gfCurrentTime : packoffset(c0.x);
    float gfElapsedTime : packoffset(c0.y);
    float gfWheel : packoffset(c0.z);
    float gfNowTime : packoffset(c0.w);

    float3 gf3Gravity : packoffset(c1.x);
    float gfSecondsPerFirework : packoffset(c1.w);
    int gnFlareParticlesToEmit : packoffset(c2.x);
    int gnMaxFlareType2Particles : packoffset(c2.y);
    
    //추가3
    uint gnRenderMode : packoffset(c2.z);
};
//----------

TextureCube gtxtSkyCubeTexture : register(t13);
SamplerState gssClamp : register(s1);

//추가3
#define DYNAMIC_TESSELLATION		0x10
#define DEBUG_TESSELLATION			0x20

#include "Light.hlsl"

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//
//#define _WITH_VERTEX_LIGHTING

#define MATERIAL_ALBEDO_MAP			0x01
#define MATERIAL_SPECULAR_MAP		0x02
#define MATERIAL_NORMAL_MAP			0x04
#define MATERIAL_METALLIC_MAP		0x08
#define MATERIAL_EMISSION_MAP		0x10
#define MATERIAL_DETAIL_ALBEDO_MAP	0x20
#define MATERIAL_DETAIL_NORMAL_MAP	0x40

//#define _WITH_STANDARD_TEXTURE_MULTIPLE_PARAMETERS

#ifdef _WITH_STANDARD_TEXTURE_MULTIPLE_PARAMETERS
Texture2D gtxtAlbedoTexture : register(t6);
Texture2D gtxtSpecularTexture : register(t7);
Texture2D gtxtNormalTexture : register(t8);
Texture2D gtxtMetallicTexture : register(t9);
Texture2D gtxtEmissionTexture : register(t10);
Texture2D gtxtDetailAlbedoTexture : register(t11);
Texture2D gtxtDetailNormalTexture : register(t12);
#else
Texture2D gtxtStandardTextures[7] : register(t6);
#endif

SamplerState gssWrap : register(s0);

struct VS_STANDARD_INPUT
{
	float3 position : POSITION;
	float2 uv : TEXCOORD;
	float3 normal : NORMAL;
	float3 tangent : TANGENT;
	float3 bitangent : BITANGENT;
};

struct VS_STANDARD_OUTPUT
{
	float4 position : SV_POSITION;
	float3 positionW : POSITION;
	float3 normalW : NORMAL;
	float3 tangentW : TANGENT;
	float3 bitangentW : BITANGENT;
	float2 uv : TEXCOORD;
};

VS_STANDARD_OUTPUT VSStandard(VS_STANDARD_INPUT input)
{
	VS_STANDARD_OUTPUT output;

	output.positionW = (float3)mul(float4(input.position, 1.0f), gmtxGameObject);
	output.normalW = mul(input.normal, (float3x3)gmtxGameObject);
	output.tangentW = (float3)mul(float4(input.tangent, 1.0f), gmtxGameObject);
	output.bitangentW = (float3)mul(float4(input.bitangent, 1.0f), gmtxGameObject);
	output.position = mul(mul(float4(output.positionW, 1.0f), gmtxView), gmtxProjection);
	output.uv = input.uv;

	return(output);
}

float4 PSStandard(VS_STANDARD_OUTPUT input) : SV_TARGET
{
	float4 cAlbedoColor = float4(0.0f, 0.0f, 0.0f, 1.0f);
	float4 cSpecularColor = float4(0.0f, 0.0f, 0.0f, 1.0f);
	float4 cNormalColor = float4(0.0f, 0.0f, 0.0f, 1.0f);
	float4 cMetallicColor = float4(0.0f, 0.0f, 0.0f, 1.0f);
	float4 cEmissionColor = float4(0.0f, 0.0f, 0.0f, 1.0f);

#ifdef _WITH_STANDARD_TEXTURE_MULTIPLE_PARAMETERS
	if (gnTexturesMask & MATERIAL_ALBEDO_MAP) cAlbedoColor = gtxtAlbedoTexture.Sample(gssWrap, input.uv);
	if (gnTexturesMask & MATERIAL_SPECULAR_MAP) cSpecularColor = gtxtSpecularTexture.Sample(gssWrap, input.uv);
	if (gnTexturesMask & MATERIAL_NORMAL_MAP) cNormalColor = gtxtNormalTexture.Sample(gssWrap, input.uv);
	if (gnTexturesMask & MATERIAL_METALLIC_MAP) cMetallicColor = gtxtMetallicTexture.Sample(gssWrap, input.uv);
	if (gnTexturesMask & MATERIAL_EMISSION_MAP) cEmissionColor = gtxtEmissionTexture.Sample(gssWrap, input.uv);
#else
	if (gnTexturesMask & MATERIAL_ALBEDO_MAP) cAlbedoColor = gtxtStandardTextures[0].Sample(gssWrap, input.uv);
	if (gnTexturesMask & MATERIAL_SPECULAR_MAP) cSpecularColor = gtxtStandardTextures[1].Sample(gssWrap, input.uv);
	if (gnTexturesMask & MATERIAL_NORMAL_MAP) cNormalColor = gtxtStandardTextures[2].Sample(gssWrap, input.uv);
	if (gnTexturesMask & MATERIAL_METALLIC_MAP) cMetallicColor = gtxtStandardTextures[3].Sample(gssWrap, input.uv);
	if (gnTexturesMask & MATERIAL_EMISSION_MAP) cEmissionColor = gtxtStandardTextures[4].Sample(gssWrap, input.uv);
#endif

	float4 cIllumination = float4(1.0f, 1.0f, 1.0f, 1.0f);
	float4 cColor = cAlbedoColor + cSpecularColor + cEmissionColor;
	if (gnTexturesMask & MATERIAL_NORMAL_MAP)
	{
		float3 normalW = input.normalW;
		float3x3 TBN = float3x3(normalize(input.tangentW), normalize(input.bitangentW), normalize(input.normalW));
		float3 vNormal = normalize(cNormalColor.rgb * 2.0f - 1.0f); //[0, 1] → [-1, 1]
		normalW = normalize(mul(vNormal, TBN));
		cIllumination = Lighting(input.positionW, normalW);
		cColor = lerp(cColor, cIllumination, 0.5f);
	}

    // 추가3
    float3 toEyeW = normalize(gvCameraPosition - input.positionW);
    float3 r = reflect(-toEyeW, input.normalW);
    float4 reflectionColor = gtxtSkyCubeTexture.Sample(gssWrap, r);

    return (cColor + reflectionColor * 1.0f);
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//
struct VS_SKYBOX_CUBEMAP_INPUT
{
	float3 position : POSITION;
};

struct VS_SKYBOX_CUBEMAP_OUTPUT
{
	float3	positionL : POSITION;
	float4	position : SV_POSITION;
};

VS_SKYBOX_CUBEMAP_OUTPUT VSSkyBox(VS_SKYBOX_CUBEMAP_INPUT input)
{
	VS_SKYBOX_CUBEMAP_OUTPUT output;

	output.position = mul(mul(mul(float4(input.position, 1.0f), gmtxGameObject), gmtxView), gmtxProjection);
	output.positionL = input.position;

	return(output);
}

float4 PSSkyBox(VS_SKYBOX_CUBEMAP_OUTPUT input) : SV_TARGET
{
	float4 cColor = gtxtSkyCubeTexture.Sample(gssClamp, input.positionL);

	return(cColor);
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//
struct VS_SPRITE_TEXTURED_INPUT
{
	float3 position : POSITION;
	float2 uv : TEXCOORD;
};

struct VS_SPRITE_TEXTURED_OUTPUT
{
	float4 position : SV_POSITION;
	float2 uv : TEXCOORD;
};

VS_SPRITE_TEXTURED_OUTPUT VSTextured(VS_SPRITE_TEXTURED_INPUT input)
{
	VS_SPRITE_TEXTURED_OUTPUT output;

	output.position = mul(mul(mul(float4(input.position, 1.0f), gmtxGameObject), gmtxView), gmtxProjection);
	output.uv = input.uv;

	return(output);
}

/*
float4 PSTextured(VS_SPRITE_TEXTURED_OUTPUT input, uint nPrimitiveID : SV_PrimitiveID) : SV_TARGET
{
	float4 cColor;
	if (nPrimitiveID < 2)
		cColor = gtxtTextures[0].Sample(gWrapSamplerState, input.uv);
	else if (nPrimitiveID < 4)
		cColor = gtxtTextures[1].Sample(gWrapSamplerState, input.uv);
	else if (nPrimitiveID < 6)
		cColor = gtxtTextures[2].Sample(gWrapSamplerState, input.uv);
	else if (nPrimitiveID < 8)
		cColor = gtxtTextures[3].Sample(gWrapSamplerState, input.uv);
	else if (nPrimitiveID < 10)
		cColor = gtxtTextures[4].Sample(gWrapSamplerState, input.uv);
	else
		cColor = gtxtTextures[5].Sample(gWrapSamplerState, input.uv);
	float4 cColor = gtxtTextures[NonUniformResourceIndex(nPrimitiveID/2)].Sample(gWrapSamplerState, input.uv);

	return(cColor);
}
*/

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// 추가

//Texture2D gtxtTexture : register(t0);

//SamplerState gWrapSamplerState : register(s0);
//SamplerState gClampSamplerState : register(s1);

//Texture2D<float4> gtxtTerrainBaseTexture : register(t4);
//Texture2D<float4> gtxtTerrainDetailTexture : register(t5);
//Texture2D<float> gtxtTerrainAlphaTexture : register(t6);

Texture2D gtxtTerrainTexture : register(t14);
Texture2D gtxtDetailTexture : register(t15);
Texture2D gtxtAlphaTexture : register(t16);

struct VS_TERRAIN_INPUT
{
    float3 position : POSITION;
    float4 color : COLOR;
    float2 uv0 : TEXCOORD0;
    float2 uv1 : TEXCOORD1;
};

struct VS_TERRAIN_OUTPUT
{
    float4 position : SV_POSITION;
    float4 color : COLOR;
    float2 uv0 : TEXCOORD0;
    float2 uv1 : TEXCOORD1;
};

VS_TERRAIN_OUTPUT VSTerrain(VS_TERRAIN_INPUT input)
{
    VS_TERRAIN_OUTPUT output;

#ifdef _WITH_CONSTANT_BUFFER_SYNTAX
	output.position = mul(mul(mul(float4(input.position, 1.0f), gcbGameObjectInfo.mtxWorld), gcbCameraInfo.mtxView), gcbCameraInfo.mtxProjection);
#else
    output.position = mul(mul(mul(float4(input.position, 1.0f), gmtxGameObject), gmtxView), gmtxProjection);
#endif
    output.color = input.color;
    output.uv0 = input.uv0;
    output.uv1 = input.uv1;
    return (output);
}

float4 PSTerrain(VS_TERRAIN_OUTPUT input) : SV_TARGET
{
    float4 cBaseTexColor = gtxtTerrainTexture.Sample(gssWrap, input.uv0);
    float4 cDetailTexColor = gtxtDetailTexture.Sample(gssWrap, input.uv1);
    float fAlpha = gtxtAlphaTexture.Sample(gssWrap, input.uv0);

//	float4 cColor = input.color * saturate((cBaseTexColor * 0.5f) + (cDetailTexColor * 0.5f));
    float4 cColor = saturate(lerp(cBaseTexColor, cDetailTexColor, fAlpha));
 
    return (cColor);
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// 추가
#define _WITH_BILLBOARD_ANIMATION

Texture2D gtxtBillboardTexture : register(t17);

struct VS_TEXTURED_INPUT
{
    float3 position : POSITION;
    float2 uv : TEXCOORD;
};

struct VS_TEXTURED_OUTPUT
{
    float4 position : SV_POSITION;
    float2 uv : TEXCOORD;
};

VS_TEXTURED_OUTPUT VSBillboard(VS_TEXTURED_INPUT input)
{
    VS_TEXTURED_OUTPUT output;

#ifdef _WITH_CONSTANT_BUFFER_SYNTAX
	output.position = mul(mul(mul(float4(input.position, 1.0f), gcbGameObjectInfo.mtxWorld), gcbCameraInfo.mtxView), gcbCameraInfo.mtxProjection);
#else
    output.position = mul(mul(mul(float4(input.position, 1.0f), gmtxGameObject), gmtxView), gmtxProjection);
#endif

#ifdef _WITH_BILLBOARD_ANIMATION
    if (input.uv.y < 0.7f)
    {
        float fShift = 0.0f;
        int nResidual = ((int) 3 * gfCurrentTime % 4);
        if (nResidual == 1)
            fShift = -0.06f;
        if (nResidual == 3)
            fShift = +0.06f;
        input.uv.x += fShift;
    }
#endif
    output.uv = input.uv;

    return (output);
}

float4 PSBillboard(VS_TEXTURED_OUTPUT input) : SV_TARGET
{
    float4 cColor = gtxtBillboardTexture.SampleLevel(gssWrap, input.uv, 0);
//	float4 cColor = gtxtTexture.Sample(gWrapSamplerState, input.uv);
    if (cColor.a <= 0.3f)
        discard; //clip(cColor.a - 0.3f);

    return (cColor);
}

//////////////////////////////거울

float4 PSMirror(VS_TEXTURED_OUTPUT input) : SV_TARGET
{
    float4 cColor = (0.3f, 0.5f, 0.3f, 0.55f);
    return (cColor);
}

//추가---------------------------------------------------
Texture2D gtxtTexture : register(t18);
SamplerState gSamplerState : register(s2);

struct VS_TEXTURED_INPUT2
{
    float3 position : POSITION;
    float2 uv : TEXCOORD;
};

struct VS_TEXTURED_OUTPUT2
{
    float4 position : SV_POSITION;
    float2 uv : TEXCOORD;
};

VS_TEXTURED_OUTPUT2 VSTextureToScreen(VS_TEXTURED_INPUT2 input)
{
    VS_TEXTURED_OUTPUT2 output;

    output.position = float4(input.position, 1.0f);
    output.uv = input.uv;

    return (output);
}

float4 PSTextureToScreen(VS_TEXTURED_OUTPUT2 input) : SV_TARGET
{
    float4 cColor = gtxtTexture.Sample(gssWrap, input.uv);

//    if ((cColor.r > 0.85f) && (cColor.g > 0.85f) && (cColor.b > 0.85f)) discard;
	
    return (cColor);
}

//추가---------------------------------------------------
VS_TEXTURED_OUTPUT VSScrollTexture(VS_TEXTURED_INPUT input)
{
    VS_TEXTURED_OUTPUT output;

    output.position = float4(input.position, 1.0f);
    output.uv.x = input.uv.x;
    output.uv.y = input.uv.y * 0.5 + gfWheel;

    return (output);
}

float4 PSScrollTexture(VS_TEXTURED_OUTPUT input) : SV_TARGET
{
    float4 cColor = gtxtTexture.Sample(gssWrap, input.uv);

    return (cColor);
}

//추가---------------------------------------------------

VS_TEXTURED_OUTPUT VSSpriteTexture(VS_TEXTURED_INPUT input)
{
    VS_TEXTURED_OUTPUT output;


    output.position = mul(mul(mul(float4(input.position, 1.0f), gmtxGameObject), gmtxView), gmtxProjection);
    output.uv = input.uv;

    return (output);
}

float4 PSSpriteTexture(VS_TEXTURED_OUTPUT input) : SV_TARGET
{
     // 애니메이션에 사용할 텍스처의 가로 프레임 수와 세로 프레임 수
    int frameWidth = 8; // 예: 텍스처가 4개의 가로 프레임으로 나뉘어 있을 때
    int frameHeight = 8; // 예: 텍스처가 4개의 세로 프레임으로 나뉘어 있을 때

    // 현재 프레임 번호 (예: 외부에서 전달받아 시간에 따라 변경)
    float currentFrame = floor(gfNowTime * 8) % (frameWidth * frameHeight);
    int frameX = int(currentFrame) % frameWidth;
    int frameY = int(currentFrame) / frameWidth;

    // uv 좌표를 조정하여 현재 프레임의 텍스처 영역으로 이동
    float2 frameSize = float2(1.0 / frameWidth, 1.0 / frameHeight);
    float2 frameOffset = float2(frameX * frameSize.x, frameY * frameSize.y);

    float2 animatedUV = frameOffset + input.uv * frameSize;

    //텍스처 샘플링
    float4 cColor = gtxtTexture.Sample(gssWrap, animatedUV);
	
    if (cColor.a < 0.85)
        discard;

    return (cColor);
}

//추가---------------------------------------------------
//추가---------------------------------------------------
VS_TEXTURED_OUTPUT VSRiverTexture(VS_TEXTURED_INPUT input)
{
    VS_TEXTURED_OUTPUT output;

    output.position = mul(mul(mul(float4(input.position, 1.0f), gmtxGameObject), gmtxView), gmtxProjection);
    output.uv = input.uv;
    output.uv.y += gfCurrentTime * 0.00125f;

    return (output);
}

float4 PSRiverTexture(VS_TEXTURED_OUTPUT input) : SV_TARGET
{
    float2 uv = input.uv;
	
    float4 BaseTextureColor = gtxtTerrainTexture.SampleLevel(gssWrap, uv * 20, 0);
    float4 DetailTextureColor = gtxtDetailTexture.SampleLevel(gssWrap, uv * 20, 0);
    float4 Detail2TextureColor = gtxtAlphaTexture.SampleLevel(gssWrap, uv * 100, 0);

    float4 color = lerp(BaseTextureColor * DetailTextureColor, Detail2TextureColor.r * 0.5f, 0.35f);
	
    color.a = 0.71f;
	
    return (color);

}
//////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////
/////////////////////////////////////
// 추가2--------------------------------------------------------
///////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////
/////////////////////////////////////////////////////////////
Texture2D<float4> gtxtParticleTexture : register(t19);
Buffer<float4> gRandomBuffer : register(t20);
Buffer<float4> gRandomSphereBuffer : register(t21);

#define PARTICLE_TYPE_EMITTER		0
#define PARTICLE_TYPE_SHELL			1
#define PARTICLE_TYPE_FLARE01		2
#define PARTICLE_TYPE_FLARE02		3
#define PARTICLE_TYPE_FLARE03		4

#define SHELL_PARTICLE_LIFETIME		3.0f
#define FLARE01_PARTICLE_LIFETIME	2.5f
#define FLARE02_PARTICLE_LIFETIME	1.5f
#define FLARE03_PARTICLE_LIFETIME	2.0f

struct VS_PARTICLE_INPUT
{
    float3 position : POSITION;
    float3 velocity : VELOCITY;
    float lifetime : LIFETIME;
//	float age : AGE;
    uint type : PARTICLETYPE;
};

VS_PARTICLE_INPUT VSParticleStreamOutput(VS_PARTICLE_INPUT input)
{
    return (input);
}

float3 GetParticleColor(float fAge, float fLifetime)
{
    float3 cColor = float3(1.0f, 1.0f, 1.0f);

    if (fAge == 0.0f)
        cColor = float3(0.0f, 1.0f, 0.0f);
    else if (fLifetime == 0.0f) 
        cColor = float3(1.0f, 1.0f, 0.0f);
    else
    {
        float t = fAge / fLifetime;
        cColor = lerp(float3(1.0f, 0.0f, 0.0f), float3(0.0f, 0.0f, 1.0f), t * 1.0f);
    }

    return (cColor);
}

void GetBillboardCorners(float3 position, float2 size, out float4 pf4Positions[4])
{
    float3 f3Up = float3(0.0f, 1.0f, 0.0f);
    float3 f3Look = normalize(gvCameraPosition - position);
    float3 f3Right = normalize(cross(f3Up, f3Look));

    pf4Positions[0] = float4(position + size.x * f3Right - size.y * f3Up, 1.0f);
    pf4Positions[1] = float4(position + size.x * f3Right + size.y * f3Up, 1.0f);
    pf4Positions[2] = float4(position - size.x * f3Right - size.y * f3Up, 1.0f);
    pf4Positions[3] = float4(position - size.x * f3Right + size.y * f3Up, 1.0f);
}

void GetPositions(float3 position, float2 f2Size, out float3 pf3Positions[8])
{
    float3 f3Right = float3(1.0f, 0.0f, 0.0f);
    float3 f3Up = float3(0.0f, 1.0f, 0.0f);
    float3 f3Look = float3(0.0f, 0.0f, 1.0f);

    float3 f3Extent = normalize(float3(1.0f, 1.0f, 1.0f));

    pf3Positions[0] = position + float3(-f2Size.x, 0.0f, -f2Size.y);
    pf3Positions[1] = position + float3(-f2Size.x, 0.0f, +f2Size.y);
    pf3Positions[2] = position + float3(+f2Size.x, 0.0f, -f2Size.y);
    pf3Positions[3] = position + float3(+f2Size.x, 0.0f, +f2Size.y);
    pf3Positions[4] = position + float3(-f2Size.x, 0.0f, 0.0f);
    pf3Positions[5] = position + float3(+f2Size.x, 0.0f, 0.0f);
    pf3Positions[6] = position + float3(0.0f, 0.0f, +f2Size.y);
    pf3Positions[7] = position + float3(0.0f, 0.0f, -f2Size.y);
}

float4 RandomDirection(float fOffset)
{
    int u = uint(gfCurrentTime + fOffset + frac(gfCurrentTime) * 1000.0f) % 1024;
    return (normalize(gRandomBuffer.Load(u)));
}

float4 RandomDirectionOnSphere(float fOffset)
{
    int u = uint(gfCurrentTime + fOffset + frac(gfCurrentTime) * 1000.0f) % 256;
    return (normalize(gRandomSphereBuffer.Load(u)));
}

void OutputParticleToStream(VS_PARTICLE_INPUT input, inout PointStream<VS_PARTICLE_INPUT> output)
{
    input.position += input.velocity * gfElapsedTime;
    input.velocity += gf3Gravity * gfElapsedTime;
    input.lifetime -= gfElapsedTime;

    output.Append(input);
}

void EmmitParticles(VS_PARTICLE_INPUT input, inout PointStream<VS_PARTICLE_INPUT> output)
{
    float4 f4Random = RandomDirection(input.type);
    if (input.lifetime <= 0.0f)
    {
        VS_PARTICLE_INPUT particle = input;

        particle.type = PARTICLE_TYPE_SHELL;
        particle.position = input.position + (input.velocity * gfElapsedTime * f4Random.xyz);
        particle.velocity = input.velocity + (f4Random.xyz * 16.0f);
        particle.lifetime = SHELL_PARTICLE_LIFETIME + (f4Random.y * 0.5f);

        output.Append(particle);

        input.lifetime = gfSecondsPerFirework * 0.2f + (f4Random.x * 0.4f);
    }
    else
    {
        input.lifetime -= gfElapsedTime;
    }

    output.Append(input);
}

void ShellParticles(VS_PARTICLE_INPUT input, inout PointStream<VS_PARTICLE_INPUT> output)
{
    if (input.lifetime <= 0.0f)
    {
        VS_PARTICLE_INPUT particle = input;
        float4 f4Random = float4(0.0f, 0.0f, 0.0f, 0.0f);

        particle.type = PARTICLE_TYPE_FLARE01;
        particle.position = input.position + (input.velocity * gfElapsedTime * 2.0f);
        particle.lifetime = FLARE01_PARTICLE_LIFETIME;

        for (int i = 0; i < gnFlareParticlesToEmit; i++)
        {
            f4Random = RandomDirection(input.type + i);
            particle.velocity = input.velocity + (f4Random.xyz * 18.0f);

            output.Append(particle);
        }

        particle.type = PARTICLE_TYPE_FLARE02;
        particle.position = input.position + (input.velocity * gfElapsedTime);
        for (int j = 0; j < abs(f4Random.x) * gnMaxFlareType2Particles; j++)
        {
            f4Random = RandomDirection(input.type + j);
            particle.velocity = input.velocity + (f4Random.xyz * 10.0f);
            particle.lifetime = FLARE02_PARTICLE_LIFETIME + (f4Random.x * 0.4f);

            output.Append(particle);
        }
    }
    else
    {
        OutputParticleToStream(input, output);
    }
}

void OutputEmberParticles(VS_PARTICLE_INPUT input, inout PointStream<VS_PARTICLE_INPUT> output)
{
    if (input.lifetime > 0.0f)
    {
        OutputParticleToStream(input, output);
    }
}

void GenerateEmberParticles(VS_PARTICLE_INPUT input, inout PointStream<VS_PARTICLE_INPUT> output)
{
    if (input.lifetime <= 0.0f)
    {
        VS_PARTICLE_INPUT particle = input;

        particle.type = PARTICLE_TYPE_FLARE03;
        particle.position = input.position + (input.velocity * gfElapsedTime);
        particle.lifetime = FLARE03_PARTICLE_LIFETIME;
        for (int i = 0; i < 128; i++)
        {
            float4 f4Random = RandomDirectionOnSphere(input.type + i);
            particle.velocity = input.velocity + (f4Random.xyz * 25.0f);

            output.Append(particle);
        }
    }
    else
    {
        OutputParticleToStream(input, output);
    }
}

[maxvertexcount(128)]
void GSParticleStreamOutput(point VS_PARTICLE_INPUT input[1], inout PointStream<VS_PARTICLE_INPUT> output)
{
    VS_PARTICLE_INPUT particle = input[0];

    if (particle.type == PARTICLE_TYPE_EMITTER)
        EmmitParticles(particle, output);
    else if (particle.type == PARTICLE_TYPE_SHELL)
        ShellParticles(particle, output);
    else if ((particle.type == PARTICLE_TYPE_FLARE01) || (particle.type == PARTICLE_TYPE_FLARE03))
        OutputEmberParticles(particle, output);
    else if (particle.type == PARTICLE_TYPE_FLARE02)
        GenerateEmberParticles(particle, output);
}

/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//
struct VS_PARTICLE_DRAW_OUTPUT
{
    float3 position : POSITION;
    float4 color : COLOR;
    float size : SCALE;
    uint type : PARTICLETYPE;
};

struct GS_PARTICLE_DRAW_OUTPUT
{
    float4 position : SV_Position;
    float4 color : COLOR;
    float2 uv : TEXTURE;
    uint type : PARTICLETYPE;
};

VS_PARTICLE_DRAW_OUTPUT VSParticleDraw(VS_PARTICLE_INPUT input)
{
    VS_PARTICLE_DRAW_OUTPUT output = (VS_PARTICLE_DRAW_OUTPUT) 0;

    output.position = input.position;
    output.size = 2.5f;
    output.type = input.type;

    if (input.type == PARTICLE_TYPE_EMITTER)
    {
        output.color = float4(1.0f, 0.1f, 0.1f, 1.0f);
        output.size = 3.0f;
    }
    else if (input.type == PARTICLE_TYPE_SHELL)
    {
        output.color = float4(0.1f, 0.0f, 1.0f, 1.0f);
        output.size = 3.0f;
    }
    else if (input.type == PARTICLE_TYPE_FLARE01)
    {
        output.color = float4(1.0f, 1.0f, 0.1f, 1.0f);
        output.color *= (input.lifetime / FLARE01_PARTICLE_LIFETIME);
    }
    else if (input.type == PARTICLE_TYPE_FLARE02)
        output.color = float4(1.0f, 0.1f, 1.0f, 1.0f);
    else if (input.type == PARTICLE_TYPE_FLARE03)
    {
        output.color = float4(1.0f, 0.1f, 1.0f, 1.0f);
        output.color *= (input.lifetime / FLARE03_PARTICLE_LIFETIME);
    }
	
    return (output);
}

static float3 gf3Positions[4] = { float3(-1.0f, +1.0f, 0.5f), float3(+1.0f, +1.0f, 0.5f), float3(-1.0f, -1.0f, 0.5f), float3(+1.0f, -1.0f, 0.5f) };
static float2 gf2QuadUVs[4] = { float2(0.0f, 0.0f), float2(1.0f, 0.0f), float2(0.0f, 1.0f), float2(1.0f, 1.0f) };

[maxvertexcount(4)]
void GSParticleDraw(point VS_PARTICLE_DRAW_OUTPUT input[1], inout TriangleStream<GS_PARTICLE_DRAW_OUTPUT> outputStream)
{
    GS_PARTICLE_DRAW_OUTPUT output = (GS_PARTICLE_DRAW_OUTPUT) 0;

    output.type = input[0].type;
    output.color = input[0].color;
    for (int i = 0; i < 4; i++)
    {
        float3 positionW = mul(gf3Positions[i] * input[0].size, (float3x3) gmtxInverseView) + input[0].position;
        output.position = mul(mul(float4(positionW, 1.0f), gmtxView), gmtxProjection);
        output.uv = gf2QuadUVs[i];

        outputStream.Append(output);
    }
}

float4 PSParticleDraw(GS_PARTICLE_DRAW_OUTPUT input) : SV_TARGET
{
    float4 cColor = gtxtParticleTexture.Sample(gssWrap, input.uv);
    cColor *= input.color;

    return (cColor);
}

///////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////
//추가3 - 지형 테셀레이션
struct VS_TERRAIN_TESSELLATION_OUTPUT
{
    float3 position : POSITION;
    float3 positionW : POSITION1;
    float4 color : COLOR;
    float2 uv0 : TEXCOORD0;
    float2 uv1 : TEXCOORD1;
};

VS_TERRAIN_TESSELLATION_OUTPUT VSTerrainTessellation(VS_TERRAIN_INPUT input)
{
    VS_TERRAIN_TESSELLATION_OUTPUT output;

    output.position = input.position;
    output.positionW = mul(float4(input.position, 1.0f), gmtxGameObject).xyz;
    output.color = input.color;
    output.uv0 = input.uv0;
    output.uv1 = input.uv1;

    return (output);
}

struct HS_TERRAIN_TESSELLATION_CONSTANT
{
    float fTessEdges[4] : SV_TessFactor;
    float fTessInsides[2] : SV_InsideTessFactor;
};

struct HS_TERRAIN_TESSELLATION_OUTPUT
{
    float3 position : POSITION;
    float4 color : COLOR;
    float2 uv0 : TEXCOORD0;
    float2 uv1 : TEXCOORD1;
};

struct DS_TERRAIN_TESSELLATION_OUTPUT
{
    float4 position : SV_POSITION;
    float4 color : COLOR;
    float2 uv0 : TEXCOORD0;
    float2 uv1 : TEXCOORD1;
    float4 tessellation : TEXCOORD2;
};

[domain("quad")]
//[partitioning("fractional_even")]
[partitioning("integer")]
[outputtopology("triangle_cw")]
[outputcontrolpoints(25)]
[patchconstantfunc("HSTerrainTessellationConstant")]
[maxtessfactor(64.0f)]
HS_TERRAIN_TESSELLATION_OUTPUT HSTerrainTessellation(InputPatch<VS_TERRAIN_TESSELLATION_OUTPUT, 25> input, uint i : SV_OutputControlPointID)
{
    HS_TERRAIN_TESSELLATION_OUTPUT output;

    output.position = input[i].position;
    output.color = input[i].color;
    output.uv0 = input[i].uv0;
    output.uv1 = input[i].uv1;

    return (output);
}

float CalculateTessFactor(float3 f3Position)
{
    float fDistToCamera = distance(f3Position, gvCameraPosition);
    float s = saturate((fDistToCamera - 10.0f) / (500.0f - 10.0f));

    return (lerp(64.0f, 1.0f, s));
	//	return(pow(2, lerp(20.0f, 4.0f, s)));
}

HS_TERRAIN_TESSELLATION_CONSTANT HSTerrainTessellationConstant(InputPatch<VS_TERRAIN_TESSELLATION_OUTPUT, 25> input)
{
    HS_TERRAIN_TESSELLATION_CONSTANT output;

    if (gnRenderMode & DYNAMIC_TESSELLATION)
    {
        float3 e0 = 0.5f * (input[0].positionW + input[4].positionW);
        float3 e1 = 0.5f * (input[0].positionW + input[20].positionW);
        float3 e2 = 0.5f * (input[4].positionW + input[24].positionW);
        float3 e3 = 0.5f * (input[20].positionW + input[24].positionW);

        output.fTessEdges[0] = CalculateTessFactor(e0);
        output.fTessEdges[1] = CalculateTessFactor(e1);
        output.fTessEdges[2] = CalculateTessFactor(e2);
        output.fTessEdges[3] = CalculateTessFactor(e3);

        float3 f3Sum = float3(0.0f, 0.0f, 0.0f);
        for (int i = 0; i < 25; i++)
            f3Sum += input[i].positionW;
        float3 f3Center = f3Sum / 25.0f;
        output.fTessInsides[0] = output.fTessInsides[1] = CalculateTessFactor(f3Center);
    }
    else
    {
        output.fTessEdges[0] = 20.0f;
        output.fTessEdges[1] = 20.0f;
        output.fTessEdges[2] = 20.0f;
        output.fTessEdges[3] = 20.0f;

        output.fTessInsides[0] = 20.0f;
        output.fTessInsides[1] = 20.0f;
    }

    return (output);
}

void BernsteinCoeffcient5x5(float t, out float fBernstein[5])
{
    float tInv = 1.0f - t;
    fBernstein[0] = tInv * tInv * tInv * tInv;
    fBernstein[1] = 4.0f * t * tInv * tInv * tInv;
    fBernstein[2] = 6.0f * t * t * tInv * tInv;
    fBernstein[3] = 4.0f * t * t * t * tInv;
    fBernstein[4] = t * t * t * t;
}

float3 CubicBezierSum5x5(OutputPatch<HS_TERRAIN_TESSELLATION_OUTPUT, 25> patch, float uB[5], float vB[5])
{
    float3 f3Sum = float3(0.0f, 0.0f, 0.0f);
    f3Sum = vB[0] * (uB[0] * patch[0].position + uB[1] * patch[1].position + uB[2] * patch[2].position + uB[3] * patch[3].position + uB[4] * patch[4].position);
    f3Sum += vB[1] * (uB[0] * patch[5].position + uB[1] * patch[6].position + uB[2] * patch[7].position + uB[3] * patch[8].position + uB[4] * patch[9].position);
    f3Sum += vB[2] * (uB[0] * patch[10].position + uB[1] * patch[11].position + uB[2] * patch[12].position + uB[3] * patch[13].position + uB[4] * patch[14].position);
    f3Sum += vB[3] * (uB[0] * patch[15].position + uB[1] * patch[16].position + uB[2] * patch[17].position + uB[3] * patch[18].position + uB[4] * patch[19].position);
    f3Sum += vB[4] * (uB[0] * patch[20].position + uB[1] * patch[21].position + uB[2] * patch[22].position + uB[3] * patch[23].position + uB[4] * patch[24].position);

    return (f3Sum);
}

[domain("quad")]
DS_TERRAIN_TESSELLATION_OUTPUT DSTerrainTessellation(HS_TERRAIN_TESSELLATION_CONSTANT patchConstant, float2 uv : SV_DomainLocation, OutputPatch<HS_TERRAIN_TESSELLATION_OUTPUT, 25> patch)
{
    DS_TERRAIN_TESSELLATION_OUTPUT output = (DS_TERRAIN_TESSELLATION_OUTPUT) 0;

    float uB[5], vB[5];
    BernsteinCoeffcient5x5(uv.x, uB);
    BernsteinCoeffcient5x5(uv.y, vB);

    output.color = lerp(lerp(patch[0].color, patch[4].color, uv.x), lerp(patch[20].color, patch[24].color, uv.x), uv.y);
    output.uv0 = lerp(lerp(patch[0].uv0, patch[4].uv0, uv.x), lerp(patch[20].uv0, patch[24].uv0, uv.x), uv.y);
    output.uv1 = lerp(lerp(patch[0].uv1, patch[4].uv1, uv.x), lerp(patch[20].uv1, patch[24].uv1, uv.x), uv.y);

    float3 position = CubicBezierSum5x5(patch, uB, vB);
    matrix mtxWorldViewProjection = mul(mul(gmtxGameObject, gmtxView), gmtxProjection);
    output.position = mul(float4(position, 1.0f), mtxWorldViewProjection);

    output.tessellation = float4(patchConstant.fTessEdges[0], patchConstant.fTessEdges[1], patchConstant.fTessEdges[2], patchConstant.fTessEdges[3]);

    return (output);
}

float4 PSTerrainTessellation(DS_TERRAIN_TESSELLATION_OUTPUT input) : SV_TARGET
{
    float4 cColor = float4(0.0f, 0.0f, 0.0f, 1.0f);

    if (gnRenderMode & (DEBUG_TESSELLATION | DYNAMIC_TESSELLATION))
    {
        if (input.tessellation.w <= 5.0f)
            cColor = float4(1.0f, 0.0f, 0.0f, 1.0f);
        else if (input.tessellation.w <= 10.0f)
            cColor = float4(0.0f, 1.0f, 0.0f, 1.0f);
        else if (input.tessellation.w <= 20.0f)
            cColor = float4(0.0f, 0.0f, 1.0f, 1.0f);
        else if (input.tessellation.w <= 30.0f)
            cColor = float4(1.0f, 0.0f, 1.0f, 1.0f);
        else if (input.tessellation.w <= 40.0f)
            cColor = float4(1.0f, 1.0f, 0.0f, 1.0f);
        else if (input.tessellation.w <= 50.0f)
            cColor = float4(1.0f, 1.0f, 1.0f, 1.0f);
        else if (input.tessellation.w <= 55.0f)
            cColor = float4(0.2f, 0.2f, 0.72f, 1.0f);
        else if (input.tessellation.w <= 60.0f)
            cColor = float4(0.5f, 0.75f, 0.75f, 1.0f);
        else
            cColor = float4(0.87f, 0.17f, 1.0f, 1.0f);
    }
    else
    {
        float4 cBaseTexColor = gtxtTerrainTexture.Sample(gssWrap, input.uv0);
        float4 cDetailTexColor = gtxtDetailTexture.Sample(gssWrap, input.uv1);
        float fAlpha = gtxtAlphaTexture.Sample(gssWrap, input.uv0);

        cColor = saturate(lerp(cBaseTexColor, cDetailTexColor, fAlpha));
    }

    return (cColor);
}



