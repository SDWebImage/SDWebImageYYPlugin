/*
 * This file is part of the SDWebImage-YYCache package.
 *
 * For the full copyright and license information, please view the LICENSE
 * file that was distributed with this source code.
 */

#import <YYCache/YYMemoryCache.h>
#import <SDWebImage/SDWebImage.h>

/// YYMemoryCache category to support `SDMemoryCache` protocol. This allow user who prefer YYMemoryCache to be used as SDWebImage's custom memory cache
@interface YYMemoryCache (SDAdditions) <SDMemoryCache>

@end
