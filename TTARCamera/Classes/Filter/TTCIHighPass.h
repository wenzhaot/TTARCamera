//
//  TTCIHighPass.h
//  TTARCamera
//
//  Created by wenzhaot on 2019/7/9.
//

#import <CoreImage/CoreImage.h>

NS_ASSUME_NONNULL_BEGIN

@interface TTCIHighPass : CIFilter
@property (strong, nonatomic, nullable) CIImage *inputImage;
@property (copy,   nonatomic, null_resettable) NSNumber *inputRadius;
@end

NS_ASSUME_NONNULL_END
