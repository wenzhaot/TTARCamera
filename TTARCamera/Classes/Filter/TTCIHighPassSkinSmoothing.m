//
//  TTCIHighPassSkinSmoothing.m
//  TTARCamera
//
//  Created by wenzhaot on 2019/7/10.
//

#import "TTCIHighPassSkinSmoothing.h"
#import "TTCIFilterConstructor.h"
#import "TTCIRGBToneCurve.h"
#import "TTCIHighPass.h"

static CIColorKernel *tt_greenBlueChannelOverlayBlendKernel = nil;

@interface TTCIGreenBlueChannelOverlayBlend : CIFilter
@property (nonatomic,strong) CIImage *inputImage;
@end

@implementation TTCIGreenBlueChannelOverlayBlend

- (instancetype)init
{
    self = [super init];
    if (self) {
        if (tt_greenBlueChannelOverlayBlendKernel == nil) {
            NSBundle *bundle = [NSBundle bundleForClass:[self class]];
            NSURL *kernelURL = [bundle URLForResource:@"default" withExtension:@"metallib"];
            NSError *error;
            NSData *data = [NSData dataWithContentsOfURL:kernelURL];
            tt_greenBlueChannelOverlayBlendKernel = [CIColorKernel kernelWithFunctionName:@"greenBlueChannelOverlayBlend" fromMetalLibraryData:data error:&error];
            if (error) {
                NSLog(@"highPass kernel error:%@", error.localizedDescription);
            }
        }
    }
    return self;
}

- (CIImage *)outputImage {
    return [tt_greenBlueChannelOverlayBlendKernel applyWithExtent:self.inputImage.extent arguments:@[self.inputImage]];
}

@end


static CIColorKernel *tt_highPassSkinSmoothingMaskBoostKernel = nil;

@interface TTCIHighPassSkinSmoothingMaskBoost : CIFilter
@property (nonatomic, strong) CIImage *inputImage;
@end

@implementation TTCIHighPassSkinSmoothingMaskBoost

- (instancetype)init
{
    self = [super init];
    if (self) {
        if (tt_highPassSkinSmoothingMaskBoostKernel == nil) {
            NSBundle *bundle = [NSBundle bundleForClass:[self class]];
            NSURL *kernelURL = [bundle URLForResource:@"default" withExtension:@"metallib"];
            NSError *error;
            NSData *data = [NSData dataWithContentsOfURL:kernelURL];
            tt_highPassSkinSmoothingMaskBoostKernel = [CIColorKernel kernelWithFunctionName:@"highPassSkinSmoothingMaskBoost" fromMetalLibraryData:data error:&error];
            if (error) {
                NSLog(@"highPass kernel error:%@", error.localizedDescription);
            }
            
        }
    }
    return self;
}

- (CIImage *)outputImage {
    return [tt_highPassSkinSmoothingMaskBoostKernel applyWithExtent:self.inputImage.extent arguments:@[self.inputImage]];
}

@end



@interface TTCIHighPassSkinSmoothingMaskGenerator: CIFilter
@property (strong, nonatomic) CIImage *inputImage;
@property (copy,   nonatomic) NSNumber *inputRadius;
@end

@implementation TTCIHighPassSkinSmoothingMaskGenerator

- (CIImage *)outputImage {
    CIFilter *exposureFilter = [CIFilter filterWithName:@"CIExposureAdjust"];
    [exposureFilter setValue:self.inputImage forKey:kCIInputImageKey];
    [exposureFilter setValue:@(-1.0) forKey:kCIInputEVKey];
    
    TTCIGreenBlueChannelOverlayBlend *channelOverlayFilter = [[TTCIGreenBlueChannelOverlayBlend alloc] init];
    channelOverlayFilter.inputImage = exposureFilter.outputImage;
    
    TTCIHighPass *highPassFilter = [[TTCIHighPass alloc] init];
    highPassFilter.inputImage = channelOverlayFilter.outputImage;
    highPassFilter.inputRadius = self.inputRadius;
    
    TTCIHighPassSkinSmoothingMaskBoost *hardLightFilter = [[TTCIHighPassSkinSmoothingMaskBoost alloc] init];
    hardLightFilter.inputImage = highPassFilter.outputImage;
    return hardLightFilter.outputImage;
}

@end




@interface TTCIHighPassSkinSmoothing ()
@property (strong, nonatomic) TTCIRGBToneCurve *skinToneCurveFilter;
@end

@implementation TTCIHighPassSkinSmoothing

+ (void)load {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        @autoreleasepool {
            if ([CIFilter respondsToSelector:@selector(registerFilterName:constructor:classAttributes:)]) {
                [CIFilter registerFilterName:NSStringFromClass([TTCIHighPassSkinSmoothing class])
                                 constructor:[TTCIFilterConstructor constructor]
                             classAttributes:@{kCIAttributeFilterCategories: @[kCICategoryStillImage,kCICategoryVideo],
                                               kCIAttributeFilterDisplayName: @"High Pass Skin Smoothing"}];
            }
        }
    });
}

- (NSNumber *)inputAmount {
    if (!_inputAmount) { _inputAmount = @(0.75); }
    return _inputAmount;
}

- (NSNumber *)inputRadius {
    if (!_inputRadius) { _inputRadius = @(8.0); }
    return _inputRadius;
}

- (TTCIRGBToneCurve *)skinToneCurveFilter {
    if (!_skinToneCurveFilter) {
        _skinToneCurveFilter = [[TTCIRGBToneCurve alloc] init];
        _skinToneCurveFilter.inputRGBCompositeControlPoints = self.defaultInputRGBCompositeControlPoints;
    }
    return _skinToneCurveFilter;
}

- (NSArray<CIVector *> *)defaultInputRGBCompositeControlPoints {
    return @[[CIVector vectorWithX:0 Y:0],
             [CIVector vectorWithX:120/255.0 Y:146/255.0],
             [CIVector vectorWithX:1.0 Y:1.0]];
}

- (void)setInputToneCurveControlPoints:(NSArray<CIVector *> *)inputToneCurveControlPoints {
    if (inputToneCurveControlPoints.count == 0) {
        inputToneCurveControlPoints = self.defaultInputRGBCompositeControlPoints;
    }
    self.skinToneCurveFilter.inputRGBCompositeControlPoints = inputToneCurveControlPoints;
}

- (NSArray<CIVector *> *)inputToneCurveControlPoints {
    return self.skinToneCurveFilter.inputRGBCompositeControlPoints;
}

- (NSNumber *)inputSharpnessFactor {
    if (!_inputSharpnessFactor) {
        _inputSharpnessFactor = @(0.6);
    }
    return _inputSharpnessFactor;
}

- (void)setDefaults {
    self.inputAmount = nil;
    self.inputRadius = nil;
    self.inputToneCurveControlPoints = nil;
    self.inputSharpnessFactor = nil;
}

- (CIImage *)outputImage {
    if (!self.inputImage) {
        return nil;
    }
    
    TTCIHighPassSkinSmoothingMaskGenerator *maskGenerator = [[TTCIHighPassSkinSmoothingMaskGenerator alloc] init];
    maskGenerator.inputRadius = self.inputRadius;
    maskGenerator.inputImage = self.inputImage;
    
    TTCIRGBToneCurve *skinToneCurveFilter = self.skinToneCurveFilter;
    skinToneCurveFilter.inputImage = self.inputImage;
    skinToneCurveFilter.inputIntensity = self.inputAmount;
    
    CIFilter *blendWithMaskFilter = [CIFilter filterWithName:@"CIBlendWithMask"];
    [blendWithMaskFilter setValue:self.inputImage forKey:kCIInputImageKey];
    [blendWithMaskFilter setValue:skinToneCurveFilter.outputImage forKey:kCIInputBackgroundImageKey];
    [blendWithMaskFilter setValue:maskGenerator.outputImage forKey:kCIInputMaskImageKey];
    
    double sharpnessValue = self.inputSharpnessFactor.doubleValue * self.inputAmount.doubleValue;
    if (sharpnessValue > 0) {
        CIFilter *shapenFilter = [CIFilter filterWithName:@"CISharpenLuminance"];
        [shapenFilter setValue:@(sharpnessValue) forKey:@"inputSharpness"];
        [shapenFilter setValue:blendWithMaskFilter.outputImage forKey:kCIInputImageKey];
        return shapenFilter.outputImage;
    } else {
        return blendWithMaskFilter.outputImage;
    }
}

@end
