/*
 * This file is part of the SDWebImage-YYImage package.
 *
 * For the full copyright and license information, please view the LICENSE
 * file that was distributed with this source code.
 */

#import "SDAnimatedImage+YYAdditions.h"

@implementation SDAnimatedImage (YYAdditions)

#pragma mark - YYAnimatedImage

- (NSUInteger)animatedImageBytesPerFrame {
    return CGImageGetBytesPerRow(self.CGImage) * CGImageGetHeight(self.CGImage);
}

@end
