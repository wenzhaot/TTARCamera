//
//  TTARMovieWriter.m
//  TTARCamera
//
//  Created by wenzhaot on 2019/7/10.
//

#import "TTARMovieWriter.h"


@interface TTARMovieWriter ()
@property (strong, nonatomic) AVAssetWriter *assetWriter;
@property (strong, nonatomic) AVAssetWriterInput *videoInput;
@property (strong, nonatomic) AVAssetWriterInput *audioInput;

@property (strong, nonatomic) AVAssetWriterInputPixelBufferAdaptor *pixelBufferInput;
@property (strong, nonatomic) NSDictionary *videoOutputSettings;
@property (strong, nonatomic) NSDictionary *audioSettings;

@property (assign, nonatomic) BOOL isRecording;
@property (assign, nonatomic) BOOL isFinished;

@property (assign, nonatomic) CMTime startingVideoTime;
@end

@implementation TTARMovieWriter
- (instancetype)initWithMovieURL:(nullable NSURL *)movieURL size:(CGSize)size audioEnable:(BOOL)audioEnable
{
    self = [super init];
    if (self) {
        _startingVideoTime = kCMTimeInvalid;
        
        NSError *error = nil;
        _assetWriter = [[AVAssetWriter alloc] initWithURL:movieURL fileType:AVFileTypeMPEG4 error:&error];
        _assetWriter.shouldOptimizeForNetworkUse = YES;
        if (error != nil) {
            [self failedWithError:error];
        }
        
        if (audioEnable) {
            [self addAudioInputsAndOutputs];
        }
        
        NSMutableDictionary *settings = [[NSMutableDictionary alloc] init];
        [settings setObject:AVVideoCodecTypeH264 forKey:AVVideoCodecKey];
        [settings setObject:[NSNumber numberWithInt:size.width] forKey:AVVideoWidthKey];
        [settings setObject:[NSNumber numberWithInt:size.height] forKey:AVVideoHeightKey];
        _videoOutputSettings = settings;
        
        _videoInput = [[AVAssetWriterInput alloc] initWithMediaType:AVMediaTypeVideo outputSettings:_videoOutputSettings];
        _videoInput.expectsMediaDataInRealTime = YES;
        
        _pixelBufferInput = [[AVAssetWriterInputPixelBufferAdaptor alloc] initWithAssetWriterInput:_videoInput sourcePixelBufferAttributes:nil];
        
        if ([_assetWriter canAddInput:_videoInput]) {
            [_assetWriter addInput:_videoInput];
        } else {
            [self failedWithError:_assetWriter.error];
        }
        
    }
    return self;
}

- (void)addAudioInputsAndOutputs {
    AudioChannelLayout acl;
    bzero( &acl, sizeof(acl));
    acl.mChannelLayoutTag = kAudioChannelLayoutTag_Mono;
    
    _audioSettings = [NSDictionary dictionaryWithObjectsAndKeys:
                      [ NSNumber numberWithInt: kAudioFormatMPEG4AAC], AVFormatIDKey,
                      [ NSNumber numberWithInt: 1 ], AVNumberOfChannelsKey,
                      [ NSNumber numberWithFloat: 44100 ], AVSampleRateKey,
                      [ NSData dataWithBytes: &acl length: sizeof( acl ) ], AVChannelLayoutKey,
                      [ NSNumber numberWithInt: 64000 ], AVEncoderBitRateKey,
                      nil];
    
    _audioInput = [[AVAssetWriterInput alloc] initWithMediaType:AVMediaTypeAudio outputSettings:_audioSettings];
    _audioInput.expectsMediaDataInRealTime = YES;
    
    if ([_assetWriter canAddInput:_audioInput]) {
        [_assetWriter addInput:_audioInput];
    }
    
}

- (void)insertPixelBuffer:(CVPixelBufferRef)buffer time:(CMTime)time {
    if (_assetWriter.status == AVAssetWriterStatusUnknown)
    {
        if (CMTIME_IS_VALID(_startingVideoTime)) return;
        _startingVideoTime = time;
        
        if ([_assetWriter startWriting]) {
            [_assetWriter startSessionAtSourceTime:_startingVideoTime];
            [self setIsRecording:YES];
            [self setIsFinished:NO];
        } else {
            [self failedWithError:_assetWriter.error];
        }
    }
    else if (_assetWriter.status == AVAssetWriterStatusFailed)
    {
        [self failedWithError:_assetWriter.error];
        return;
    }
    
    if (_videoInput.isReadyForMoreMediaData && self.isRecording && !self.isFinished) {
        [_pixelBufferInput appendPixelBuffer:buffer withPresentationTime:time];
        [self setIsRecording:YES];
    }
}

- (void)finishRecordingWithCompletionHandler:(void (^__nullable)(void))handler {
    [self setIsFinished:YES];
    [_assetWriter finishWritingWithCompletionHandler:handler];
}

- (void)failedWithError:(NSError *)error {
    [self setIsRecording:NO];
    [self setIsFinished:NO];
    
    if ([self.delelgate respondsToSelector:@selector(movieWriter:didFailed:)]) {
        [self.delelgate movieWriter:self didFailed:error];
    }
}

- (void)appendAudioBuffer:(CMSampleBufferRef)sampleBuffer {
    if (_audioInput == nil) {
        return;
    }
    
    if (self.audioInput.isReadyForMoreMediaData && self.isRecording) {
        [self.audioInput appendSampleBuffer:sampleBuffer];
    }
}
@end
