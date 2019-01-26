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
    if (!data && image) {
        // If we do not have any data to detect image format, check whether it contains alpha channel to use PNG or JPEG format
        SDImageFormat format;
        if ([SDImageCoderHelper CGImageContainsAlpha:image.CGImage]) {
            format = SDImageFormatPNG;
        } else {
            format = SDImageFormatJPEG;
        }
        data = [[SDImageCodersManager sharedManager] encodedDataWithImage:image format:format options:nil];
    }
    
    return data;
}

@implementation YYCache (SDAdditions)

- (id<SDWebImageOperation>)queryImageForKey:(NSString *)key options:(SDWebImageOptions)options context:(SDWebImageContext *)context completion:(SDImageCacheQueryCompletionBlock)doneBlock {
    if (!key) {
        if (doneBlock) {
            doneBlock(nil, nil, SDImageCacheTypeNone);
        }
        return nil;
    }
    
    if ([context valueForKey:SDWebImageContextImageTransformer]) {
        // grab the transformed disk image if transformer provided
        id<SDImageTransformer> transformer = [context valueForKey:SDWebImageContextImageTransformer];
        NSString *transformerKey = [transformer transformerKey];
        key = SDTransformedKeyForKey(key, transformerKey);
    }
    
    // First check the in-memory cache...
    UIImage *image = [self.memoryCache objectForKey:key];
    BOOL shouldQueryMemoryOnly = (image && !(options & SDImageCacheQueryMemoryData));
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
    void(^queryDiskBlock)(NSData *) =  ^(NSData *diskData){
        if (operation.isCancelled) {
            // do not call the completion if cancelled
            return;
        }
        
        @autoreleasepool {
            UIImage *diskImage;
            SDImageCacheType cacheType = SDImageCacheTypeDisk;
            if (image) {
                // the image is from in-memory cache, but need image data
                diskImage = image;
                cacheType = SDImageCacheTypeMemory;
            } else if (diskData) {
                // decode image data only if in-memory cache missed
                diskImage = SDImageCacheDecodeImageData(diskData, key, options, context);
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
        [self.diskCache objectForKey:key withBlock:^(NSString * _Nonnull key, NSObject<NSCoding> *  _Nullable object) {
            NSData *diskData = nil;
            if ([object isKindOfClass:[NSData class]]) {
                diskData = (NSData *)object;
            }
            queryDiskBlock(diskData);
        }];
    }
    
    return operation;
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
        }
            break;
        case SDImageCacheTypeDisk: {
            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
                NSData *data = SDYYPluginCacheDataWithImageData(image, imageData);
                if (!data) {
                    // SDImageCache does not remove object if `data` is nil
                    if (completionBlock) {
                        dispatch_async(dispatch_get_main_queue(), ^{
                            completionBlock();
                        });
                    }
                }
                [self.diskCache setObject:data forKey:key withBlock:^{
                    if (completionBlock) {
                        dispatch_async(dispatch_get_main_queue(), ^{
                            completionBlock();
                        });
                    }
                }];
            });
        }
            break;
        case SDImageCacheTypeAll: {
            NSUInteger cost = image.sd_memoryCost;
            [self.memoryCache setObject:image forKey:key cost:cost];
            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
                NSData *data = SDYYPluginCacheDataWithImageData(image, imageData);
                if (!data) {
                    // SDImageCache does not remove object if `data` is nil
                    if (completionBlock) {
                        dispatch_async(dispatch_get_main_queue(), ^{
                            completionBlock();
                        });
                    }
                }
                [self.diskCache setObject:data forKey:key withBlock:^{
                    if (completionBlock) {
                        dispatch_async(dispatch_get_main_queue(), ^{
                            completionBlock();
                        });
                    }
                }];
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
