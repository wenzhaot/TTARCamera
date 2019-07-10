//
//  TTARStickerPackage.h
//  TTARCamera
//
//  Created by wenzhaot on 2019/7/9.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@protocol TTARSticker;

@interface TTARStickerPackage : NSObject
@property (copy,   nonatomic) NSString *version;
@property (copy,   nonatomic) NSString *packageId;
@property (strong, nonatomic) NSDictionary *parts;
@property (strong, nonatomic) NSArray<id <TTARSticker>> *stickers;
@end

NS_ASSUME_NONNULL_END
