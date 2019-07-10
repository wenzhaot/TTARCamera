//
//  TTARCamera.h
//  TTARCamera
//
//  Created by wenzhaot on 2019/7/10.
//

#import <ARKit/ARKit.h>
#import <TTARCamera/TTARStickerPackage.h>

NS_ASSUME_NONNULL_BEGIN

@class TTARBackgroundRender;
@protocol TTARFrameFeeder;

@interface TTARCamera : NSObject
@property (readonly, nonatomic) ARSCNView *sceneView;
@property (strong,   nonatomic) ARConfiguration *configuration; // ARFaceTrackingConfiguration for default.

@property (strong, nullable, nonatomic) id<TTARFrameFeeder> backgroundFeeder;
@property (readonly, nullable, nonatomic) TTARBackgroundRender *backgroundRender;

@property (nonatomic) UIInterfaceOrientation outputImageOrientation;

@property (copy, nullable, nonatomic) void(^audioBufferHandler)(CMSampleBufferRef audioSampleBuffer);

/**
 ARSession run
 
 @return If it returns NO, the configuration was not supported.
 */
- (BOOL)startRunning;


/**
 ARSession pause
 */
- (void)stopRunning;


// Sticker Package

- (void)addStickerPackage:(TTARStickerPackage *)pack;
- (void)removePackageById:(NSString *)packageId;
@end

NS_ASSUME_NONNULL_END
