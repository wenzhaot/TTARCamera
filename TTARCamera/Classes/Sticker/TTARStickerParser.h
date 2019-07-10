//
//  TTARStickerParser.h
//  TTARCamera
//
//  Created by wenzhaot on 2019/7/9.
//

#import <Foundation/Foundation.h>
#import "TTARStickerPackage.h"

NS_ASSUME_NONNULL_BEGIN

@interface TTARStickerParser : NSObject

+ (void)parseZip:(NSString *)zipPath packageId:(NSString *)packageId completionHandler:(void (^__nullable)(TTARStickerPackage *pack))handler;

@end

NS_ASSUME_NONNULL_END
