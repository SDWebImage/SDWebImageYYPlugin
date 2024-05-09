/*
 * This file is part of the SDWebImage-YYCache package.
 *
 * For the full copyright and license information, please view the LICENSE
 * file that was distributed with this source code.
 */

#import "YYMemoryCache+SDAdditions.h"
#import <objc/runtime.h>

@implementation YYMemoryCache (SDAdditions)

- (SDImageCacheConfig *)config {
    return objc_getAssociatedObject(self, @selector(config));
}

- (void)setConfig:(SDImageCacheConfig *)config {
    objc_setAssociatedObject(self, @selector(config), config, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

#pragma mark - SDMemoryCache

- (instancetype)initWithConfig:(SDImageCacheConfig *)config {
    self = [self init];
    if (self) {
        self.config = config;
        self.countLimit = config.maxMemoryCount;
        self.costLimit = config.maxMemoryCost;
    }
    return self;
}

- (void)setObject:(id)object forKey:(id)key cost:(NSUInteger)cost {
    [self setObject:object forKey:key withCost:cost];
}

@end
