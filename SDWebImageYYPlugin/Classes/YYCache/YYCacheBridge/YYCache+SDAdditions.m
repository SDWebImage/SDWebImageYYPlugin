/*
 * This file is part of the SDWebImage-YYCache package.
 *
 * For the full copyright and license information, please view the LICENSE
 * file that was distributed with this source code.
 */


#import "YYCache+SDAdditions.h"
#import "YYMemoryCache+SDAdditions.h"
#import "YYDiskCache+SDAdditions.h"

static void SDYYPluginUnarchiveObject(NSData *data, UIImage *image) {
    if (!data || !image) {
        return;
    }
    // Check extended data
    NSData *extendedData = [YYDiskCache getExtendedDataFromObject:data];
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

static void SDYYPluginArchiveObject(NSData *data, UIImage *image) {
    if (!data || !image) {
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
        [YYDiskCache setExtendedData:extendedData toObject:data];
    }
}

@implementation YYCache (SDAdditions)

- (id<SDWebImageOperation>)queryImageForKey:(NSString *)key options:(SDWebImageOptions)options context:(SDWebImageContext *)context completion:(SDImageCacheQueryCompletionBlock)doneBlock {
    return [self queryImageForKey:key options:options context:context cacheType:SDImageCacheTypeAll completion:doneBlock];
}

- (id<SDWebImageOperation>)queryImageForKey:(NSString *)key options:(SDWebImageOptions)options context:(SDWebImageContext *)context cacheType:(SDImageCacheType)queryCacheType completion:(SDImageCacheQueryCompletionBlock)doneBlock {
    SDImageCacheOptions cacheOptions = 0;
    if (options & SDWebImageQueryMemoryData) cacheOptions |= SDImageCacheQueryMemoryData;
    if (options & SDWebImageQueryMemoryDataSync) cacheOptions |= SDImageCacheQueryMemoryDataSync;
    if (options & SDWebImageQueryDiskDataSync) cacheOptions |= SDImageCacheQueryDiskDataSync;
    if (options & SDWebImageScaleDownLargeImages) cacheOptions |= SDImageCacheScaleDownLargeImages;
    if (options & SDWebImageAvoidDecodeImage) cacheOptions |= SDImageCacheAvoidDecodeImage;
    if (options & SDWebImageDecodeFirstFrameOnly) cacheOptions |= SDImageCacheDecodeFirstFrameOnly;
    if (options & SDWebImagePreloadAllFrames) cacheOptions |= SDImageCachePreloadAllFrames;
    if (options & SDWebImageMatchAnimatedImageClass) cacheOptions |= SDImageCacheMatchAnimatedImageClass;
    
    return [self queryCacheOperationForKey:key options:cacheOptions context:context cacheType:queryCacheType done:doneBlock];
}

- (id<SDWebImageOperation>)queryCacheOperationForKey:(nullable NSString *)key options:(SDImageCacheOptions)options context:(nullable SDWebImageContext *)context cacheType:(SDImageCacheType)queryCacheType done:(nullable SDImageCacheQueryCompletionBlock)doneBlock {
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
            if (image.sd_isAnimated) {
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
    SDCallbackQueue *queue = context[SDWebImageContextCallbackQueue];
    NSOperation *operation = [NSOperation new];
    // Check whether we need to synchronously query disk
    // 1. in-memory cache hit & memoryDataSync
    // 2. in-memory cache miss & diskDataSync
    BOOL shouldQueryDiskSync = ((image && options & SDImageCacheQueryMemoryDataSync) ||
                                (!image && options & SDImageCacheQueryDiskDataSync));
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
            BOOL shouldCacheToMomery = YES;
            if (context[SDWebImageContextStoreCacheType]) {
                SDImageCacheType cacheType = [context[SDWebImageContextStoreCacheType] integerValue];
                shouldCacheToMomery = (cacheType == SDImageCacheTypeAll || cacheType == SDImageCacheTypeMemory);
            }
            CGSize thumbnailSize = CGSizeZero;
            NSValue *thumbnailSizeValue = context[SDWebImageContextImageThumbnailPixelSize];
            if (thumbnailSizeValue != nil) {
        #if SD_MAC
                thumbnailSize = thumbnailSizeValue.sizeValue;
        #else
                thumbnailSize = thumbnailSizeValue.CGSizeValue;
        #endif
            }
            if (thumbnailSize.width > 0 && thumbnailSize.height > 0) {
                // Query full size cache key which generate a thumbnail, should not write back to full size memory cache
                shouldCacheToMomery = NO;
            }
            // decode image data only if in-memory cache missed
            diskImage = SDImageCacheDecodeImageData(diskData, key, options, context);
            SDYYPluginUnarchiveObject(diskData, diskImage);
            if (shouldCacheToMomery && diskImage) {
                NSUInteger cost = diskImage.sd_memoryCost;
                [self.memoryCache setObject:diskImage forKey:key cost:cost];
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
            SDYYPluginArchiveObject(data, image);
            [self.diskCache setObject:data forKey:key withBlock:^{
                if (completionBlock) {
                    [(queue ?: SDCallbackQueue.mainQueue) async:^{
                        completionBlock();
                    }];
                }
            }];
        });
    } else {
        SDYYPluginArchiveObject(data, image);
        [self.diskCache setObject:data forKey:key withBlock:^{
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
