//
//  TTFilter.metal
//  TTARCamera
//
//  Created by wenzhaot on 2019/7/9.
//

#include <metal_stdlib>
#include <CoreImage/CoreImage.h>
using namespace metal;

extern "C" {
    namespace coreimage
    {
        float4 greenBlueChannelOverlayBlend(sample_t image) {
            float4 base = float4(image.g,image.g,image.g,1.0);
            float4 overlay = float4(image.b,image.b,image.b,1.0);
            float ba = 2.0 * overlay.b * base.b + overlay.b * (1.0 - base.a) + base.b * (1.0 - overlay.a);
            return float4(ba,ba,ba,image.a);
        }
        
        float4 highPass(sample_t image, sample_t blurredImage) {
            return float4(float3(image.rgb - blurredImage.rgb + float3(0.5,0.5,0.5)), image.a);
        }
        
        float4 highPassSkinSmoothingMaskBoost(sample_t image) {
            float hardLightColor = image.b;
            
            for (int i = 0; i < 3; ++i) {
                if (hardLightColor < 0.5) {
                    hardLightColor = hardLightColor  * hardLightColor * 2.;
                } else {
                    hardLightColor = 1. - (1. - hardLightColor) * (1. - hardLightColor) * 2.;
                }
            }
            
            const float k = 255.0 / (164.0 - 75.0);
            
            hardLightColor = (hardLightColor - 75.0 / 255.0) * k;
            
            return float4(float3(hardLightColor), image.a);
        }
        
        float4 rgbToneCurve(sampler inputImage, sampler toneCurveTexture, float intensity) {
            float4 textureColor = inputImage.sample(inputImage.coord());
            float4 toneCurveTextureExtent = toneCurveTexture.extent();
            
            float2 redCoord = toneCurveTexture.transform(float2(textureColor.r * 255.0 + 0.5 + toneCurveTextureExtent.x, toneCurveTextureExtent.y + 0.5));
            float2 greenCoord = toneCurveTexture.transform(float2(textureColor.g * 255.0 + 0.5 + toneCurveTextureExtent.x, toneCurveTextureExtent.y + 0.5));
            float2 blueCoord = toneCurveTexture.transform(float2(textureColor.b * 255.0 + 0.5 + toneCurveTextureExtent.x, toneCurveTextureExtent.y + 0.5));
            
            float redCurveValue = toneCurveTexture.sample(redCoord).r;
            float greenCurveValue = toneCurveTexture.sample(greenCoord).g;
            float blueCurveValue = toneCurveTexture.sample(blueCoord).b;
            return float4(mix(textureColor.rgb,float3(redCurveValue, greenCurveValue, blueCurveValue),intensity),textureColor.a);
        }
    }
    
}
