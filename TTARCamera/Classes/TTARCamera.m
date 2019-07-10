//
//  TTARCamera.m
//  TTARCamera
//
//  Created by wenzhaot on 2019/7/10.
//

#import "TTARCamera.h"
#import "TTARSticker.h"
#import "TTARFrameFeeder.h"
#import "TTARBackgroundRender.h"

@interface TTARCamera () <ARSCNViewDelegate, ARSessionDelegate>
@property (strong, nonatomic) SCNNode *contentNode;
@property (strong, nonatomic) SCNNode *occlusionNode;
@property (strong, nonatomic) NSMutableDictionary *packageMap;
@end

@implementation TTARCamera
@synthesize backgroundRender = _backgroundRender;

- (instancetype)init
{
    self = [super init];
    if (self) {
        [self commonInit];
    }
    return self;
}

- (void)commonInit {
    _sceneView = [[ARSCNView alloc] initWithFrame:[UIScreen mainScreen].bounds];
    _sceneView.delegate = self;
    _sceneView.session.delegate = self;
    
    _configuration = [[ARFaceTrackingConfiguration alloc] init];
    for (ARVideoFormat *vf in ARFaceTrackingConfiguration.supportedVideoFormats) {
        if (CGSizeEqualToSize(vf.imageResolution, CGSizeMake(1280, 720)) && vf.framesPerSecond == 60) {
            _configuration.videoFormat = vf;
            break;
        }
    }
}

- (BOOL)startRunning {
    if (![[self.configuration class] isSupported]) {
        return NO;
    }
    
    ARSessionRunOptions options = ARSessionRunOptionResetTracking | ARSessionRunOptionRemoveExistingAnchors;
    [_sceneView.session runWithConfiguration:self.configuration options:options];
    
    return YES;
}

- (void)stopRunning {
    [_sceneView.session pause];
}

// MARK: - ARSessionDelegate

- (void)session:(ARSession *)session didFailWithError:(NSError *)error {
    
}

- (void)session:(ARSession *)session didUpdateFrame:(ARFrame *)frame {
    [self.backgroundRender updateFrame:frame inScene:self.sceneView];
}

- (void)session:(ARSession *)session didOutputAudioSampleBuffer:(CMSampleBufferRef)audioSampleBuffer {
    if (self.audioBufferHandler) {
        self.audioBufferHandler(audioSampleBuffer);
    }
}

// MARK: - ARSCNViewDelegate


- (SCNNode *)renderer:(id<SCNSceneRenderer>)renderer nodeForAnchor:(ARAnchor *)anchor {
    if ([renderer isKindOfClass:[ARSCNView class]] && [anchor isKindOfClass:[ARFaceAnchor class]]) {
        return self.contentNode;
    }
    return nil;
}

- (void)renderer:(id<SCNSceneRenderer>)renderer didAddNode:(SCNNode *)node forAnchor:(ARAnchor *)anchor {
    
}

- (void)renderer:(id<SCNSceneRenderer>)renderer didUpdateNode:(SCNNode *)node forAnchor:(ARAnchor *)anchor {
    if ([self.occlusionNode.geometry isKindOfClass:[ARSCNFaceGeometry class]] && [anchor isKindOfClass:[ARFaceAnchor class]])
    {
        ARFaceAnchor *faceAnchor = (ARFaceAnchor *)anchor;
        ARSCNFaceGeometry *faceGeometry = (ARSCNFaceGeometry *)self.occlusionNode.geometry;
        [faceGeometry updateFromFaceGeometry:faceAnchor.geometry];
    }
}

// MARK: - Setter

- (void)setBackgroundFeeder:(id<TTARFrameFeeder>)backgroundFeeder {
    _backgroundFeeder = backgroundFeeder;
    self.backgroundRender.frameFeeder = backgroundFeeder;
}

- (void)setAudioBufferHandler:(void (^)(CMSampleBufferRef _Nonnull))audioBufferHandler {
    _audioBufferHandler = audioBufferHandler;
    _configuration.providesAudioData = audioBufferHandler != nil;
}

- (void)setOutputImageOrientation:(UIInterfaceOrientation)outputImageOrientation {
    _outputImageOrientation = outputImageOrientation;
    _backgroundRender.orientation = outputImageOrientation;
}

// MARK: - Getter

- (NSMutableDictionary *)packageMap {
    if (!_packageMap) {
        _packageMap = [NSMutableDictionary dictionary];
    }
    return _packageMap;
}

- (SCNNode *)occlusionNode {
#if TARGET_IPHONE_SIMULATOR
    return nil;
#else
    if (!_occlusionNode) {
        ARSCNFaceGeometry *faceGeometry = [ARSCNFaceGeometry faceGeometryWithDevice:_sceneView.device];
        faceGeometry.firstMaterial.colorBufferWriteMask = SCNColorMaskNone;
        
        _occlusionNode = [SCNNode nodeWithGeometry:faceGeometry];
        _occlusionNode.renderingOrder = -1;
    }
    return _occlusionNode;
#endif
}


- (SCNNode *)contentNode {
    if (!_contentNode) {
        _contentNode = [SCNNode node];
        [_contentNode addChildNode:self.occlusionNode];
    }
    return _contentNode;
}

- (TTARBackgroundRender *)backgroundRender {
    if (!_backgroundRender) {
        _backgroundRender = [[TTARBackgroundRender alloc] init];
        _backgroundRender.orientation = self.outputImageOrientation;
    }
    return _backgroundRender;
}


// MARK: - Sticker Package

- (void)updateSticker:(id<TTARSticker>)sticker {
    switch (sticker.type) {
        case TTARStickerTypeDepth: {
            TTARDepthSticker *depth = (TTARDepthSticker *)sticker;
            self.backgroundFeeder = [depth frameFeeder];
            self.backgroundRender.blurRadius = depth.blurRadius;
            self.backgroundRender.gamma = depth.gamma;
            break;
        }
        
        case TTARStickerTypeFace: {
            TTARNormalSticker *normal = (TTARNormalSticker *)sticker;
            if (normal.resType == 0)
            {
                ARSCNFaceGeometry *faceGeometry = (ARSCNFaceGeometry *)self.occlusionNode.geometry;
                SCNMaterial *material = faceGeometry.firstMaterial;
                material.lightingModelName = SCNLightingModelPhysicallyBased;
                material.colorBufferWriteMask = SCNColorMaskAll;
                material.diffuse.contents = [normal firstImage];
            }
            else if (normal.resType == 1)
            {
                [self.contentNode addChildNode:normal.node];
                [normal runAnimationIfNeeded];
            }
            break;
        }
        
    }
}

- (void)removeStiker:(id<TTARSticker>)sticker {
    switch (sticker.type) {
        case TTARStickerTypeDepth:
        self.backgroundFeeder = nil;
        break;
        
        case TTARStickerTypeFace: {
            TTARNormalSticker *normal = (TTARNormalSticker *)sticker;
            if (normal.resType == 0)
            {
                ARSCNFaceGeometry *faceGeometry = (ARSCNFaceGeometry *)self.occlusionNode.geometry;
                SCNMaterial *material = faceGeometry.firstMaterial;
                material.lightingModelName = SCNLightingModelBlinn;
                material.colorBufferWriteMask = SCNColorMaskNone;
                material.diffuse.contents = nil;
            }
            else if (normal.resType == 1)
            {
                [normal.node removeFromParentNode];
            }
            break;
        }
    }
}

- (void)addStickerPackage:(TTARStickerPackage *)pack {
    if (pack == nil) { return; }
    
    [self.packageMap setObject:pack forKey:pack.packageId];
    [pack.stickers enumerateObjectsUsingBlock:^(id<TTARSticker>  _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        [self updateSticker:obj];
    }];
}

- (void)removePackageById:(NSString *)packageId {
    if (packageId == nil) { return; }
    
    TTARStickerPackage *pack = [self.packageMap objectForKey:packageId];
    [pack.stickers enumerateObjectsUsingBlock:^(id<TTARSticker>  _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        [self removeStiker:obj];
    }];
    
    [self.packageMap removeObjectForKey:packageId];
}
@end
