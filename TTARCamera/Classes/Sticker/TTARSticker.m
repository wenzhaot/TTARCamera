//
//  TTARSticker.m
//  TTARCamera
//
//  Created by wenzhaot on 2019/7/9.
//

#import "TTARSticker.h"
#import "TTARImageFeeder.h"
#import "TTARVideoFeeder.h"

@implementation TTARDepthSticker
@synthesize directory = _directory;
@synthesize name = _name;

+ (NSArray *)modelPropertyBlacklist {
    return @[@"directory"];
}

- (id<TTARFrameFeeder>)frameFeeder {
    id<TTARFrameFeeder> feeder = nil;
    switch (self.resType) {
        case 0: {
            NSString *path = [self.directory stringByAppendingPathComponent:_name];
            feeder = [TTARImageFeeder feederWithDirectory:path count:self.frameCount];
            break;
        }
        case 1: {
            NSString *filename = [NSString stringWithFormat:@"%@.mp4", _name];
            NSString *path = [self.directory stringByAppendingPathComponent:_name];
            path = [path stringByAppendingPathComponent:filename];
            feeder = [TTARVideoFeeder feederWithFilePath:path];
            break;
        }
            
        default:
            break;
    }
    
    return feeder;
}

- (TTARStickerType)type { return TTARStickerTypeDepth; }

@end



@implementation TTARStickerVector
@end



@implementation TTARNormalSticker
@synthesize directory = _directory;
@synthesize name = _name;
@synthesize node = _node;

+ (NSArray *)modelPropertyBlacklist {
    return @[@"directory", @"node"];
}

- (TTARStickerType)type { return TTARStickerTypeFace; }

- (UIImage *)firstImage {
    return [self imageAtIndex:0];
}

- (SCNVector3)vector3Position {
    return SCNVector3Make(self.position.x, self.position.y, self.position.z);
}

- (SCNVector3)vector3Scale {
    return SCNVector3Make(self.scale.x, self.scale.y, self.scale.z);
}

- (SCNNode *)node {
    if (!_node) {
        SCNPlane *plane = [SCNPlane planeWithWidth:self.width height:self.height];
        plane.firstMaterial.diffuse.contents = [self firstImage];
        
        SCNNode *node = [SCNNode nodeWithGeometry:plane];
        node.position = [self vector3Position];
        node.scale = [self vector3Scale];
        node.opacity = self.opacity;
        node.renderingOrder = self.renderingOrder;
        node.castsShadow = self.castsShadow;
        node.name = self.name;
        
        _node = node;
    }
    return _node;
}

- (UIImage *)imageAtIndex:(NSUInteger)index {
    if (index >= self.frameCount) {
        return nil;
    }
    
    NSString *filename = [NSString stringWithFormat:@"%@_%03lu.png", _name, (unsigned long)index];
    NSString *directory = [self.directory stringByAppendingPathComponent:_name];
    NSString *path = [directory stringByAppendingPathComponent:filename];
    return [UIImage imageWithContentsOfFile:path];
}

- (void)runAnimationIfNeeded {
    NSUInteger count = self.frameCount;
    if (count == 1) {
        return;
    }
    
    __weak typeof(self)weakSelf = self;
    
    SCNAction *action = [SCNAction customActionWithDuration:self.duration actionBlock:^(SCNNode * _Nonnull node, CGFloat elapsedTime) {
        CGFloat percent = elapsedTime / weakSelf.duration;
        NSUInteger index = MIN(count - 1, count*percent);
        node.geometry.firstMaterial.diffuse.contents = [weakSelf imageAtIndex:index];
    }];
    
    if (self.loopCount == -1) {
        [self.node runAction:[SCNAction repeatActionForever:action]];
    } else {
        [self.node runAction:[SCNAction repeatAction:action count:self.loopCount]];
    }
}

@end
