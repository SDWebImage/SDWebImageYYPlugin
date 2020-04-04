/*
 * This file is part of the SDWebImage-YYCache package.
 *
 * For the full copyright and license information, please view the LICENSE
 * file that was distributed with this source code.
 */


#import "YYCache+SDAdditions.h"
#import "YYMemoryCache+SDAdditions.h"
#import "YYDiskCache+SDAdditions.h"

static NSData * SDYYPluginCacheDataWithImageData(UIImage *image, NSData *imageData) {
    NSData *data = imageData;
    if (!data && [image conformsToProtocol:@protocol(SDAnimatedImage)]) {
        // If image is custom animated image class, prefer its original animated data
        data = [((id<SDAnimatedImage>)image) animatedImageData];
    }
    if (!data && image) {
        // Check image's associated image format, may return .undefined
        SDImageFormat format = image.sd_imageFormat;
        if (format == SDImageFormatUndefined) {
            // If image is animated, use GIF (APNG may be better, but has bugs before macOS 10.14)
            if (image.sd_isAnimated) {
                format = SDImageFormatGIF;
            } else {
                // If we do not have any data to detect image format, check whether it contains alpha channel to use PNG or JPEG format
                if ([SDImageCoderHelper CGImageContainsAlpha:image.CGImage]) {
                    format = SDImageFormatPNG;
                } else {
                    format = SDImageFormatJPEG;
                }
            }
        }
        data = [[SDImageCodersManager sharedManager] encodedDataWithImage:image format:format options:nil];
    }
    
    return data;
}

@implementation YYCache (SDAdditions)

- (id<SDWebImageOperation>)queryImageForKey:(NSString *)key options:(SDWebImageOptions)options context:(SDWebImageContext *)context completion:(SDImageCacheQueryCompletionBlock)doneBlock {
    return [self queryImageForKey:key options:options context:context cacheType:SDImageCacheTypeAll completion:doneBlock];
}

- (id<SDWebImageOperation>)queryImageForKey:(NSString *)key options:(SDWebImageOptions)options context:(SDWebImageContext *)context cacheType:(SDImageCacheType)queryCacheType completion:(SDImageCacheQueryCompletionBlock)doneBlock {
    if (!key) {
        if (doneBlock) {
            doneBlock(nil, nil, SDImageCacheTypeNone);
        }
        return nil;
    }
    // Invalid cache type
    if (queryCacheType == SDImageCacheTypeNone) {
        if (doneBlock) {
            doneBlock(nil, nil, SDImageCacheTypeNone);
        }
        return nil;
    }
    
    // First check the in-memory cache...
    UIImage *image;
    if (queryCacheType != SDImageCacheTypeDisk) {
        image = [self.memoryCache objectForKey:key];
    }
    
    if (image) {
        if (options & SDImageCacheDecodeFirstFrameOnly) {
            // Ensure static image
            Class animatedImageClass = image.class;
            if (image.sd_isAnimated || ([animatedImageClass isSubclassOfClass:[UIImage class]] && [animatedImageClass conformsToProtocol:@protocol(SDAnimatedImage)])) {
#if SD_MAC
                image = [[NSImage alloc] initWithCGImage:image.CGImage scale:image.scale orientation:kCGImagePropertyOrientationUp];
#else
                image = [[UIImage alloc] initWithCGImage:image.CGImage scale:image.scale orientation:image.imageOrientation];
#endif
            }
        } else if (options & SDImageCacheMatchAnimatedImageClass) {
            // Check image class matching
            Class animatedImageClass = image.class;
            Class desiredImageClass = context[SDWebImageContextAnimatedImageClass];
            if (desiredImageClass && ![animatedImageClass isSubclassOfClass:desiredImageClass]) {
                image = nil;
            }
        }
    }
    
    BOOL shouldQueryMemoryOnly = (queryCacheType == SDImageCacheTypeMemory) || (image && !(options & SDImageCacheQueryMemoryData));
    if (shouldQueryMemoryOnly) {
        if (doneBlock) {
            doneBlock(image, nil, SDImageCacheTypeMemory);
        }
        return nil;
    }
    
    // Second check the disk cache...
    NSOperation *operation = [NSOperation new];
    // Check whether we need to synchronously query disk
    // 1. in-memory cache hit & memoryDataSync
    // 2. in-memory cache miss & diskDataSync
    BOOL shouldQueryDiskSync = ((image && options & SDImageCacheQueryMemoryDataSync) ||
                                (!image && options & SDImageCacheQueryDiskDataSync));
    void(^queryDiskBlock)(NSData *) = ^(NSData *diskData) {
        if (operation.isCancelled) {
            if (doneBlock) {
                doneBlock(nil, nil, SDImageCacheTypeNone);
            }
            return;
        }
        
        @autoreleasepool {
            UIImage *diskImage;
            SDImageCacheType cacheType = SDImageCacheTypeNone;
            if (image) {
                // the image is from in-memory cache, but need image data
                diskImage = image;
                cacheType = SDImageCacheTypeMemory;
            } else if (diskData) {
                cacheType = SDImageCacheTypeDisk;
                // decode image data only if in-memory cache missed
                diskImage = SDImageCacheDecodeImageData(diskData, key, options, context);
                if (diskImage) {
                    // Check extended data
                    NSData *extendedData = [YYDiskCache getExtendedDataFromObject:diskData];
                    if (extendedData) {
                        id extendedObject;
                        if (@available(iOS 11, tvOS 11, macOS 10.13, watchOS 4, *)) {
                            NSError *error;
                            NSKeyedUnarchiver *unarchiver = [[NSKeyedUnarchiver alloc] initForReadingFromData:extendedData error:&error];
                            unarchiver.requiresSecureCoding = NO;
                            extendedObject = [unarchiver decodeTopLevelObjectForKey:NSKeyedArchiveRootObjectKey error:&error];
                            if (error) {
                                NSLog(@"NSKeyedUnarchiver unarchive failed with error: %@", error);
                            }
                        } else {
                            @try {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
                                extendedObject = [NSKeyedUnarchiver unarchiveObjectWithData:extendedData];
#pragma clang diagnostic pop
                            } @catch (NSException *exception) {
                                NSLog(@"NSKeyedUnarchiver unarchive failed with exception: %@", exception);
                            }
                        }
                        diskImage.sd_extendedObject = extendedObject;
                    }
                }
                if (diskImage) {
                    NSUInteger cost = diskImage.sd_memoryCost;
                    [self.memoryCache setObject:diskImage forKey:key cost:cost];
                }
            }
            
            if (doneBlock) {
                if (shouldQueryDiskSync) {
                    doneBlock(diskImage, diskData, cacheType);
                } else {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        doneBlock(diskImage, diskData, cacheType);
                    });
                }
            }
        }
    };
    
    if (shouldQueryDiskSync) {
        NSData *diskData = [self.diskCache dataForKey:key];
        queryDiskBlock(diskData);
    } else {
        // YYDiskCache's completion block is called in the global queue
        [self.diskCache objectForKey:key withBlock:^(NSString * _Nonnull key, id<NSObject, NSCoding> _Nullable object) {
            NSData *diskData = nil;
            if ([object isKindOfClass:[NSData class]]) {
                diskData = (NSData *)object;
            }
            queryDiskBlock(diskData);
        }];
    }
    
    return operation;
}

- (void)storeImageToDisk:(UIImage *)image imageData:(NSData *)imageData forKey:(NSString *)key completion:(SDWebImageNoParamsBlock)completionBlock {
    NSData *data = SDYYPluginCacheDataWithImageData(image, imageData);
    if (!data) {
        // SDImageCache does not remove object if `data` is nil
        if (completionBlock) {
            dispatch_async(dispatch_get_main_queue(), ^{
                completionBlock();
            });
        }
        return;
    }
    if (image) {
        // Check extended data
        id extendedObject = image.sd_extendedObject;
        if ([extendedObject conformsToProtocol:@protocol(NSCoding)]) {
            NSData *extendedData;
            if (@available(iOS 11, tvOS 11, macOS 10.13, watchOS 4, *)) {
                NSError *error;
                extendedData = [NSKeyedArchiver archivedDataWithRootObject:extendedObject requiringSecureCoding:NO error:&error];
                if (error) {
                    NSLog(@"NSKeyedArchiver archive failed with error: %@", error);
                }
            } else {
                @try {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
                    extendedData = [NSKeyedArchiver archivedDataWithRootObject:extendedObject];
#pragma clang diagnostic pop
                } @catch (NSException *exception) {
                    NSLog(@"NSKeyedArchiver archive failed with exception: %@", exception);
                }
            }
            if (extendedData) {
                [YYDiskCache setExtendedData:extendedData toObject:data];
            }
        }
    }
    [self.diskCache setObject:data forKey:key withBlock:^{
        if (completionBlock) {
            dispatch_async(dispatch_get_main_queue(), ^{
                completionBlock();
            });
        }
    }];
}

- (void)storeImage:(UIImage *)image imageData:(NSData *)imageData forKey:(NSString *)key cacheType:(SDImageCacheType)cacheType completion:(SDWebImageNoParamsBlock)completionBlock {
    switch (cacheType) {
        case SDImageCacheTypeNone: {
            if (completionBlock) {
                completionBlock();
            }
        }
            break;
        case SDImageCacheTypeMemory: {
            NSUInteger cost = image.sd_memoryCost;
            [self.memoryCache setObject:image forKey:key cost:cost];
            if (completionBlock) {
                completionBlock();
            }
        }
            break;
        case SDImageCacheTypeDisk: {
            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
                [self storeImageToDisk:image imageData:imageData forKey:key completion:completionBlock];
            });
        }
            break;
        case SDImageCacheTypeAll: {
            NSUInteger cost = image.sd_memoryCost;
            [self.memoryCache setObject:image forKey:key cost:cost];
            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
                [self storeImageToDisk:image imageData:imageData forKey:key completion:completionBlock];
            });
        }
            break;
        default: {
            if (completionBlock) {
                completionBlock();
            }
        }
            break;
    }
}

- (void)removeImageForKey:(NSString *)key cacheType:(SDImageCacheType)cacheType completion:(SDWebImageNoParamsBlock)completionBlock {
    switch (cacheType) {
        case SDImageCacheTypeNone: {
            if (completionBlock) {
                completionBlock();
            }
        }
            break;
        case SDImageCacheTypeMemory: {
            [self.memoryCache removeObjectForKey:key];
            if (completionBlock) {
                completionBlock();
            }
        }
            break;
        case SDImageCacheTypeDisk: {
            [self.diskCache removeObjectForKey:key withBlock:^(NSString * _Nonnull key) {
                if (completionBlock) {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        completionBlock();
                    });
                }
            }];
        }
            break;
        case SDImageCacheTypeAll: {
            [self.memoryCache removeObjectForKey:key];
            [self.diskCache removeObjectForKey:key withBlock:^(NSString * _Nonnull key) {
                if (completionBlock) {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        completionBlock();
                    });
                }
            }];
        }
            break;
        default: {
            if (completionBlock) {
                completionBlock();
            }
        }
            break;
    }
}

- (void)containsImageForKey:(NSString *)key cacheType:(SDImageCacheType)cacheType completion:(SDImageCacheContainsCompletionBlock)completionBlock {
    switch (cacheType) {
        case SDImageCacheTypeNone: {
            if (completionBlock) {
                completionBlock(SDImageCacheTypeNone);
            }
        }
            break;
        case SDImageCacheTypeMemory: {
            BOOL isInMemoryCache = ([self.memoryCache objectForKey:key] != nil);
            if (completionBlock) {
                completionBlock(isInMemoryCache ? SDImageCacheTypeMemory : SDImageCacheTypeNone);
            }
        }
            break;
        case SDImageCacheTypeDisk: {
            [self.diskCache containsObjectForKey:key withBlock:^(NSString * _Nonnull key, BOOL contains) {
                if (completionBlock) {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        completionBlock(contains ? SDImageCacheTypeDisk : SDImageCacheTypeNone);
                    });
                }
            }];
        }
            break;
        case SDImageCacheTypeAll: {
            BOOL isInMemoryCache = ([self.memoryCache objectForKey:key] != nil);
            if (isInMemoryCache) {
                if (completionBlock) {
                    completionBlock(SDImageCacheTypeMemory);
                }
                return;
            }
            [self.diskCache containsObjectForKey:key withBlock:^(NSString * _Nonnull key, BOOL contains) {
                if (completionBlock) {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        completionBlock(contains ? SDImageCacheTypeDisk : SDImageCacheTypeNone);
                    });
                }
            }];
        }
            break;
        default:
            if (completionBlock) {
                completionBlock(SDImageCacheTypeNone);
            }
            break;
    }
}

- (void)clearWithCacheType:(SDImageCacheType)cacheType completion:(SDWebImageNoParamsBlock)completionBlock {
    switch (cacheType) {
        case SDImageCacheTypeNone: {
            if (completionBlock) {
                completionBlock();
            }
            return;
        }
            break;
        case SDImageCacheTypeMemory: {
            [self.memoryCache removeAllObjects];
            if (completionBlock) {
                completionBlock();
            }
        }
            break;
        case SDImageCacheTypeDisk: {
            [self.diskCache removeAllObjectsWithBlock:^{
                if (completionBlock) {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        completionBlock();
                    });
                }
            }];
        }
            break;
        case SDImageCacheTypeAll: {
            [self.memoryCache removeAllObjects];
            [self.diskCache removeAllObjectsWithBlock:^{
                if (completionBlock) {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        completionBlock();
                    });
                }
            }];
        }
            break;
        default: {
            if (completionBlock) {
                completionBlock();
            }
        }
            break;
    }
}

@end
