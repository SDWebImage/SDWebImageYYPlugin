/*
 * This file is part of the SDWebImage-YYImage package.
 *
 * For the full copyright and license information, please view the LICENSE
 * file that was distributed with this source code.
 */

#import "YYImage+SDAdditions.h"

@implementation YYImage (SDAdditions)

#pragma mark - SDAnimatedImage

- (instancetype)initWithData:(NSData *)data scale:(CGFloat)scale options:(SDImageCoderOptions *)options {
    return [self initWithData:data scale:scale];
}

- (instancetype)initWithAnimatedCoder:(id<SDAnimatedImageCoder>)animatedCoder scale:(CGFloat)scale {
    // YYImage does not support progressive animation decoding
    return nil;
}

- (void)preloadAllFrames {
    [self setPreloadAllAnimatedImageFrames:YES];
}

- (void)unloadAllFrames {
    [self setPreloadAllAnimatedImageFrames:NO];
}

- (BOOL)isAllFramesLoaded {
    return self.preloadAllAnimatedImageFrames;
}

@end
