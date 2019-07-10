//
//  TTCIRGBToneCurve.h
//  TTARCamera
//
//  Created by wenzhaot on 2019/7/10.
//

#import <CoreImage/CoreImage.h>

NS_ASSUME_NONNULL_BEGIN

@interface TTCIRGBToneCurve : CIFilter
@property (nonatomic, strong, nullable) CIImage *inputImage;
@property (nonatomic, copy, null_resettable) NSArray<CIVector *> *inputRedControlPoints;
@property (nonatomic, copy, null_resettable) NSArray<CIVector *> *inputGreenControlPoints;
@property (nonatomic, copy, null_resettable) NSArray<CIVector *> *inputBlueControlPoints;
@property (nonatomic, copy, null_resettable) NSArray<CIVector *> *inputRGBCompositeControlPoints;
@property (nonatomic, copy, null_resettable) NSNumber *inputIntensity; //default 1.0
@end

NS_ASSUME_NONNULL_END
