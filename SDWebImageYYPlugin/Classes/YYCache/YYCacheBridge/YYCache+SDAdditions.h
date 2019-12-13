/*
 * This file is part of the SDWebImage-YYCache package.
 *
 * For the full copyright and license information, please view the LICENSE
 * file that was distributed with this source code.
 */


#import <YYCache/YYCache.h>
#import <SDWebImage/SDWebImage.h>

/// YYCache category to support `SDImageCache` protocol. This allow user who prefer YYCache to be used as SDWebImage's custom image cache
@interface YYCache (SDAdditions) <SDImageCache>

@end
