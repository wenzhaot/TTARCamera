//
//  TTCIFilterConstructor.h
//  TTARCamera
//
//  Created by wenzhaot on 2019/7/9.
//

#import <Foundation/Foundation.h>
#import <CoreImage/CoreImage.h>

NS_ASSUME_NONNULL_BEGIN

@interface TTCIFilterConstructor : NSObject <CIFilterConstructor>
+ (instancetype)constructor;
- (instancetype)init NS_UNAVAILABLE;
@end

NS_ASSUME_NONNULL_END
