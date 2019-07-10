//
//  TTARBackgroundRender.h
//  TTARCamera
//
//  Created by wenzhaot on 2019/7/10.
//

#import <Foundation/Foundation.h>
#import <ARKit/ARKit.h>

NS_ASSUME_NONNULL_BEGIN

@protocol TTARFrameFeeder;

@interface TTARBackgroundRender : NSObject
@property (strong, nonatomic) id<TTARFrameFeeder> frameFeeder;
@property (assign, nonatomic) CGFloat blurRadius;
@property (assign, nonatomic) CGFloat gamma;
@property (assign, nonatomic) BOOL hasBeauty;
@property (assign, nonatomic) UIInterfaceOrientation orientation;
@property (readonly, nonatomic) dispatch_queue_t processQueue;
- (void)updateFrame:(ARFrame *)frame inScene:(ARSCNView *)sceneView;
@end

NS_ASSUME_NONNULL_END
