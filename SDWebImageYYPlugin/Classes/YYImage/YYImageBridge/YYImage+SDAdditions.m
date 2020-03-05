/*
 * This file is part of the SDWebImage-YYImage package.
 *
 * For the full copyright and license information, please view the LICENSE
 * file that was distributed with this source code.
 */

#import "YYImage+SDAdditions.h"
#import <objc/runtime.h>

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
    // YYImage contains bug that don't update ivar value, simple workaround
    Ivar ivar = class_getInstanceVariable(self.class, "_preloadAllAnimatedImageFrames");
    ((void (*)(id, Ivar, BOOL))object_setIvar)(self, ivar, YES);
}

- (void)unloadAllFrames {
    [self setPreloadAllAnimatedImageFrames:NO];
    // YYImage contains bug that don't update ivar value, simple workaround
    Ivar ivar = class_getInstanceVariable(self.class, "_preloadAllAnimatedImageFrames");
    ((void (*)(id, Ivar, BOOL))object_setIvar)(self, ivar, NO);
}

- (BOOL)isAllFramesLoaded {
    return self.preloadAllAnimatedImageFrames;
}

@end

@implementation YYImage (MemoryCacheCost)

- (NSUInteger)sd_memoryCost {
    NSNumber *value = objc_getAssociatedObject(self, @selector(sd_memoryCost));
    if (value != nil) {
        return value.unsignedIntegerValue;
    }
    
    CGImageRef imageRef = self.CGImage;
    if (!imageRef) {
        return 0;
    }
    NSUInteger bytesPerFrame = CGImageGetBytesPerRow(imageRef) * CGImageGetHeight(imageRef);
    NSUInteger frameCount = 1;
    if (self.isAllFramesLoaded) {
        frameCount = self.animatedImageFrameCount;
    }
    frameCount = frameCount > 0 ? frameCount : 1;
    NSUInteger cost = bytesPerFrame * frameCount;
    return cost;
}

@end

@implementation YYImage (Metadata)

- (BOOL)sd_isAnimated {
    return YES;
}

- (NSUInteger)sd_imageLoopCount {
    return self.animatedImageLoopCount;
}

- (void)setSd_imageLoopCount:(NSUInteger)sd_imageLoopCount {
    return;
}

- (SDImageFormat)sd_imageFormat {
    switch (self.animatedImageType) {
        case YYImageTypeJPEG:
        case YYImageTypeJPEG2000:
            return SDImageFormatJPEG;
        case YYImageTypePNG:
            return SDImageFormatPNG;
        case YYImageTypeGIF:
            return SDImageFormatGIF;
        case YYImageTypeTIFF:
            return SDImageFormatTIFF;
        case YYImageTypeWebP:
            return SDImageFormatWebP;
        default:
            return SDImageFormatUndefined;
    }
}

- (void)setSd_imageFormat:(SDImageFormat)sd_imageFormat {
    return;
}

- (BOOL)sd_isVector {
    return NO;
}

@end
