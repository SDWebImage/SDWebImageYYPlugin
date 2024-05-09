/*
 * This file is part of the SDWebImage-YYCache package.
 *
 * For the full copyright and license information, please view the LICENSE
 * file that was distributed with this source code.
 */


#import "YYCache+SDAdditions.h"
#import "YYMemoryCache+SDAdditions.h"
#import "YYDiskCache+SDAdditions.h"
#import "SDImageTransformer.h" // TODO, remove this
#import <objc/runtime.h>

// TODO, remove this
static BOOL SDIsThumbnailKey(NSString *key) {
    if ([key rangeOfString:@"-Thumbnail("].location != NSNotFound) {
        return YES;
    }
    return NO;
}

@implementation YYCache (SDAdditions)

- (SDImageCacheConfig *)config {
    // Provided the default one
    SDImageCacheConfig *config = objc_getAssociatedObject(self, @selector(config));
    if (!config) {
        config = SDImageCacheConfig.defaultCacheConfig;
        config.shouldDisableiCloud
        [self setConfig:config];
    }
    return config;
}

- (void)setConfig:(SDImageCacheConfig *)config {
    objc_setAssociatedObject(self, @selector(config), config, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (void)_syncDiskToMemoryWithImage:(UIImage *)diskImage forKey:(NSString *)key {
    // earily check
    if (!self.config.shouldCacheImagesInMemory) {
        return;
    }
    if (!diskImage) {
        return;
    }
    // The disk -> memory sync logic, which should only store thumbnail image with thumbnail key
    // However, caller (like SDWebImageManager) will query full key, with thumbnail size, and get thubmnail image
    // We should add a check here, currently it's a hack
    if (diskImage.sd_isThumbnail && !SDIsThumbnailKey(key)) {
        SDImageCoderOptions *options = diskImage.sd_decodeOptions;
        CGSize thumbnailSize = CGSizeZero;
        NSValue *thumbnailSizeValue = options[SDImageCoderDecodeThumbnailPixelSize];
        if (thumbnailSizeValue != nil) {
    #if SD_MAC
            thumbnailSize = thumbnailSizeValue.sizeValue;
    #else
            thumbnailSize = thumbnailSizeValue.CGSizeValue;
    #endif
        }
        BOOL preserveAspectRatio = YES;
        NSNumber *preserveAspectRatioValue = options[SDImageCoderDecodePreserveAspectRatio];
        if (preserveAspectRatioValue != nil) {
            preserveAspectRatio = preserveAspectRatioValue.boolValue;
        }
        // Calculate the actual thumbnail key
        NSString *thumbnailKey = SDThumbnailedKeyForKey(key, thumbnailSize, preserveAspectRatio);
        // Override the sync key
        key = thumbnailKey;
    }
    NSUInteger cost = diskImage.sd_memoryCost;
    [self.memoryCache setObject:diskImage forKey:key cost:cost];
}

- (void)_unarchiveObjectWithImage:(UIImage *)image forKey:(NSString *)key {
    if (!image || !key) {
        return;
    }
    // Check extended data
    NSData *extendedData = [self.diskCache extendedDataForKey:key];
    if (!extendedData) {
        return;
    }
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
    image.sd_extendedObject = extendedObject;
}

- (void)_archivedDataWithImage:(UIImage *)image forKey:(NSString *)key {
    if (!image || !key) {
        return;
    }
    // Check extended data
    id extendedObject = image.sd_extendedObject;
    if (![extendedObject conformsToProtocol:@protocol(NSCoding)]) {
        return;
    }
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
        [self.diskCache setExtendedData:extendedData forKey:key];
    }
}

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
        if (options & SDWebImageDecodeFirstFrameOnly) {
            // Ensure static image
            if (image.sd_imageFrameCount > 1) {
#if SD_MAC
                image = [[NSImage alloc] initWithCGImage:image.CGImage scale:image.scale orientation:kCGImagePropertyOrientationUp];
#else
                image = [[UIImage alloc] initWithCGImage:image.CGImage scale:image.scale orientation:image.imageOrientation];
#endif
            }
        } else if (options & SDWebImageMatchAnimatedImageClass) {
            // Check image class matching
            Class animatedImageClass = image.class;
            Class desiredImageClass = context[SDWebImageContextAnimatedImageClass];
            if (desiredImageClass && ![animatedImageClass isSubclassOfClass:desiredImageClass]) {
                image = nil;
            }
        }
    }
    
    BOOL shouldQueryMemoryOnly = (queryCacheType == SDImageCacheTypeMemory) || (image && !(options & SDWebImageQueryMemoryData));
    if (shouldQueryMemoryOnly) {
        if (doneBlock) {
            doneBlock(image, nil, SDImageCacheTypeMemory);
        }
        return nil;
    }
    
    // Second check the disk cache...
    SDCallbackQueue *queue = context[SDWebImageContextCallbackQueue];
    NSOperation *operation = [NSOperation new];
    // Check whether we need to synchronously query disk
    // 1. in-memory cache hit & memoryDataSync
    // 2. in-memory cache miss & diskDataSync
    BOOL shouldQueryDiskSync = ((image && options & SDWebImageQueryMemoryDataSync) ||
                                (!image && options & SDWebImageQueryDiskDataSync));
    NSData* (^queryDiskDataBlock)(void) = ^NSData* {
        @synchronized (operation) {
            if (operation.isCancelled) {
                return nil;
            }
        }
        
        return [self.diskCache dataForKey:key];
    };
    UIImage* (^queryDiskImageBlock)(NSData*) = ^UIImage*(NSData* diskData) {
        @synchronized (operation) {
            if (operation.isCancelled) {
                return nil;
            }
        }
        
        UIImage *diskImage;
        if (image) {
            // the image is from in-memory cache, but need image data
            diskImage = image;
        } else if (diskData) {
            BOOL shouldCacheToMemory = YES;
            if (context[SDWebImageContextStoreCacheType]) {
                SDImageCacheType cacheType = [context[SDWebImageContextStoreCacheType] integerValue];
                shouldCacheToMemory = (cacheType == SDImageCacheTypeAll || cacheType == SDImageCacheTypeMemory);
            }
            // Special case: If user query image in list for the same URL, to avoid decode and write **same** image object into disk cache multiple times, we query and check memory cache here again.
            if (shouldCacheToMemory && self.config.shouldCacheImagesInMemory) {
                diskImage = [self.memoryCache objectForKey:key];
            }
            // decode image data only if in-memory cache missed
            if (!diskImage) {
                diskImage = SDImageCacheDecodeImageData(diskData, key, options, context);
                [self _unarchiveObjectWithImage:diskImage forKey:key];
                // check if we need sync logic
                if (shouldCacheToMemory) {
                    [self _syncDiskToMemoryWithImage:diskImage forKey:key];
                }
            }
        }
        return diskImage;
    };
    
    // YYCache has its own IO queue
    if (shouldQueryDiskSync) {
        NSData* diskData = queryDiskDataBlock();
        UIImage* diskImage = queryDiskImageBlock(diskData);
        if (doneBlock) {
            doneBlock(diskImage, diskData, SDImageCacheTypeDisk);
        }
    } else {
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
            NSData* diskData = queryDiskDataBlock();
            UIImage* diskImage = queryDiskImageBlock(diskData);
            @synchronized (operation) {
                if (operation.isCancelled) {
                    return;
                }
            }
            if (doneBlock) {
                [(queue ?: SDCallbackQueue.mainQueue) async:^{
                    // Dispatch from IO queue to main queue need time, user may call cancel during the dispatch timing
                    // This check is here to avoid double callback (one is from `SDImageCacheToken` in sync)
                    @synchronized (operation) {
                        if (operation.isCancelled) {
                            return;
                        }
                    }
                    doneBlock(diskImage, diskData, SDImageCacheTypeDisk);
                }];
            }
        });
    }
    
    return operation;
}

- (void)storeImage:(UIImage *)image imageData:(NSData *)imageData forKey:(NSString *)key cacheType:(SDImageCacheType)cacheType completion:(SDWebImageNoParamsBlock)completionBlock {
    [self storeImage:image imageData:imageData forKey:key options:0 context:nil cacheType:cacheType completion:completionBlock];
}

- (void)storeImage:(UIImage *)image imageData:(NSData *)imageData forKey:(NSString *)key options:(SDWebImageOptions)options context:(SDWebImageContext *)context cacheType:(SDImageCacheType)cacheType completion:(SDWebImageNoParamsBlock)completionBlock {
    if ((!image && !imageData) || !key) {
        if (completionBlock) {
            completionBlock();
        }
        return;
    }
    BOOL toMemory = cacheType == SDImageCacheTypeMemory || cacheType == SDImageCacheTypeAll;
    BOOL toDisk = cacheType == SDImageCacheTypeDisk || cacheType == SDImageCacheTypeAll;
    // if memory cache is enabled
    if (image && toMemory) {
        NSUInteger cost = image.sd_memoryCost;
        [self.memoryCache setObject:image forKey:key cost:cost];
    }
    
    if (!toDisk) {
        if (completionBlock) {
            completionBlock();
        }
        return;
    }
    NSData *data = imageData;
    if (!data && [image respondsToSelector:@selector(animatedImageData)]) {
        // If image is custom animated image class, prefer its original animated data
        data = [((id<SDAnimatedImage>)image) animatedImageData];
    }
    SDCallbackQueue *queue = context[SDWebImageContextCallbackQueue];
    if (!data && image) {
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
            // Check image's associated image format, may return .undefined
            SDImageFormat format = image.sd_imageFormat;
            if (format == SDImageFormatUndefined) {
                // If image is animated, use GIF (APNG may be better, but has bugs before macOS 10.14)
                if (image.sd_isAnimated) {
                    format = SDImageFormatGIF;
                } else {
                    // If we do not have any data to detect image format, check whether it contains alpha channel to use PNG or JPEG format
                    format = [SDImageCoderHelper CGImageContainsAlpha:image.CGImage] ? SDImageFormatPNG : SDImageFormatJPEG;
                }
            }
            NSData *data = [[SDImageCodersManager sharedManager] encodedDataWithImage:image format:format options:context[SDWebImageContextImageEncodeOptions]];
            [self.diskCache setObject:data forKey:key withBlock:^{
                [self _archivedDataWithImage:image forKey:key];
                if (completionBlock) {
                    [(queue ?: SDCallbackQueue.mainQueue) async:^{
                        completionBlock();
                    }];
                }
            }];
        });
    } else {
        [self.diskCache setObject:data forKey:key withBlock:^{
            [self _archivedDataWithImage:image forKey:key];
            if (completionBlock) {
                [(queue ?: SDCallbackQueue.mainQueue) async:^{
                    completionBlock();
                }];
            }
        }];
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
