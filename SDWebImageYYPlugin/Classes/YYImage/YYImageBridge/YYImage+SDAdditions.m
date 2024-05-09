/*
 * This file is part of the SDWebImage-YYImage package.
 *
 * For the full copyright and license information, please view the LICENSE
 * file that was distributed with this source code.
 */

#import "YYImage+SDAdditions.h"
#import <objc/runtime.h>

static inline SDImageFormat SDImageFormatFromYYImageType(YYImageType type) {
    switch (type) {
        case YYImageTypeJPEG:
        case YYImageTypeJPEG2000:
            return SDImageFormatJPEG;
        case YYImageTypePNG:
            return SDImageFormatPNG;
        case YYImageTypeGIF:
            return SDImageFormatGIF;
        case YYImageTypeTIFF:
            return SDImageFormatTIFF;
        case YYImageTypeBMP:
            return SDImageFormatBMP;
        case YYImageTypeWebP:
            return SDImageFormatWebP;
        default:
            return SDImageFormatUndefined;
    }
}

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

- (SDImageFormat)animatedImageFormat {
    return SDImageFormatFromYYImageType(self.animatedImageType);
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
    return self.animatedImageFrameCount > 1;
}

- (NSUInteger)sd_imageLoopCount {
    return self.animatedImageLoopCount;
}

- (void)setSd_imageLoopCount:(NSUInteger)sd_imageLoopCount {
    return;
}

- (NSUInteger)sd_imageFrameCount {
    NSUInteger frameCount = self.animatedImageFrameCount;
    if (frameCount > 1) {
        return frameCount;
    } else {
        return 1;
    }
}

- (SDImageFormat)sd_imageFormat {
    NSData *animatedImageData = self.animatedImageData;
    if (animatedImageData) {
        return self.animatedImageFormat;
    } else {
        return [super sd_imageFormat];
    }
}

- (void)setSd_imageFormat:(SDImageFormat)sd_imageFormat {
    return;
}

- (BOOL)sd_isVector {
    return NO;
}

@end

@implementation YYImage (MultiFormat)

+ (nullable UIImage *)sd_imageWithData:(nullable NSData *)data {
    return [self sd_imageWithData:data scale:1];
}

+ (nullable UIImage *)sd_imageWithData:(nullable NSData *)data scale:(CGFloat)scale {
    return [self sd_imageWithData:data scale:scale firstFrameOnly:NO];
}

+ (nullable UIImage *)sd_imageWithData:(nullable NSData *)data scale:(CGFloat)scale firstFrameOnly:(BOOL)firstFrameOnly {
    if (!data) {
        return nil;
    }
    return [[self alloc] initWithData:data scale:scale options:@{SDImageCoderDecodeFirstFrameOnly : @(firstFrameOnly)}];
}

- (nullable NSData *)sd_imageData {
    NSData *imageData = self.animatedImageData;
    if (imageData) {
        return imageData;
    } else {
        return [self sd_imageDataAsFormat:self.animatedImageFormat];
    }
}

- (nullable NSData *)sd_imageDataAsFormat:(SDImageFormat)imageFormat {
    return [self sd_imageDataAsFormat:imageFormat compressionQuality:1];
}

- (nullable NSData *)sd_imageDataAsFormat:(SDImageFormat)imageFormat compressionQuality:(double)compressionQuality {
    return [self sd_imageDataAsFormat:imageFormat compressionQuality:compressionQuality firstFrameOnly:NO];
}

- (nullable NSData *)sd_imageDataAsFormat:(SDImageFormat)imageFormat compressionQuality:(double)compressionQuality firstFrameOnly:(BOOL)firstFrameOnly {
    // Protect when user input the imageFormat == self.animatedImageFormat && compressionQuality == 1
    // This should be treated as grabbing `self.animatedImageData` as well :)
    NSData *imageData;
    if (imageFormat == self.animatedImageFormat && compressionQuality == 1) {
        imageData = self.animatedImageData;
    }
    if (imageData) return imageData;
    
    SDImageCoderOptions *options = @{SDImageCoderEncodeCompressionQuality : @(compressionQuality), SDImageCoderEncodeFirstFrameOnly : @(firstFrameOnly)};
    NSUInteger frameCount = self.animatedImageFrameCount;
    if (frameCount <= 1) {
        // Static image
        imageData = [SDImageCodersManager.sharedManager encodedDataWithImage:self format:imageFormat options:options];
    }
    if (imageData) return imageData;
    
    NSUInteger loopCount = self.animatedImageLoopCount;
    // Keep animated image encoding, loop each frame.
    NSMutableArray<SDImageFrame *> *frames = [NSMutableArray arrayWithCapacity:frameCount];
    for (size_t i = 0; i < frameCount; i++) {
        UIImage *image = [self animatedImageFrameAtIndex:i];
        NSTimeInterval duration = [self animatedImageDurationAtIndex:i];
        SDImageFrame *frame = [SDImageFrame frameWithImage:image duration:duration];
        [frames addObject:frame];
    }
    imageData = [SDImageCodersManager.sharedManager encodedDataWithFrames:frames loopCount:loopCount format:imageFormat options:options];
    return imageData;
}

@end
