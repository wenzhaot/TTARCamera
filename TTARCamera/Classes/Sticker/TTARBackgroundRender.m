//
//  TTARBackgroundRender.m
//  TTARCamera
//
//  Created by wenzhaot on 2019/7/10.
//

#import "TTARBackgroundRender.h"
#import "TTARFrameFeeder.h"

@interface TTARBackgroundRender ()
@property (assign, nonatomic) CGFloat depthCutOff;
@end

@implementation TTARBackgroundRender

- (instancetype)init
{
    self = [super init];
    if (self) {
        _processQueue = dispatch_queue_create("TTARBackgroudRender.Process", DISPATCH_QUEUE_SERIAL);
        _orientation = UIInterfaceOrientationPortrait;
        _blurRadius = 5.0;
        _gamma = 3.0;
    }
    return self;
}

- (void)updateFrame:(ARFrame *)frame inScene:(ARSCNView *)sceneView {
    dispatch_async(_processQueue, ^{
        [self updateBackdrop:frame scene:sceneView.scene];
    });
}

- (void)updateBackdrop:(ARFrame *)frame scene:(SCNScene *)scene {
    if (frame == nil) {
        NSLog(@"Update backdrop failed, ARFrame is nil");
        return;
    }
    
    CVPixelBufferRef videoPixelBuffer = frame.capturedImage;
    if (self.frameFeeder == nil) {
        CIImage *originalImage = [CIImage imageWithCVPixelBuffer:videoPixelBuffer];
        if (self.hasBeauty) {
            originalImage = [originalImage imageByApplyingFilter:@"TTCIHighPassSkinSmoothing" withInputParameters:@{@"inputAmount" : @(0.7)}];
        }
        
        
        CIContext *originalContext = [CIContext context];
        CGImageRef originalImgRef = [originalContext createCGImage:originalImage fromRect:originalImage.extent];
        if (originalImgRef != NULL) {
            scene.background.contents = (__bridge id _Nullable)(originalImgRef);
            scene.background.contentsTransform = [self currentScreenTransform];
            CGImageRelease(originalImgRef);
        }
        return;
    }
    
    CVPixelBufferRef depthPixelBuffer = frame.capturedDepthData.depthDataMap;
    if (depthPixelBuffer == NULL) {
        return;
    }
    
    ARAnchor *firstAnchor = frame.anchors.firstObject;
    if ([firstAnchor isKindOfClass:[ARFaceAnchor class]]) {
        simd_float4x4 viewMatrix = [frame.camera viewMatrixForOrientation:_orientation];
        self.depthCutOff = [self calculateDepthCutOff:(ARFaceAnchor *)firstAnchor viewMatrix:viewMatrix];
    }
    
    // Convert depth map in-place: every pixel above cutoff is converted to 1. otherwise it's 0
    size_t depthWidth = CVPixelBufferGetWidth(depthPixelBuffer);
    size_t depthHeight = CVPixelBufferGetHeight(depthPixelBuffer);
    
    CVPixelBufferLockBaseAddress(depthPixelBuffer, 0);
    for (int yMap = 0; yMap < depthHeight; yMap++) {
        float_t *rowData = CVPixelBufferGetBaseAddress(depthPixelBuffer) + yMap * CVPixelBufferGetBytesPerRow(depthPixelBuffer);
        for (int index = 0; index < depthWidth; index++) {
            if (rowData[index] > 0 && rowData[index] <= self.depthCutOff) {
                rowData[index] = 1.0;
            } else {
                rowData[index] = 0.0;
            }
        }
        
    }
    CVPixelBufferUnlockBaseAddress(depthPixelBuffer, 0);
    
    // Create the mask from that pixel buffer.
    CIImage *depthMaskImage = [CIImage imageWithCVPixelBuffer:depthPixelBuffer options:@{}];
    
    // Smooth edges to create an alpha matte, then upscale it to the RGB resolution.
    CGFloat alphaUpscaleFactor = CVPixelBufferGetWidth(videoPixelBuffer) / depthWidth;
    CIImage *alphaMatte = [depthMaskImage imageByClampingToExtent];
    alphaMatte = [alphaMatte imageByApplyingFilter:@"CIGaussianBlur" withInputParameters:@{@"inputRadius" : @(self.blurRadius)}];
    alphaMatte = [alphaMatte imageByApplyingFilter:@"CIGammaAdjust" withInputParameters:@{@"inputPower" : @(self.gamma)}];
    alphaMatte = [alphaMatte imageByCroppingToRect:depthMaskImage.extent];
    alphaMatte = [alphaMatte imageByApplyingFilter:@"CIBicubicScaleTransform" withInputParameters:@{@"inputScale" : @(alphaUpscaleFactor)}];
    
    CIImage *image = [CIImage imageWithCVPixelBuffer:videoPixelBuffer];
    
    // Apply alpha matte to the video.
    NSMutableDictionary *parameters = [NSMutableDictionary dictionaryWithCapacity:2];
    [parameters setValue:alphaMatte forKey:@"inputMaskImage"];
    
    CIImage *backgroundImage = [self nextBackgroundImage];
    if (backgroundImage != nil) {
        [parameters setValue:backgroundImage forKey:@"inputBackgroundImage"];
    }
    
    CIImage *output = [image imageByApplyingFilter:@"CIBlendWithMask" withInputParameters:parameters];
    
    if (self.hasBeauty) {
        output = [output imageByApplyingFilter:@"TTCIHighPassSkinSmoothing" withInputParameters:@{@"inputAmount" : @(0.7)}];
    }
    
    CIContext *context = [CIContext context];
    CGImageRef imgRef = [context createCGImage:output fromRect:output.extent];
    if (imgRef != NULL) {
        scene.background.contents = (__bridge id _Nullable)(imgRef);
        CGImageRelease(imgRef);
    }
    
    scene.background.contentsTransform = [self currentScreenTransform];
    
}

- (CGFloat)calculateDepthCutOff:(ARFaceAnchor *)anchor viewMatrix:(simd_float4x4)viewMatrix {
    CGFloat behindDist = 0.15;
    CGFloat upwardsCam = viewMatrix.columns[1][2];
    CGFloat camHeight = viewMatrix.columns[3][1];
    CGFloat headHeight = anchor.transform.columns[3][1];
    if (upwardsCam > 0.33 && camHeight - headHeight > 0.1) {
        behindDist = 1.0;
    }
    simd_float4x4 modelMatrix = anchor.transform;
    simd_float4x4 modelViewMatrix = simd_mul(viewMatrix, modelMatrix);
    return -modelViewMatrix.columns[3][2] + behindDist;
}

- (SCNMatrix4)currentScreenTransform {
    switch (self.orientation) {
        case UIInterfaceOrientationLandscapeLeft:
        return SCNMatrix4MakeRotation(M_PI, 0, 0, 1);
        
        case UIInterfaceOrientationLandscapeRight:
        return SCNMatrix4Identity;
        
        case UIInterfaceOrientationPortrait:
        return SCNMatrix4MakeRotation(M_PI_2, 0, 0, 1);
        
        case UIInterfaceOrientationPortraitUpsideDown:
        return SCNMatrix4MakeRotation(-M_PI_2, 0, 0, 1);
        
        default:
        return SCNMatrix4Identity;
    }
}

// MARK: - Handle Image

- (UIImage *)rotateToRightOrientation:(UIImage *)image {
    CGSize size = image.size;
    CGRect drawRect = CGRectMake(0, 0, size.width, size.height);
    
    UIGraphicsBeginImageContextWithOptions(drawRect.size, NO, 1.0);
    [image drawInRect:drawRect];
    
    CGContextRef context = UIGraphicsGetCurrentContext();
    if (context == nil) {
        return nil;
    }
    
    CGPoint center = CGPointMake(CGRectGetMidX(drawRect), CGRectGetMidY(drawRect));
    CGContextTranslateCTM(context, center.x, center.y);
    CGContextSaveGState(context);
    
    switch (self.orientation) {
        case UIInterfaceOrientationLandscapeLeft:
        CGContextRotateCTM(context, M_PI);
        break;
        
        case UIInterfaceOrientationLandscapeRight:
        break;
        
        case UIInterfaceOrientationPortrait:
        CGContextRotateCTM(context, M_PI_2);
        break;;
        
        case UIInterfaceOrientationPortraitUpsideDown:
        CGContextRotateCTM(context, -M_PI_2);
        break;
        
        default:
        break;
    }
    
    drawRect.origin.x = -size.width / 2;
    drawRect.origin.y = -size.height / 2;
    [image drawInRect:drawRect blendMode:kCGBlendModeNormal alpha:1.0];
    
    CGContextRestoreGState(context);
    
    UIImage *newImage = UIGraphicsGetImageFromCurrentImageContext();
    
    UIGraphicsEndImageContext();
    
    return newImage;
}

- (CIImage *)convertImage:(UIImage *)image {
    UIImage *rotatedImage = [self rotateToRightOrientation:image];
    if (rotatedImage == nil) {
        return nil;
    }
    
    CGImageRef cgImage = [rotatedImage CGImage];
    if (cgImage == NULL) {
        NSLog(@"Convert image has no CGImage");
        return nil;
    }
    
    size_t imageWidth = CGImageGetWidth(cgImage);
    size_t imageHeight = CGImageGetHeight(cgImage);
    
    // Video preview is running at 1280x720. Downscale background to same resolution
    CGFloat videoWidth = 1280;
    CGFloat videoHeight = 720;
    
    CGFloat scaleX = imageWidth / videoWidth;
    CGFloat scaleY = imageHeight / videoHeight;
    
    CGFloat scale = MIN(scaleX, scaleY);
    
    // crop the image to have the right aspect ratio
    CGSize cropSize = CGSizeMake(videoWidth * scale, videoHeight * scale);
    CGRect cropRect = CGRectMake((imageWidth - cropSize.width)/2, (imageHeight - cropSize.height)/2, cropSize.width, cropSize.height);
    CGImageRef croppedImage = CGImageCreateWithImageInRect(cgImage, cropRect);
    
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    CGContextRef context = CGBitmapContextCreate(nil, videoWidth, videoHeight, 8, 0, colorSpace, kCGImageAlphaPremultipliedLast);
    if (context == NULL) {
        NSLog(@"fail to create bitmap context");
        return nil;
    }
    
    CGRect bounds = CGRectMake(0, 0, videoWidth, videoHeight);
    CGContextClearRect(context, bounds);
    CGContextDrawImage(context, bounds, croppedImage);
    
    CGImageRef scaledImage = CGBitmapContextCreateImage(context);
    if (scaledImage == NULL) {
        NSLog(@"bitmap context create image is null");
        return nil;
    }
    
    CIImage *resultImage = [CIImage imageWithCGImage:scaledImage];
    
    CGImageRelease(croppedImage);
    CGImageRelease(scaledImage);
    
    CGContextRelease(context);
    CGColorSpaceRelease(colorSpace);
    
    return resultImage;
}

- (CIImage *)nextBackgroundImage {
    UIImage *originalImage = [self.frameFeeder nextFrame];
    return [self convertImage:originalImage];
}

// MARK: - Setter

- (void)setFrameFeeder:(id<TTARFrameFeeder>)frameFeeder {
    dispatch_async(_processQueue, ^{
        self->_frameFeeder = frameFeeder;
    });
}

- (void)setBlurRadius:(CGFloat)blurRadius {
    dispatch_async(_processQueue, ^{
        self->_blurRadius = blurRadius;
    });
}

- (void)setGamma:(CGFloat)gamma {
    dispatch_async(_processQueue, ^{
        self->_gamma = gamma;
    });
}
@end
