/*
 * This file is part of the SDWebImage-YYImage package.
 *
 * For the full copyright and license information, please view the LICENSE
 * file that was distributed with this source code.
 */

#import "SDImageYYCoder.h"

static inline YYImageType YYImageTypeFromSDImageFormat(SDImageFormat format) {
    switch (format) {
        case SDImageFormatJPEG:
            return YYImageTypeJPEG;
        case SDImageFormatPNG:
            return YYImageTypePNG;
        case SDImageFormatGIF:
            return YYImageTypeGIF;
        case SDImageFormatTIFF:
            return YYImageTypeTIFF;
        case SDImageFormatWebP:
            return YYImageTypeWebP;
        default:
            return YYImageTypeUnknown;
    }
}

@interface SDImageYYCoder ()

@property (nonatomic, strong) YYImageDecoder *decoder;

@end

@implementation SDImageYYCoder

+ (SDImageYYCoder *)sharedCoder {
    static dispatch_once_t onceToken;
    static SDImageYYCoder *coder;
    dispatch_once(&onceToken, ^{
        coder = [[SDImageYYCoder alloc] init];
    });
    
    return coder;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        self.decoder = [[YYImageDecoder alloc] initWithScale:1];
    }
    return self;
}

#pragma mark - SDImageCoder

- (BOOL)canDecodeFromData:(NSData *)data {
    YYImageType type = YYImageDetectType((__bridge CFDataRef)(data));
    return type != YYImageTypeUnknown;
}

- (UIImage *)decodedImageWithData:(NSData *)data options:(SDImageCoderOptions *)options {
    if (!data) {
        return nil;
    }
    CGFloat scale = 1;
    NSNumber *scaleFactor = options[SDImageCoderDecodeScaleFactor];
    if (scaleFactor != nil) {
        scale = [scaleFactor doubleValue];
        if (scale < 1) {
            scale = 1;
        }
    }
    
    YYImageDecoder *decoder = [YYImageDecoder decoderWithData:data scale:scale];
    YYImageFrame *frame = [decoder frameAtIndex:0 decodeForDisplay:NO];
    
    return frame.image;
}

- (BOOL)canEncodeToFormat:(SDImageFormat)format {
    YYImageType type = YYImageTypeFromSDImageFormat(format);
    return type != YYImageTypeUnknown;
}

- (NSData *)encodedDataWithImage:(UIImage *)image format:(SDImageFormat)format options:(SDImageCoderOptions *)options {
    double compressionQuality = 1;
    if (options[SDImageCoderEncodeCompressionQuality]) {
        compressionQuality = [options[SDImageCoderEncodeCompressionQuality] doubleValue];
    }
    
    YYImageType type = YYImageTypeFromSDImageFormat(format);
    NSData *data = [YYImageEncoder encodeImage:image type:type quality:compressionQuality];
    
    return data;
}

#pragma mark - SDProgressiveImageCoder

- (BOOL)canIncrementalDecodeFromData:(nullable NSData *)data {
    YYImageType type = YYImageDetectType((__bridge CFDataRef)(data));
    return type != YYImageTypeUnknown;
}

- (instancetype)initIncrementalWithOptions:(SDImageCoderOptions *)options {
    self = [super init];
    if (self) {
        CGFloat scale = 1;
        NSNumber *scaleFactor = options[SDImageCoderDecodeScaleFactor];
        if (scaleFactor != nil) {
            scale = [scaleFactor doubleValue];
            if (scale < 1) {
                scale = 1;
            }
        }
        self.decoder = [[YYImageDecoder alloc] initWithScale:scale];
    }
    
    return self;
}

- (void)updateIncrementalData:(NSData *)data finished:(BOOL)finished {
    if (self.decoder.isFinalized) {
        return;
    }
    
    [self.decoder updateData:data final:finished];
}

- (UIImage *)incrementalDecodedImageWithOptions:(SDImageCoderOptions *)options {
    YYImageFrame *frame = [self.decoder frameAtIndex:0 decodeForDisplay:NO];
    
    return frame.image;
}

#pragma mark - SDAnimatedImageCoder

- (instancetype)initWithAnimatedImageData:(NSData *)data options:(SDImageCoderOptions *)options {
    if (!data) {
        return nil;
    }
    self = [super init];
    if (self) {
        CGFloat scale = 1;
        NSNumber *scaleFactor = options[SDImageCoderDecodeScaleFactor];
        if (scaleFactor != nil) {
            scale = [scaleFactor doubleValue];
            if (scale < 1) {
                scale = 1;
            }
        }
        YYImageDecoder *decoder = [YYImageDecoder decoderWithData:data scale:scale];
        if (!decoder) {
            return nil;
        }
        self.decoder = decoder;
    }
    return self;
}

- (NSData *)animatedImageData {
    return self.decoder.data;
}

- (NSUInteger)animatedImageFrameCount {
    return self.decoder.frameCount;
}

- (NSUInteger)animatedImageLoopCount {
    return self.decoder.loopCount;
}

- (UIImage *)animatedImageFrameAtIndex:(NSUInteger)index {
    YYImageFrame *frame = [self.decoder frameAtIndex:index decodeForDisplay:NO];
    return frame.image;
}

- (NSTimeInterval)animatedImageDurationAtIndex:(NSUInteger)index {
    return [self.decoder frameDurationAtIndex:index];
}

@end
