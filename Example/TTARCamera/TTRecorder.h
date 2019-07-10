//
//  TTRecorder.h
//  TTARCamera
//
//  Created by wenzhaot on 2019/7/10.
//  Copyright © 2019 wenzhaot. All rights reserved.
//

#import <AVFoundation/AVFoundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef void (^TTRecorderRunningHandler)(NSError * __nullable error);
typedef void (^TTRecorderCompletionHandler)(NSURL * __nullable outputURL, NSError * __nullable error);

@protocol TTRecorder <NSObject>

@property (readonly) UIView *preview;
@property (readonly, getter=isRunning) BOOL running;
@property (readonly, getter=isRecording) BOOL recording;
@property (class, nonatomic, readonly) BOOL isSupported;
@property (assign, nonatomic) CGFloat beautyLevel;  //美颜级别

/**
 The value of this property defaults to AVCaptureDevicePositionFront
 */
@property (nonatomic) AVCaptureDevicePosition position;
@property (nonatomic) UIInterfaceOrientation orientation;

- (void)startRunning:(TTRecorderRunningHandler)handler;
- (void)stopRunning;

- (void)record:(NSURL *)outputURL;
- (void)pause:(TTRecorderCompletionHandler)completionHandler;

/**
 Switch between the camera devices
 */
- (void)switchCaptureDevices;

@optional

- (void)addStickerPackage:(NSString *)packageId zipPath:(NSString *)zipPath;
- (void)removeStickerPackage:(NSString *)packageId;

@end

NS_ASSUME_NONNULL_END
