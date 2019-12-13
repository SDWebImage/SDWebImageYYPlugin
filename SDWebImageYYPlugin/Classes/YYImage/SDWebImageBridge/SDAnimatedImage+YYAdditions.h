/*
 * This file is part of the SDWebImage-YYImage package.
 *
 * For the full copyright and license information, please view the LICENSE
 * file that was distributed with this source code.
 */

#import <SDWebImage/SDWebImage.h>
#import <YYImage/YYAnimatedImageView.h>

/// SDAnimatedImage category to supports `YYAnimatedImage` protocol, which allows using `SDAnimatedImage` inside `YYAnimatedImageView`
@interface SDAnimatedImage (YYAdditions) <YYAnimatedImage>

@end
