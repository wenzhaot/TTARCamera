//
//  TTARImageFeeder.m
//  TTARCamera
//
//  Created by wenzhaot on 2019/7/9.
//

#import "TTARImageFeeder.h"

@interface TTARImageFeeder ()
@property (copy,   nonatomic) NSString *imagePrefix;
@property (copy,   nonatomic) NSString *imageDirectory;
@property (assign, nonatomic) NSUInteger numberOfImages;
@property (assign, nonatomic) NSUInteger currentIndex;
@end

@implementation TTARImageFeeder

+ (instancetype)feederWithDirectory:(NSString *)inDirectory count:(NSUInteger)count; {
    TTARImageFeeder *feeder = [[TTARImageFeeder alloc] init];
    feeder.imagePrefix = [inDirectory lastPathComponent];
    feeder.imageDirectory = inDirectory;
    feeder.numberOfImages = count;
    return feeder;
}

- (UIImage *)nextFrame {
    if (self.currentIndex >= self.numberOfImages) {
        self.currentIndex = 0;
    }
    
    NSString *path = [NSString stringWithFormat:@"%@/%@_%03lu.png", self.imageDirectory, self.imagePrefix, (unsigned long)self.currentIndex];
    self.currentIndex += 1;
    return [UIImage imageWithContentsOfFile:path];
}

@end
