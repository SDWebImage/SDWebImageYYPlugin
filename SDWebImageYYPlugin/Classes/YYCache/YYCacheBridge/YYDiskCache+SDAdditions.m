/*
 * This file is part of the SDWebImage-YYCache package.
 *
 * For the full copyright and license information, please view the LICENSE
 * file that was distributed with this source code.
 */

#import "YYDiskCache+SDAdditions.h"
#import <objc/runtime.h>

@interface YYDiskCache ()

// Internal Headers
- (NSString *)_filenameForKey:(NSString *)key;

@end

@implementation YYDiskCache (SDAdditions)

- (SDImageCacheConfig *)config {
    return objc_getAssociatedObject(self, @selector(config));
}

- (void)setConfig:(SDImageCacheConfig *)config {
    objc_setAssociatedObject(self, @selector(config), config, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

#pragma mark - SDDiskCache

- (instancetype)initWithCachePath:(NSString *)cachePath config:(SDImageCacheConfig *)config {
    self = [self initWithPath:cachePath inlineThreshold:0];
    if (self) {
        self.config = config;
        self.ageLimit = config.maxDiskAge;
        self.costLimit = config.maxDiskSize;
    }
    return self;
}

- (BOOL)containsDataForKey:(NSString *)key {
    return [self containsObjectForKey:key];
}

- (NSData *)dataForKey:(NSString *)key {
    id<NSObject, NSCoding> object = [self objectForKey:key];
    if ([object isKindOfClass:[NSData class]]) {
        return (NSData *)object;
    } else {
        return nil;
    }
}

- (void)setData:(NSData *)data forKey:(NSString *)key {
    if (!data) {
        return; // YYDiskCache will remove object if `data` is nil
    }
    
    [self setObject:data forKey:key];
}

- (NSData *)extendedDataForKey:(NSString *)key {
    id<NSObject, NSCoding> object = [self objectForKey:key];
    return [self.class getExtendedDataFromObject:object];
}

- (void)setExtendedData:(NSData *)extendedData forKey:(NSString *)key {
    id<NSObject, NSCoding> object = [self objectForKey:key];
    [self.class setExtendedData:nil toObject:object];
    [self setObject:object forKey:key];
}

- (void)removeDataForKey:(NSString *)key {
    [self removeObjectForKey:key];
}

- (void)removeAllData {
    [self removeAllObjects];
}

- (void)removeExpiredData {
    NSTimeInterval ageLimit = self.config.maxDiskAge;
    NSUInteger sizeLimit = self.config.maxDiskSize;
    
    [self trimToAge:ageLimit];
    [self trimToCost:sizeLimit];
}

- (NSString *)cachePathForKey:(NSString *)key {
    NSString *filename =  [self _filenameForKey:key];
    if (!filename) {
        return nil;
    }
    return [self.path stringByAppendingPathComponent:filename];
}

- (NSInteger)totalSize {
    return [self totalCost];
}

@end
