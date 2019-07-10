//
//  TTARVideoFeeder.m
//  TTARCamera
//
//  Created by wenzhaot on 2019/7/9.
//

#import "TTARVideoFeeder.h"
#import <AVFoundation/AVFoundation.h>

@interface TTARVideoFeeder ()
@property (strong, nonatomic) AVAsset *asset;
@property (strong, nonatomic) AVAssetReader *reader;
@property (strong, nonatomic) AVAssetReaderTrackOutput *trackOutput;
@property (strong, nonatomic) UIImage *lastRenderImage;
@property (assign, getter=isStarted, nonatomic) BOOL started;
@end

@implementation TTARVideoFeeder

- (void)dealloc {
    [self destroyReader];
}

+ (instancetype)feederWithFilePath:(NSString *)path {
    TTARVideoFeeder *feeder = [[TTARVideoFeeder alloc] init];
    feeder.asset = [AVAsset assetWithURL:[NSURL fileURLWithPath:path]];
    return feeder;
}

- (nullable UIImage *)nextFrame {
    if (!self.isStarted) {
        [self createReader];
        [self.reader startReading];
        [self setStarted:YES];
    }
    
    switch (self.reader.status) {
        case AVAssetReaderStatusReading: {
            CMSampleBufferRef buffer = [self.trackOutput copyNextSampleBuffer];
            UIImage *image = [self imageFromSampleBuffer:buffer];
            if (image == nil) {
                image = self.lastRenderImage;
            } else {
                self.lastRenderImage = image;
            }
            return image;
        }
            
        case AVAssetReaderStatusCompleted:
            [self setStarted:NO];
            break;
            
        case AVAssetReaderStatusFailed:
            [self setStarted:NO];
            NSLog(@"AVAssetReaderStatusFailed : %@", self.reader.error.localizedDescription);
            return self.lastRenderImage;
            
        case AVAssetReaderStatusCancelled:
            
            break;
            
        case AVAssetReaderStatusUnknown:
            break;
    }
    
    return nil;
}

- (void)createReader {
    [self destroyReader];
    
    NSError *error = nil;
    _reader = [[AVAssetReader alloc] initWithAsset:_asset error:&error];
    
    if (error) {
        NSLog(@"AVAssetReader alloc error: %@", error.localizedDescription);
    } else {
        [self addVideoOutput];
    }
}

- (void)addVideoOutput {
    AVAssetTrack *videoTrack = [self.asset tracksWithMediaType:AVMediaTypeVideo].firstObject;
    NSMutableDictionary* dictionary = [[NSMutableDictionary alloc] init];
    [dictionary setObject:[NSNumber numberWithInt:kCVPixelFormatType_32BGRA] forKey:(NSString*)kCVPixelBufferPixelFormatTypeKey];
    
    self.trackOutput = [[AVAssetReaderTrackOutput alloc] initWithTrack:videoTrack outputSettings:dictionary];
    
    if ([self.reader canAddOutput:self.trackOutput]) {
        [self.reader addOutput:self.trackOutput];
    } else {
        NSLog(@"AVAssetReader cannot add output");
    }
    
}

- (void)destroyReader {
    [_reader cancelReading];
    _reader = nil;
}

- (UIImage *)imageFromSampleBuffer:(CMSampleBufferRef)sampleBuffer
{
    @autoreleasepool {
        if (sampleBuffer == NULL) {
            return nil;
        }
        
        CVImageBufferRef imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);
        /*Lock the image buffer*/
        CVPixelBufferLockBaseAddress(imageBuffer,0);
        /*Get information about the image*/
        uint8_t *baseAddress = (uint8_t *)CVPixelBufferGetBaseAddress(imageBuffer);
        size_t bytesPerRow = CVPixelBufferGetBytesPerRow(imageBuffer);
        size_t width = CVPixelBufferGetWidth(imageBuffer);
        size_t height = CVPixelBufferGetHeight(imageBuffer);
        
        /*Create a CGImageRef from the CVImageBufferRef*/
        CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
        CGContextRef newContext = CGBitmapContextCreate(baseAddress, width, height, 8, bytesPerRow, colorSpace, kCGBitmapByteOrder32Little | kCGImageAlphaPremultipliedFirst);
        CGImageRef newImage = CGBitmapContextCreateImage(newContext);
        
        /*We release some components*/
        CGContextRelease(newContext);
        CGColorSpaceRelease(colorSpace);
        
        
        /*We display the result on the image view (We need to change the orientation of the image so that the video is displayed correctly).
         Same thing as for the CALayer we are not in the main thread so ...*/
        UIImage *image= [UIImage imageWithCGImage:newImage scale:1.0 orientation:UIImageOrientationUp];
        
        /*We relase the CGImageRef*/
        CGImageRelease(newImage);
        
        /*We unlock the  image buffer*/
        CVPixelBufferUnlockBaseAddress(imageBuffer,0);
        CFRelease(sampleBuffer);
        
        return image;
    }
}

@end
