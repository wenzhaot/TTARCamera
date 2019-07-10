//
//  TTCIHighPassSkinSmoothing.h
//  TTARCamera
//
//  Created by wenzhaot on 2019/7/10.
//

#import <CoreImage/CoreImage.h>

NS_ASSUME_NONNULL_BEGIN

@interface TTCIHighPassSkinSmoothing : CIFilter
@property (nonatomic, strong, nullable) CIImage *inputImage;
@property (nonatomic, copy, null_resettable) NSNumber *inputAmount;
@property (nonatomic, copy, null_resettable) NSNumber *inputRadius;
@property (nonatomic, copy, null_resettable) NSArray<CIVector *> *inputToneCurveControlPoints;
@property (nonatomic, copy, null_resettable) NSNumber *inputSharpnessFactor;
@end

NS_ASSUME_NONNULL_END
