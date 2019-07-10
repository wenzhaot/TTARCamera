//
//  TTARImageFeeder.h
//  TTARCamera
//
//  Created by wenzhaot on 2019/7/9.
//

#import <Foundation/Foundation.h>
#import "TTARFrameFeeder.h"

NS_ASSUME_NONNULL_BEGIN

@interface TTARImageFeeder : NSObject <TTARFrameFeeder>

+ (instancetype)feederWithDirectory:(NSString *)inDirectory count:(NSUInteger)count;

@end

NS_ASSUME_NONNULL_END
