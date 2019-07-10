//
//  TTCIHighPass.m
//  TTARCamera
//
//  Created by wenzhaot on 2019/7/9.
//

#import "TTCIHighPass.h"
#import "TTCIFilterConstructor.h"

@implementation TTCIHighPass

static CIColorKernel *tt_hignPassKernel = nil;

+ (void)initialize {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        @autoreleasepool {
            if ([CIFilter respondsToSelector:@selector(registerFilterName:constructor:classAttributes:)]) {
                [CIFilter registerFilterName:NSStringFromClass([TTCIHighPass class])
                                 constructor:[TTCIFilterConstructor constructor]
                             classAttributes:@{kCIAttributeFilterCategories: @[kCICategoryStillImage,kCICategoryVideo],
                                               kCIAttributeFilterDisplayName: @"High Pass"}];
            }
        }
    });
}

- (instancetype)init
{
    self = [super init];
    if (self) {
        if (tt_hignPassKernel == nil) {
            NSBundle *bundle = [NSBundle bundleForClass:[self class]];
            NSURL *kernelURL = [bundle URLForResource:@"default" withExtension:@"metallib"];
            NSError *error;
            NSData *data = [NSData dataWithContentsOfURL:kernelURL];
            tt_hignPassKernel = [CIColorKernel kernelWithFunctionName:@"highPass" fromMetalLibraryData:data error:&error];
            if (error) {
                NSLog(@"highPass kernel error:%@", error.localizedDescription);
            }
        }
    }
    return self;
}

- (NSNumber *)inputRadius {
    if (!_inputRadius) { _inputRadius = @(1.0); }
    return _inputRadius;
}

- (void)setDefaults {
    self.inputRadius = nil;
}

- (CIImage *)outputImage {
    if (!self.inputImage) { return nil; }
    
    CIFilter *blurFilter = [CIFilter filterWithName:@"CIGaussianBlur"];
    [blurFilter setValue:self.inputImage.imageByClampingToExtent forKey:kCIInputImageKey];
    [blurFilter setValue:self.inputRadius forKey:kCIInputRadiusKey];
    return [tt_hignPassKernel applyWithExtent:self.inputImage.extent arguments:@[self.inputImage,blurFilter.outputImage]];
}

@end
