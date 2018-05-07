/*
 * This file is part of the SDWebImage-YYImage package.
 *
 * For the full copyright and license information, please view the LICENSE
 * file that was distributed with this source code.
 */

#import "YYImage+SDAddtions.h"

@implementation YYImage (SDAddtions)

#pragma mark - SDAnimatedImage

- (instancetype)initWithAnimatedCoder:(id<SDAnimatedImageCoder>)animatedCoder scale:(CGFloat)scale {
    // Call `YYImage`'s initializer with animated image data
    NSData *data = animatedCoder.animatedImageData;
    return [self initWithData:data scale:scale];
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
