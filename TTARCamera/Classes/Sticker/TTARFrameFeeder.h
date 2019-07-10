//
//  TTARFrameFeeder.h
//  Pods
//
//  Created by wenzhaot on 2019/7/9.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@protocol TTARFrameFeeder <NSObject>

- (nullable UIImage *)nextFrame;

@end

NS_ASSUME_NONNULL_END
