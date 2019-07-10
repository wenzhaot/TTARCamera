//
//  TTARRecorder.m
//  TTARCamera_Example
//
//  Created by wenzhaot on 2019/7/10.
//  Copyright © 2019 wenzhaot. All rights reserved.
//

#import "TTARRecorder.h"
#import <TTARCamera/TTARCamera.h>
#import <TTARCamera/TTARMovieWriter.h>
#import <TTARCamera/TTARStickerParser.h>
#import <TTARCamera/TTARBackgroundRender.h>
#import <Metal/Metal.h>

@interface TTARWeakProxy : NSProxy
@property (nonatomic, weak) id target;
+ (instancetype)weakProxyForObject:(id)targetObject;
@end

@implementation TTARWeakProxy

#pragma mark Life Cycle

+ (instancetype)weakProxyForObject:(id)targetObject
{
    TTARWeakProxy *weakProxy = [TTARWeakProxy alloc];
    weakProxy.target = targetObject;
    return weakProxy;
}


#pragma mark Forwarding Messages

- (id)forwardingTargetForSelector:(SEL)selector
{
    return _target;
}


#pragma mark - NSWeakProxy Method Overrides
#pragma mark Handling Unimplemented Methods

- (void)forwardInvocation:(NSInvocation *)invocation
{
    void *nullPointer = NULL;
    [invocation setReturnValue:&nullPointer];
}


- (NSMethodSignature *)methodSignatureForSelector:(SEL)selector
{
    return [NSObject instanceMethodSignatureForSelector:@selector(init)];
}

@end




@interface TTARRecorder () <TTARMovieWriterDelegate>
@property (strong, nonatomic) TTARCamera *camera;
@property (strong, nonatomic) TTARMovieWriter *movieWriter;
@property (strong, nonatomic) SCNRenderer *renderEngine;
@property (strong, nonatomic) CADisplayLink *gpuLoop;
@property (copy,   nonatomic) NSURL *outputURL;
@property (assign, nonatomic) CGSize bufferSize;
@property (strong, nonatomic) dispatch_queue_t pixelsQueue;
@property (strong, nonatomic) dispatch_queue_t writerQueue;
@property (copy,   nonatomic) TTRecorderCompletionHandler completionHandler;
@end

@implementation TTARRecorder
@synthesize running = _running;
@synthesize recording = _recording;
@synthesize position = _position;
@synthesize orientation = _orientation;
@synthesize beautyLevel = _beautyLevel;

+ (BOOL)isSupported {
    return [ARFaceTrackingConfiguration isSupported];
}

- (void)dealloc
{
    [_gpuLoop invalidate];
    [self setGpuLoop:nil];
}

- (instancetype)init
{
    self = [super init];
    if (self) {
        _pixelsQueue = dispatch_queue_create("VKARRecorder.pixelsQueue", DISPATCH_QUEUE_CONCURRENT);
        _writerQueue = dispatch_queue_create("VKARRecorder.writerQueue", NULL);
    }
    return self;
}

- (void)startRunning:(TTRecorderRunningHandler)handler {
    if (self.isRunning) {
        return;
    }
    
    _running = YES;
    
    NSError *error = nil;
    if (![_camera startRunning]) {
        error = [NSError errorWithDomain:@"TTARRecorder" code:9999 userInfo:@{NSLocalizedDescriptionKey : @"Not supported"}];
    }
    
    if (handler) {
        handler(error);
    }
}

- (void)stopRunning {
    [_camera stopRunning];
    
    _running = NO;
}

- (void)record:(NSURL *)outputURL {
    if (self.isRecording) {
        return;
    }
    
    _recording = YES;
    _outputURL = outputURL;
    
    id<MTLDevice> mtlDevice = MTLCreateSystemDefaultDevice();
    if (mtlDevice == nil) {
        NSLog(@"ERROR:- This device does not support Metal");
    }
    
    _renderEngine = [SCNRenderer rendererWithDevice:mtlDevice options:nil];
    _renderEngine.scene = self.camera.sceneView.scene;
    
    _gpuLoop = [CADisplayLink displayLinkWithTarget:[TTARWeakProxy weakProxyForObject:self] selector:@selector(renderFrame)];
    _gpuLoop.preferredFramesPerSecond = 60;
    [_gpuLoop addToRunLoop:[NSRunLoop mainRunLoop] forMode:NSRunLoopCommonModes];
    
}

- (void)pause:(TTRecorderCompletionHandler)completionHandler {
    if (!self.isRecording) {
        return;
    }
    
    [_gpuLoop invalidate];
    [self setGpuLoop:nil];
    
    __weak typeof(self)weakSelf = self;
    [self setCompletionHandler:completionHandler];
    [self.movieWriter finishRecordingWithCompletionHandler:^{
        __strong __typeof(weakSelf) strongSelf = weakSelf;
        
        [strongSelf setMovieWriter:nil];
        strongSelf->_recording = NO;
        strongSelf.completionHandler(strongSelf.outputURL, nil);
    }];
}

// MARK: - Buffer

- (void)renderFrame {
    if (!self.isRecording) {
        return;
    }
    
    CVPixelBufferRef buffer = [self capturePixelBuffer];
    if (buffer == NULL) {
        return;
    }
    
    dispatch_sync(_writerQueue, ^{
        CMTime time = CMTimeMakeWithSeconds(CACurrentMediaTime(), 1000000);
        
        if (self.isRecording) {
            if (self.movieWriter == nil) {
                self.movieWriter = [[TTARMovieWriter alloc] initWithMovieURL:self.outputURL size:self.bufferSize audioEnable:YES];
                self.movieWriter.delelgate = self;
            } else {
                [self.movieWriter insertPixelBuffer:buffer time:time];
                CFRelease(buffer);
            }
        }
    });
    
}

- (CVPixelBufferRef)capturePixelBuffer {
    CVPixelBufferRef rawBuffer = self.camera.sceneView.session.currentFrame.capturedImage;
    if (rawBuffer == NULL) {
        return NULL;
    }
    
    size_t width = CVPixelBufferGetWidth(rawBuffer);
    size_t height = CVPixelBufferGetHeight(rawBuffer);
    
    self.bufferSize = CGSizeMake(width, height);
    
    __block UIImage *renderedFrame = nil;
    dispatch_sync(_pixelsQueue, ^{
        renderedFrame = [self.renderEngine
                         snapshotAtTime:CACurrentMediaTime()
                         withSize:self.bufferSize
                         antialiasingMode:SCNAntialiasingModeNone];
    });
    
    if (renderedFrame == nil) {
        renderedFrame = [_renderEngine
                         snapshotAtTime:CACurrentMediaTime()
                         withSize:self.bufferSize
                         antialiasingMode:SCNAntialiasingModeNone];
    }
    
    return [self pixelBufferFromImage:renderedFrame.CGImage];
}

- (CVPixelBufferRef)pixelBufferFromImage:(CGImageRef)image {
    NSDictionary *attrs = @{
                            (NSString *)kCVPixelBufferCGImageCompatibilityKey : @YES,
                            (NSString *)kCVPixelBufferCGBitmapContextCompatibilityKey : @YES
                            };
    CVPixelBufferRef pxbuffer = NULL;
    
    size_t frameWidth = CGImageGetWidth(image);
    size_t frameHeight = CGImageGetHeight(image);
    
    CVReturn status = CVPixelBufferCreate(kCFAllocatorDefault,
                                          frameWidth,
                                          frameHeight,
                                          kCVPixelFormatType_32ARGB,
                                          (__bridge CFDictionaryRef)attrs,
                                          &pxbuffer);
    
    if (status != kCVReturnSuccess) {
        return NULL;
    }
    
    CVPixelBufferLockBaseAddress(pxbuffer, 0);
    void *pxdata = CVPixelBufferGetBaseAddress(pxbuffer);
    
    CGColorSpaceRef rgbColorSpace = CGColorSpaceCreateDeviceRGB();
    CGContextRef context = CGBitmapContextCreate(pxdata,
                                                 frameWidth,
                                                 frameHeight,
                                                 8,
                                                 CVPixelBufferGetBytesPerRow(pxbuffer),
                                                 rgbColorSpace,
                                                 (CGBitmapInfo)kCGImageAlphaNoneSkipFirst);
    
    CGContextConcatCTM(context, CGAffineTransformIdentity);
    CGContextDrawImage(context, CGRectMake(0, 0, frameWidth, frameHeight), image);
    CGColorSpaceRelease(rgbColorSpace);
    CGContextRelease(context);
    CVPixelBufferUnlockBaseAddress(pxbuffer, 0);
    
    return pxbuffer;
}

// MARK: - VKARMovieWriterDelegate

- (void)movieWriter:(TTARMovieWriter *)writer didFailed:(NSError *)error {
    _recording = NO;
}

// MARK: - Sticker

- (void)addStickerPackage:(NSString *)packageId zipPath:(NSString *)zipPath {
    __weak typeof(self)weakSelf = self;
    [TTARStickerParser parseZip:zipPath packageId:packageId completionHandler:^(TTARStickerPackage * _Nonnull pack) {
        [weakSelf.camera addStickerPackage:pack];
    }];
}

- (void)removeStickerPackage:(NSString *)packageId {
    [self.camera removePackageById:packageId];
}

- (void)switchCaptureDevices {
    
}


// MARK: - Setter

- (void)setOrientation:(UIInterfaceOrientation)orientation {
    _orientation = orientation;
    _camera.outputImageOrientation = orientation;
}

- (void)setBeautyLevel:(CGFloat)beautyLevel {
    _beautyLevel = beautyLevel;
    
    _camera.backgroundRender.hasBeauty = beautyLevel >= 0.6;
}

// MARK: - Getter

- (TTARCamera *)camera {
    if (!_camera) {
        _camera = [[TTARCamera alloc] init];
        _camera.outputImageOrientation = _orientation;
        _camera.backgroundRender.hasBeauty = _beautyLevel >= 0.6;
        
        __weak typeof(self)weakSelf = self;
        [_camera setAudioBufferHandler:^(CMSampleBufferRef  _Nonnull audioSampleBuffer) {
            [weakSelf.movieWriter appendAudioBuffer:audioSampleBuffer];
        }];
    }
    return _camera;
}

- (UIView *)preview {
    return self.camera.sceneView;
}
@end
