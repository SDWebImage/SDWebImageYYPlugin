/*
 * This file is part of the SDWebImage-YYImage package.
 *
 * For the full copyright and license information, please view the LICENSE
 * file that was distributed with this source code.
 */

#import <YYImage/YYImage.h>
#import <SDWebImage/SDWebImage.h>

/// YYImage category to support `SDAnimatedImage` protocol, which allows using `YYImage` inside `SDAnimatedImageView`
@interface YYImage (SDAdditions) <SDAnimatedImage>

@end
