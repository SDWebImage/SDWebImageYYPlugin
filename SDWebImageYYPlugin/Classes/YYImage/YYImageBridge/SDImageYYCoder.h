/*
 * This file is part of the SDWebImage-YYImage package.
 *
 * For the full copyright and license information, please view the LICENSE
 * file that was distributed with this source code.
 */

#import <YYImage/YYImage.h>
#import <SDWebImage/SDWebImage.h>

/**
 YYImageEncoder && YYImageDecoder bridge to supports SDWebImage coder protocol. This class use YYImage's decoding && encoding system. It supports any image format listed in `YYImageType`.
 @note This class conforms to `SDProgressiveImageCoder` && `SDAnimatedImageCoder`, supports static progressive decoding and animation decoding. However, it does not supports progressive animation decoding like `SDImageGIFCoder`. Which means you can not use any method in `SDAnimatedImageProvider` protocol if you create the instance with `initIncrementalWithOptions:` method.
 */
@interface SDImageYYCoder : NSObject <SDImageCoder, SDProgressiveImageCoder, SDAnimatedImageCoder>

/**
 The shared coder instance.
 */
@property (nonatomic, class, readonly, nonnull) SDImageYYCoder *sharedCoder;

/**
 The wrapped `YYImageDecoder` instance, to support static progressive and animation decoding.
 @note This property is only useful for static progressive or animation decoding. For normal decoding process, we will use a temporary `YYImageDecoder` to do decoding because it does not need to keep decoded context.
 */
@property (nonatomic, strong, readonly, nonnull) YYImageDecoder *decoder;

@end
