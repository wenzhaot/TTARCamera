//
//  TTARVideoFeeder.h
//  TTARCamera
//
//  Created by wenzhaot on 2019/7/9.
//

#import <Foundation/Foundation.h>
#import "TTARFrameFeeder.h"

NS_ASSUME_NONNULL_BEGIN

@interface TTARVideoFeeder : NSObject <TTARFrameFeeder>

+ (instancetype)feederWithFilePath:(NSString *)path;

@end

NS_ASSUME_NONNULL_END
