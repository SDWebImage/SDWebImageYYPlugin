/*
 * This file is part of the SDWebImage-YYCache package.
 *
 * For the full copyright and license information, please view the LICENSE
 * file that was distributed with this source code.
 */

#import <YYCache/YYDiskCache.h>
#import <SDWebImage/SDWebImage.h>

/// YYDiskCache category to support `SDDiskCache` protocol. This allow user who prefer YYDiskCache to be used as SDWebImage's custom disk cache
@interface YYDiskCache (SDAdditions) <SDDiskCache>

@end
