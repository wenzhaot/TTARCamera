//
//  TTARStickerParser.m
//  TTARCamera
//
//  Created by wenzhaot on 2019/7/9.
//

#import "TTARStickerParser.h"
#import <YYModel/YYModel.h>
#import "TTARSticker.h"
#include "zip.h"
#include "unzip.h"

@interface NSData(TTARStickerParser)
- (NSString *)ttar_base64RFC4648;
- (NSString *)ttar_hexString;
@end

@interface NSString (TTARStickerParser)
- (NSString *)ttar_sanitizedPath;
@end



@implementation TTARStickerParser

+ (void)parseZip:(NSString *)zipPath packageId:(NSString *)packageId completionHandler:(void (^__nullable)(TTARStickerPackage *pack))handler {
    NSString *filename = [[zipPath lastPathComponent] stringByDeletingPathExtension];
    NSString *destination = [zipPath stringByDeletingLastPathComponent];
    NSString *zipDir = [destination stringByAppendingPathComponent:filename];
    
    if ([[NSFileManager defaultManager] fileExistsAtPath:zipDir]) {
        handler([self makePackageAtDirectory:zipDir identifier:packageId]);
        return;
    }
    
    [self unzipFileAtPath:zipPath toDestination:destination destinationName:filename progressHandler:^(NSString *entry, long entryNumber, long total) {
        
    } completionHandler:^(NSString *path, BOOL succeeded, NSError * _Nullable error) {
        TTARStickerPackage *pack = nil;
        if (succeeded) {
            pack = [self makePackageAtDirectory:zipDir identifier:packageId];
            
            // Remove zip file
            dispatch_async(dispatch_get_global_queue(0,0), ^{
                [[NSFileManager defaultManager] removeItemAtPath:zipPath error:nil];
            });
        } else {
            NSLog(@"unzip error: %@", error);
        }
        handler(pack);
    }];
}

+ (TTARStickerPackage *)makePackageAtDirectory:(NSString *)dir identifier:(NSString *)identifier {
    NSError *er = nil;
    TTARStickerPackage *pack = nil;
    
    NSString *configPath = [dir stringByAppendingPathComponent:@"config.json"];
    NSString *json = [NSString stringWithContentsOfFile:configPath encoding:NSUTF8StringEncoding error:&er];
    
    if (er == nil) {
        pack = [TTARStickerPackage yy_modelWithJSON:json];
        pack.stickers = [self makeStickersForPack:pack zipDir:dir];
        pack.packageId = identifier;
    } else {
        NSLog(@"config json file read error: %@", er);
    }
    
    return pack;
}

+ (NSArray<id <TTARSticker>> *)makeStickersForPack:(TTARStickerPackage *)pack zipDir:(NSString *)zipDir {
    NSMutableArray *array = [NSMutableArray arrayWithCapacity:pack.parts.count];
    for (NSString *key in pack.parts.allKeys) {
        id obj = [pack.parts objectForKey:key];
        if ([obj isKindOfClass:[NSDictionary class]])
        {
            id typeObj = [(NSDictionary *)obj objectForKey:@"type"];
            if ([typeObj respondsToSelector:@selector(integerValue)]) {
                switch ([typeObj integerValue]) {
                    case TTARStickerTypeFace: {
                        TTARNormalSticker *normal = [TTARNormalSticker yy_modelWithDictionary:obj];
                        normal.directory = zipDir;
                        normal.name = key;
                        [array addObject:normal];
                        break;
                    }
                        
                    case TTARStickerTypeDepth: {
                        TTARDepthSticker *depth = [TTARDepthSticker yy_modelWithDictionary:obj];
                        depth.directory = zipDir;
                        depth.name = key;
                        [array addObject:depth];
                        break;
                    }
                        
                    default:
                        break;
                }
            }
        }
        
    }
    
    return array;
}

// MARK: - UnZip

BOOL ttar_fileIsSymbolicLink(const unz_file_info *fileInfo)
{
    //
    // Determine whether this is a symbolic link:
    // - File is stored with 'version made by' value of UNIX (3),
    //   as per http://www.pkware.com/documents/casestudies/APPNOTE.TXT
    //   in the upper byte of the version field.
    // - BSD4.4 st_mode constants are stored in the high 16 bits of the
    //   external file attributes (defacto standard, verified against libarchive)
    //
    // The original constants can be found here:
    //    http://minnie.tuhs.org/cgi-bin/utree.pl?file=4.4BSD/usr/include/sys/stat.h
    //
    const uLong ZipUNIXVersion = 3;
    const uLong BSD_SFMT = 0170000;
    const uLong BSD_IFLNK = 0120000;
    
    BOOL fileIsSymbolicLink = ((fileInfo->version >> 8) == ZipUNIXVersion) && BSD_IFLNK == (BSD_SFMT & (fileInfo->external_fa >> 16));
    return fileIsSymbolicLink;
}

+ (NSCalendar *)ttar_gregorian
{
    static NSCalendar *gregorian;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        gregorian = [[NSCalendar alloc] initWithCalendarIdentifier:NSCalendarIdentifierGregorian];
    });
    
    return gregorian;
}

+ (NSString *)ttar_filenameStringWithCString:(const char *)filename
                             version_made_by:(uint16_t)version_made_by
                        general_purpose_flag:(uint16_t)flag
                                        size:(uint16_t)size_filename {
    
    // Respect Language encoding flag only reading filename as UTF-8 when this is set
    // when file entry created on dos system.
    //
    // https://pkware.cachefly.net/webdocs/casestudies/APPNOTE.TXT
    //   Bit 11: Language encoding flag (EFS).  If this bit is set,
    //           the filename and comment fields for this file
    //           MUST be encoded using UTF-8. (see APPENDIX D)
    uint16_t made_by = version_made_by >> 8;
    BOOL made_on_dos = made_by == 0;
    BOOL languageEncoding = (flag & (1 << 11)) != 0;
    if (!languageEncoding && made_on_dos) {
        // APPNOTE.TXT D.1:
        //   D.2 If general purpose bit 11 is unset, the file name and comment should conform
        //   to the original ZIP character encoding.  If general purpose bit 11 is set, the
        //   filename and comment must support The Unicode Standard, Version 4.1.0 or
        //   greater using the character encoding form defined by the UTF-8 storage
        //   specification.  The Unicode Standard is published by the The Unicode
        //   Consortium (www.unicode.org).  UTF-8 encoded data stored within ZIP files
        //   is expected to not include a byte order mark (BOM).
        
        //  Code Page 437 corresponds to kCFStringEncodingDOSLatinUS
        NSStringEncoding encoding = CFStringConvertEncodingToNSStringEncoding(kCFStringEncodingDOSLatinUS);
        NSString* strPath = [NSString stringWithCString:filename encoding:encoding];
        if (strPath) {
            return strPath;
        }
    }
    
    // attempting unicode encoding
    NSString * strPath = @(filename);
    if (strPath) {
        return strPath;
    }
    
    // if filename is non-unicode, detect and transform Encoding
    NSData *data = [NSData dataWithBytes:(const void *)filename length:sizeof(unsigned char) * size_filename];
    // Testing availability of @available (https://stackoverflow.com/a/46927445/1033581)
    [NSString stringEncodingForData:data encodingOptions:nil convertedString:&strPath usedLossyConversion:nil];
    if (strPath) {
        return strPath;
    }
    
    // if filename encoding is non-detected, we default to something based on data
    // _hexString is more readable than _base64RFC4648 for debugging unknown encodings
    strPath = [data ttar_hexString];
    return strPath;
}
    
// Format from http://newsgroups.derkeiler.com/Archive/Comp/comp.os.msdos.programmer/2009-04/msg00060.html
// Two consecutive words, or a longword, YYYYYYYMMMMDDDDD hhhhhmmmmmmsssss
// YYYYYYY is years from 1980 = 0
// sssss is (seconds/2).
//
// 3658 = 0011 0110 0101 1000 = 0011011 0010 11000 = 27 2 24 = 2007-02-24
// 7423 = 0111 0100 0010 0011 - 01110 100001 00011 = 14 33 3 = 14:33:06
+ (NSDate *)ttar_dateWithMSDOSFormat:(UInt32)msdosDateTime
{
    // the whole `_dateWithMSDOSFormat:` method is equivalent but faster than this one line,
    // essentially because `mktime` is slow:
    //NSDate *date = [NSDate dateWithTimeIntervalSince1970:dosdate_to_time_t(msdosDateTime)];
    static const UInt32 kYearMask = 0xFE000000;
    static const UInt32 kMonthMask = 0x1E00000;
    static const UInt32 kDayMask = 0x1F0000;
    static const UInt32 kHourMask = 0xF800;
    static const UInt32 kMinuteMask = 0x7E0;
    static const UInt32 kSecondMask = 0x1F;
    
    NSAssert(0xFFFFFFFF == (kYearMask | kMonthMask | kDayMask | kHourMask | kMinuteMask | kSecondMask), @"[SSZipArchive] MSDOS date masks don't add up");
    
    NSDateComponents *components = [[NSDateComponents alloc] init];
    components.year = 1980 + ((msdosDateTime & kYearMask) >> 25);
    components.month = (msdosDateTime & kMonthMask) >> 21;
    components.day = (msdosDateTime & kDayMask) >> 16;
    components.hour = (msdosDateTime & kHourMask) >> 11;
    components.minute = (msdosDateTime & kMinuteMask) >> 5;
    components.second = (msdosDateTime & kSecondMask) * 2;
    
    NSDate *date = [self.ttar_gregorian dateFromComponents:components];
    return date;
}
    
+ (BOOL)unzipFileAtPath:(NSString *)path
          toDestination:(NSString *)destination
        destinationName:(NSString *)destinationName
        progressHandler:(void (^_Nullable)(NSString *entry, long entryNumber, long total))progressHandler
      completionHandler:(void (^_Nullable)(NSString *path, BOOL succeeded, NSError * _Nullable error))completionHandler
{
    NSString *errorDomain = @"VKARStickerFactory.unzip";
    // Guard against empty strings
    if (path.length == 0 || destination.length == 0)
    {
        NSDictionary *userInfo = @{NSLocalizedDescriptionKey: @"received invalid argument(s)"};
        NSError *err = [NSError errorWithDomain:errorDomain code:999 userInfo:userInfo];
        if (completionHandler)
        {
            completionHandler(nil, NO, err);
        }
        return NO;
    }
    
    // Begin opening
    zipFile zip = unzOpen(path.fileSystemRepresentation);
    if (zip == NULL)
    {
        NSDictionary *userInfo = @{NSLocalizedDescriptionKey: @"failed to open zip file"};
        NSError *err = [NSError errorWithDomain:errorDomain code:999 userInfo:userInfo];
        if (completionHandler)
        {
            completionHandler(nil, NO, err);
        }
        return NO;
    }
    
    unsigned long long currentPosition = 0;
    
    unz_global_info globalInfo = {};
    unzGetGlobalInfo(zip, &globalInfo);
    
    // Begin unzipping
    int ret = 0;
    ret = unzGoToFirstFile(zip);
    if (ret != UNZ_OK && ret != UNZ_END_OF_LIST_OF_FILE)
    {
        NSDictionary *userInfo = @{NSLocalizedDescriptionKey: @"failed to open first file in zip file"};
        NSError *err = [NSError errorWithDomain:errorDomain code:999 userInfo:userInfo];
        if (completionHandler)
        {
            completionHandler(nil, NO, err);
        }
        return NO;
    }
    
    BOOL success = YES;
    int crc_ret = 0;
    unsigned char buffer[4096] = {0};
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSMutableArray<NSDictionary *> *directoriesModificationDates = [[NSMutableArray alloc] init];
    
    
    NSInteger currentFileNumber = -1;
    NSError *unzippingError;
    do {
        currentFileNumber++;
        if (ret == UNZ_END_OF_LIST_OF_FILE) {
            break;
        }
        @autoreleasepool {
            ret = unzOpenCurrentFile(zip);
            
            if (ret != UNZ_OK) {
                unzippingError = [NSError errorWithDomain:errorDomain code:999 userInfo:@{NSLocalizedDescriptionKey: @"failed to open file in zip file"}];
                success = NO;
                break;
            }
            
            // Reading data and write to file
            unz_file_info fileInfo;
            memset(&fileInfo, 0, sizeof(unz_file_info));
            
            ret = unzGetCurrentFileInfo(zip, &fileInfo, NULL, 0, NULL, 0, NULL, 0);
            if (ret != UNZ_OK) {
                unzippingError = [NSError errorWithDomain:errorDomain code:999 userInfo:@{NSLocalizedDescriptionKey: @"failed to retrieve info for file"}];
                success = NO;
                unzCloseCurrentFile(zip);
                break;
            }
            
            currentPosition += fileInfo.compressed_size;
            
            
            char *filename = (char *)malloc(fileInfo.size_filename + 1);
            if (filename == NULL)
            {
                success = NO;
                break;
            }
            
            unzGetCurrentFileInfo(zip, &fileInfo, filename, fileInfo.size_filename + 1, NULL, 0, NULL, 0);
            filename[fileInfo.size_filename] = '\0';
            
            BOOL fileIsSymbolicLink = ttar_fileIsSymbolicLink(&fileInfo);
            
            NSString * strPath = [TTARStickerParser ttar_filenameStringWithCString:filename
                                                                   version_made_by:fileInfo.version
                                                              general_purpose_flag:fileInfo.flag
                                                                              size:fileInfo.size_filename];
            if ([strPath hasPrefix:@"__MACOSX/"]) {
                // ignoring resource forks: https://superuser.com/questions/104500/what-is-macosx-folder
                unzCloseCurrentFile(zip);
                ret = unzGoToNextFile(zip);
                free(filename);
                continue;
            }
            
            // Check if it contains directory
            BOOL isDirectory = NO;
            if (filename[fileInfo.size_filename-1] == '/' || filename[fileInfo.size_filename-1] == '\\') {
                isDirectory = YES;
            }
            free(filename);
            
            // Sanitize paths in the file name.
            strPath = [strPath ttar_sanitizedPath];
            if (!strPath.length) {
                // if filename data is unsalvageable, we default to currentFileNumber
                strPath = @(currentFileNumber).stringValue;
            }
            
            if (destinationName) {
                NSRange range = [strPath rangeOfString:@"/"];
                if (range.location != NSNotFound) {
                    range = NSMakeRange(0, range.location);
                    strPath = [strPath stringByReplacingCharactersInRange:range withString:destinationName];
                }
            }
            
            NSString *fullPath = [destination stringByAppendingPathComponent:strPath];
            
            NSError *err = nil;
            NSDictionary *directoryAttr;
            NSDate *modDate = [[self class] ttar_dateWithMSDOSFormat:(UInt32)fileInfo.dosDate];
            directoryAttr = @{NSFileCreationDate: modDate, NSFileModificationDate: modDate};
            [directoriesModificationDates addObject: @{@"path": fullPath, @"modDate": modDate}];
            
            if (isDirectory) {
                [fileManager createDirectoryAtPath:fullPath withIntermediateDirectories:YES attributes:directoryAttr error:&err];
            } else {
                [fileManager createDirectoryAtPath:fullPath.stringByDeletingLastPathComponent withIntermediateDirectories:YES attributes:directoryAttr error:&err];
            }
            if (err != nil) {
                if ([err.domain isEqualToString:NSCocoaErrorDomain] &&
                    err.code == 640) {
                    unzippingError = err;
                    unzCloseCurrentFile(zip);
                    success = NO;
                    break;
                }
                NSLog(@"[SSZipArchive] Error: %@", err.localizedDescription);
            }
            
            if (isDirectory && !fileIsSymbolicLink) {
                // nothing to read/write for a directory
            } else if (!fileIsSymbolicLink) {
                // ensure we are not creating stale file entries
                int readBytes = unzReadCurrentFile(zip, buffer, 4096);
                if (readBytes >= 0) {
                    FILE *fp = fopen(fullPath.fileSystemRepresentation, "wb");
                    while (fp) {
                        if (readBytes > 0) {
                            if (0 == fwrite(buffer, readBytes, 1, fp)) {
                                if (ferror(fp)) {
                                    NSString *message = [NSString stringWithFormat:@"Failed to write file (check your free space)"];
                                    NSLog(@"[SSZipArchive] %@", message);
                                    success = NO;
                                    unzippingError = [NSError errorWithDomain:errorDomain code:999 userInfo:@{NSLocalizedDescriptionKey: message}];
                                    break;
                                }
                            }
                        } else {
                            break;
                        }
                        readBytes = unzReadCurrentFile(zip, buffer, 4096);
                        if (readBytes < 0) {
                            // Let's assume error Z_DATA_ERROR is caused by an invalid password
                            // Let's assume other errors are caused by Content Not Readable
                            success = NO;
                        }
                    }
                    
                    if (fp) {
                        fclose(fp);
                        
                        // Set the original datetime property
                        if (fileInfo.dosDate != 0) {
                            NSDate *orgDate = [[self class] ttar_dateWithMSDOSFormat:(UInt32)fileInfo.dosDate];
                            NSDictionary *attr = @{NSFileModificationDate: orgDate};
                            
                            if (attr) {
                                if (![fileManager setAttributes:attr ofItemAtPath:fullPath error:nil]) {
                                    // Can't set attributes
                                    NSLog(@"[SSZipArchive] Failed to set attributes - whilst setting modification date");
                                }
                            }
                        }
                        
                        // Set the original permissions on the file (+read/write to solve #293)
                        uLong permissions = fileInfo.external_fa >> 16 | 0b110000000;
                        if (permissions != 0) {
                            // Store it into a NSNumber
                            NSNumber *permissionsValue = @(permissions);
                            
                            // Retrieve any existing attributes
                            NSMutableDictionary *attrs = [[NSMutableDictionary alloc] initWithDictionary:[fileManager attributesOfItemAtPath:fullPath error:nil]];
                            
                            // Set the value in the attributes dict
                            [attrs setObject:permissionsValue forKey:NSFilePosixPermissions];
                            
                            // Update attributes
                            if (![fileManager setAttributes:attrs ofItemAtPath:fullPath error:nil]) {
                                // Unable to set the permissions attribute
                                NSLog(@"[SSZipArchive] Failed to set attributes - whilst setting permissions");
                            }
                        }
                    }
                    else
                    {
                        // if we couldn't open file descriptor we can validate global errno to see the reason
                        if (errno == ENOSPC) {
                            NSError *enospcError = [NSError errorWithDomain:NSPOSIXErrorDomain
                                                                       code:ENOSPC
                                                                   userInfo:nil];
                            unzippingError = enospcError;
                            unzCloseCurrentFile(zip);
                            success = NO;
                            break;
                        }
                    }
                } else {
                    // Let's assume error Z_DATA_ERROR is caused by an invalid password
                    // Let's assume other errors are caused by Content Not Readable
                    success = NO;
                    break;
                }
            }
            else
            {
                // Assemble the path for the symbolic link
                NSMutableString *destinationPath = [NSMutableString string];
                int bytesRead = 0;
                while ((bytesRead = unzReadCurrentFile(zip, buffer, 4096)) > 0)
                {
                    buffer[bytesRead] = 0;
                    [destinationPath appendString:@((const char *)buffer)];
                }
                if (bytesRead < 0) {
                    // Let's assume error Z_DATA_ERROR is caused by an invalid password
                    // Let's assume other errors are caused by Content Not Readable
                    success = NO;
                    break;
                }
                
                // Check if the symlink exists and delete it if we're overwriting
                if ([fileManager fileExistsAtPath:fullPath])
                {
                    NSError *error = nil;
                    BOOL removeSuccess = [fileManager removeItemAtPath:fullPath error:&error];
                    if (!removeSuccess)
                    {
                        NSString *message = [NSString stringWithFormat:@"Failed to delete existing symbolic link at \"%@\"", error.localizedDescription];
                        NSLog(@"[SSZipArchive] %@", message);
                        success = NO;
                        unzippingError = [NSError errorWithDomain:errorDomain code:error.code userInfo:@{NSLocalizedDescriptionKey: message}];
                    }
                }
                
                // Create the symbolic link (making sure it stays relative if it was relative before)
                int symlinkError = symlink([destinationPath cStringUsingEncoding:NSUTF8StringEncoding],
                                           [fullPath cStringUsingEncoding:NSUTF8StringEncoding]);
                
                if (symlinkError != 0)
                {
                    // Bubble the error up to the completion handler
                    NSString *message = [NSString stringWithFormat:@"Failed to create symbolic link at \"%@\" to \"%@\" - symlink() error code: %d", fullPath, destinationPath, errno];
                    NSLog(@"[SSZipArchive] %@", message);
                    success = NO;
                    unzippingError = [NSError errorWithDomain:NSPOSIXErrorDomain code:symlinkError userInfo:@{NSLocalizedDescriptionKey: message}];
                }
            }
            
            crc_ret = unzCloseCurrentFile(zip);
            if (crc_ret == UNZ_CRCERROR) {
                // CRC ERROR
                success = NO;
                break;
            }
            ret = unzGoToNextFile(zip);
            
            if (progressHandler)
            {
                progressHandler(strPath, currentFileNumber, globalInfo.number_entry);
            }
        }
    } while (ret == UNZ_OK && success);
    
    // Close
    unzClose(zip);
    
    // The process of decompressing the .zip archive causes the modification times on the folders
    // to be set to the present time. So, when we are done, they need to be explicitly set.
    // set the modification date on all of the directories.
    if (success) {
        NSError * err = nil;
        for (NSDictionary * d in directoriesModificationDates) {
            if (![[NSFileManager defaultManager] setAttributes:@{NSFileModificationDate: [d objectForKey:@"modDate"]} ofItemAtPath:[d objectForKey:@"path"] error:&err]) {
                NSLog(@"[SSZipArchive] Set attributes failed for directory: %@.", [d objectForKey:@"path"]);
            }
            if (err) {
                NSLog(@"[SSZipArchive] Error setting directory file modification date attribute: %@", err.localizedDescription);
            }
        }
    }
    
    NSError *retErr = nil;
    if (crc_ret == UNZ_CRCERROR)
    {
        NSDictionary *userInfo = @{NSLocalizedDescriptionKey: @"crc check failed for file"};
        retErr = [NSError errorWithDomain:errorDomain code:999 userInfo:userInfo];
    }
    
    if (completionHandler)
    {
        if (unzippingError) {
            completionHandler(path, success, unzippingError);
        }
        else
        {
            completionHandler(path, success, retErr);
        }
    }
    return success;
}

@end
    
    
#pragma mark - Private tools for unreadable encodings
    
@implementation NSData (TTARStickerParser)

// `base64EncodedStringWithOptions` uses a base64 alphabet with '+' and '/'.
// we got those alternatives to make it compatible with filenames: https://en.wikipedia.org/wiki/Base64
// * modified Base64 encoding for IMAP mailbox names (RFC 3501): uses '+' and ','
// * modified Base64 for URL and filenames (RFC 4648): uses '-' and '_'
- (NSString *)ttar_base64RFC4648
{
    NSString *strName = [self base64EncodedStringWithOptions:0];
    strName = [strName stringByReplacingOccurrencesOfString:@"+" withString:@"-"];
    strName = [strName stringByReplacingOccurrencesOfString:@"/" withString:@"_"];
    return strName;
}

// initWithBytesNoCopy from NSProgrammer, Jan 25 '12: https://stackoverflow.com/a/9009321/1033581
// hexChars from Peter, Aug 19 '14: https://stackoverflow.com/a/25378464/1033581
// not implemented as too lengthy: a potential mapping improvement from Moose, Nov 3 '15: https://stackoverflow.com/a/33501154/1033581
- (NSString *)ttar_hexString
{
    const char *hexChars = "0123456789ABCDEF";
    NSUInteger length = self.length;
    const unsigned char *bytes = self.bytes;
    char *chars = malloc(length * 2);
    if (chars == NULL) {
        // we directly raise an exception instead of using NSAssert to make sure assertion is not disabled as this is irrecoverable
        [NSException raise:@"NSInternalInconsistencyException" format:@"failed malloc" arguments:nil];
        return nil;
    }
    char *s = chars;
    NSUInteger i = length;
    while (i--) {
        *s++ = hexChars[*bytes >> 4];
        *s++ = hexChars[*bytes & 0xF];
        bytes++;
    }
    NSString *str = [[NSString alloc] initWithBytesNoCopy:chars
                                                   length:length * 2
                                                 encoding:NSASCIIStringEncoding
                                             freeWhenDone:YES];
    return str;
}

@end
    
#pragma mark Private tools for security
    
@implementation NSString (TTARStickerParser)

// One implementation alternative would be to use the algorithm found at mz_path_resolve from https://github.com/nmoinvaz/minizip/blob/dev/mz_os.c,
// but making sure to work with unichar values and not ascii values to avoid breaking Unicode characters containing 2E ('.') or 2F ('/') in their decomposition
/// Sanitize path traversal characters to prevent directory backtracking. Ignoring these characters mimicks the default behavior of the Unarchiving tool on macOS.
- (NSString *)ttar_sanitizedPath
{
    // Change Windows paths to Unix paths: https://en.wikipedia.org/wiki/Path_(computing)
    // Possible improvement: only do this if the archive was created on a non-Unix system
    NSString *strPath = [self stringByReplacingOccurrencesOfString:@"\\" withString:@"/"];
    
    // Percent-encode file path (where path is defined by https://tools.ietf.org/html/rfc8089)
    // The key part is to allow characters "." and "/" and disallow "%".
    // CharacterSet.urlPathAllowed seems to do the job
    // Testing availability of @available (https://stackoverflow.com/a/46927445/1033581)
    strPath = [strPath stringByAddingPercentEncodingWithAllowedCharacters:NSCharacterSet.URLPathAllowedCharacterSet];
    
    // `NSString.stringByAddingPercentEncodingWithAllowedCharacters:` may theorically fail: https://stackoverflow.com/questions/33558933/
    // But because we auto-detect encoding using `NSString.stringEncodingForData:encodingOptions:convertedString:usedLossyConversion:`,
    // we likely already prevent UTF-16, UTF-32 and invalid Unicode in the form of unpaired surrogate chars: https://stackoverflow.com/questions/53043876/
    // To be on the safe side, we will still perform a guard check.
    if (strPath == nil) {
        return nil;
    }
    
    // Add scheme "file:///" to support sanitation on names with a colon like "file:a/../../../usr/bin"
    strPath = [@"file:///" stringByAppendingString:strPath];
    
    // Sanitize path traversal characters to prevent directory backtracking. Ignoring these characters mimicks the default behavior of the Unarchiving tool on macOS.
    // "../../../../../../../../../../../tmp/test.txt" -> "tmp/test.txt"
    // "a/b/../c.txt" -> "a/c.txt"
    strPath = [NSURL URLWithString:strPath].standardizedURL.absoluteString;
    
    // Remove the "file:///" scheme
    strPath = [strPath substringFromIndex:8];
    
    // Remove the percent-encoding
    // Testing availability of @available (https://stackoverflow.com/a/46927445/1033581)
    strPath = strPath.stringByRemovingPercentEncoding;
    
    return strPath;
}

@end
