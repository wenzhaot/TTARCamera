//
//  TTARSticker.h
//  TTARCamera
//
//  Created by wenzhaot on 2019/7/9.
//

#import <Foundation/Foundation.h>
#import <SceneKit/SceneKit.h>

NS_ASSUME_NONNULL_BEGIN

@protocol TTARFrameFeeder;

typedef NS_ENUM(NSInteger, TTARStickerType) {
    TTARStickerTypeFace,
    TTARStickerTypeDepth
};

@protocol TTARSticker <NSObject>
@property (readonly) TTARStickerType type;
@property (copy, nonatomic) NSString *name;
@property (copy, nonatomic) NSString *directory;
@end



// MARK: - Depth

@interface TTARDepthSticker : NSObject <TTARSticker>
@property (assign, nonatomic) CGFloat blurRadius;
@property (assign, nonatomic) CGFloat gamma;
@property (assign, nonatomic) NSInteger resType; // 0: image  1: mp4
@property (assign, nonatomic) NSInteger frameCount;
- (id<TTARFrameFeeder>)frameFeeder;
@end



// MARK: - Vector

@interface TTARStickerVector : NSObject
@property (assign, nonatomic) CGFloat x;
@property (assign, nonatomic) CGFloat y;
@property (assign, nonatomic) CGFloat z;
@end




// MARK: - Normal

@interface TTARNormalSticker : NSObject <TTARSticker>
@property (assign, nonatomic) CGFloat width;
@property (assign, nonatomic) CGFloat height;

@property (strong, nonatomic) TTARStickerVector *position;
@property (strong, nonatomic) TTARStickerVector *scale;

// 0: 脸部蒙皮材质 1：普通图片，可以是序列帧
@property (assign, nonatomic) NSInteger resType;
@property (assign, nonatomic) NSInteger frameCount;
@property (assign, nonatomic) NSInteger loopCount;  // -1: forever
@property (assign, nonatomic) NSTimeInterval duration;

@property (assign, nonatomic) CGFloat opacity;
@property (assign, nonatomic) NSInteger renderingOrder;
@property (assign, nonatomic) BOOL castsShadow;

@property (strong, readonly, nonatomic) SCNNode *node;

- (UIImage *)firstImage;
- (void)runAnimationIfNeeded;
@end

NS_ASSUME_NONNULL_END
