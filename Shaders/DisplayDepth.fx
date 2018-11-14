///////////////////////////////////////////////////////
// Ported from Reshade v2.x. Original by CeeJay.
// Displays the depth buffer: further away is more white than close by. 
// Use this to configure the depth buffer preprocessor settings
// in Reshade's settings. (The RESHADE_DEPTH_INPUT_* ones)
///////////////////////////////////////////////////////

#include "Reshade.fxh"

uniform int iUIInfo <
	ui_type = "combo";
	ui_label = "How To Setting";
	ui_tooltip = "Pick the value from 'Depth Input Settings'\n"
	             "that lets the scene look the most natural.\n"
	             "Then put the values from the tooltip into\n"
	             "the settings.\n"
	             "(Settings Tab -> Preprocessor Definitions)";
	ui_items = "Pointer Here\0";
> = 0;

uniform bool bUIUsePreprocessorDefs <
	ui_label = "Use Preprocessor Definitions";
	ui_tooltip = "Enable this to override the values from\n"
	             "'Depth Input Settings' with the\n"
				 "preprocessor definitions. If all is set\n"
				 "up correctly, no difference should be\n"
				 "noticed.";
> = false;

uniform float fUIFarPlane <
	ui_category = "Preprocessor";
	ui_type = "drag";
	ui_label = "Far Plane";
	ui_tooltip = "*: RESHADE_DEPTH_LINEARIZATION_FAR_PLANE=*";
	ui_min = 0.0; ui_max = 1000.0;
	ui_step = 0.1;
> = __RESHADE_DEPTH_LINEARIZATION_FAR_PLANE_DEFAULT__;

uniform int iUIUpsideDown <
	ui_category = "Preprocessor";
	ui_type = "combo";
	ui_label = "Upside Down";
	ui_tooltip = "On:  RESHADE_DEPTH_INPUT_IS_UPSIDE_DOWN=1\n"
	             "Off: RESHADE_DEPTH_INPUT_IS_UPSIDE_DOWN=0";
	ui_items = "Off\0On\0";
> = __RESHADE_DEPTH_INPUT_IS_UPSIDE_DOWN_DEFAULT__;

uniform int iUIReversed <
	ui_category = "Preprocessor";
	ui_type = "combo";
	ui_label = "Reversed";
	ui_tooltip = "On:  RESHADE_DEPTH_INPUT_IS_REVERSED=1\n"
	             "Off: RESHADE_DEPTH_INPUT_IS_REVERSED=0";
	ui_items = "Off\0On\0";
> = __RESHADE_DEPTH_INPUT_IS_REVERSED_DEFAULT__;

uniform int iUILogArithmic <
	ui_category = "Preprocessor";
	ui_type = "combo";
	ui_label = "Logarithmic";
	ui_tooltip = "On:  RESHADE_DEPTH_INPUT_IS_LOGARITHMIC=1\n"
	             "Off: RESHADE_DEPTH_INPUT_IS_LOGARITHMIC=0";
	ui_items = "Off\0On\0";
> = __RESHADE_DEPTH_INPUT_IS_LOGARITHMIC_DEFAULT__;

uniform bool bUIShowNormals <
	ui_category = "Debug";
	ui_type = "combo";
	ui_label = "Show Normals";
	ui_tooltip = "On:  Show normals\n"
	             "Off: Show depth";
> = true;

float GetDepth(float2 texcoord)
{
	//Return the depth value as defined in the preprocessor definitions
	if(bUIUsePreprocessorDefs)
	{
		return ReShade::GetLinearizedDepth(texcoord);
	}
	
	//Calculate the depth value as defined by the user
	//RESHADE_DEPTH_INPUT_IS_UPSIDE_DOWN
	if(iUIUpsideDown)
	{
		texcoord.y = 1.0 - texcoord.y;
	}

	float depth = tex2Dlod(ReShade::DepthBuffer, float4(texcoord, 0, 0)).x;
	//RESHADE_DEPTH_INPUT_IS_LOGARITHMIC
	if(iUILogArithmic)
	{
		const float C = 0.01;
		depth = (exp(depth * log(C + 1.0)) - 1.0) / C;
	}
	//RESHADE_DEPTH_INPUT_IS_REVERSED
	if(iUIReversed)
	{
		depth = 1.0 - depth;
	}

	const float N = 1.0;
	return depth /= fUIFarPlane - depth * (fUIFarPlane - N);
}

float3 NormalVector(float2 texcoord)
{
	float3 offset = float3(ReShade::PixelSize.xy, 0.0);
	float2 posCenter = texcoord.xy;
	float2 posNorth = posCenter - offset.zy;
	float2 posEast = posCenter + offset.xz;

	float3 vertCenter = float3(posCenter, GetDepth(posCenter));
	float3 vertNorth = float3(posNorth, GetDepth(posNorth));
	float3 vertEast = float3(posEast, GetDepth(posEast));
	
	return normalize(cross(vertCenter - vertNorth, vertCenter - vertEast)) * 0.5 + 0.5;
}

void PS_DisplayDepth(in float4 position : SV_Position, in float2 texcoord : TEXCOORD0, out float3 color : SV_Target)
{
	if(bUIShowNormals)
	{
		color = NormalVector(texcoord);
	}
	else
	{
		color.rgb = GetDepth(texcoord).rrr;

		float dither_bit  = 8.0;  //Number of bits per channel. Should be 8 for most monitors.
	
		//color = (tex.x*0.3+0.1); //draw a gradient for testing.
		//#define dither_method 2 //override method for testing purposes

		/*------------------------.
		| :: Ordered Dithering :: |
		'------------------------*/
		//Calculate grid position
		float grid_position = frac( dot(texcoord, (ReShade::ScreenSize * float2(1.0/16.0,10.0/36.0) ) + 0.25) );

		//Calculate how big the shift should be
		float dither_shift = 0.25 * (1.0 / (pow(2,dither_bit) - 1.0));

		//Shift the individual colors differently, thus making it even harder to see the dithering pattern
		float3 dither_shift_RGB = float3(dither_shift, -dither_shift, dither_shift); //subpixel dithering

		//modify shift acording to grid position.
		dither_shift_RGB = lerp(2.0 * dither_shift_RGB, -2.0 * dither_shift_RGB, grid_position); //shift acording to grid position.

		//shift the color by dither_shift
		color.rgb += dither_shift_RGB;
	}
}

technique DisplayDepth
{
	pass
	{
		VertexShader = PostProcessVS;
		PixelShader = PS_DisplayDepth;
	}
}
