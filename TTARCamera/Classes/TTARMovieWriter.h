//
//  TTARMovieWriter.h
//  TTARCamera
//
//  Created by wenzhaot on 2019/7/10.
//

#import <AVFoundation/AVFoundation.h>

NS_ASSUME_NONNULL_BEGIN

@class TTARMovieWriter;
@protocol TTARMovieWriterDelegate <NSObject>
@optional
- (void)movieWriter:(TTARMovieWriter *)writer didFailed:(NSError *)error;
@end


@interface TTARMovieWriter : NSObject
@property (weak, nonatomic) id<TTARMovieWriterDelegate> delelgate;

- (instancetype)initWithMovieURL:(nullable NSURL *)movieURL size:(CGSize)size audioEnable:(BOOL)audioEnable;
- (void)appendAudioBuffer:(CMSampleBufferRef)sampleBuffer;
- (void)insertPixelBuffer:(CVPixelBufferRef)buffer time:(CMTime)time;
- (void)finishRecordingWithCompletionHandler:(void (^__nullable)(void))handler;
@end

NS_ASSUME_NONNULL_END
