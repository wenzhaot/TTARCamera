//
//  TTCIFilterConstructor.m
//  TTARCamera
//
//  Created by wenzhaot on 2019/7/9.
//

#import "TTCIFilterConstructor.h"

@implementation TTCIFilterConstructor
+ (instancetype)constructor {
    static TTCIFilterConstructor *constructor;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        constructor = [[TTCIFilterConstructor alloc] initForSharedConstructor];
    });
    return constructor;
}

- (instancetype)initForSharedConstructor {
    if (self = [super init]) {}
    return self;
}

- (CIFilter *)filterWithName:(NSString *)name {
    return [[NSClassFromString(name) alloc] init];
}
@end
