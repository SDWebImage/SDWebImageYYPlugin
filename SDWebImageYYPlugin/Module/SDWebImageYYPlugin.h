#ifdef __OBJC__
#import <UIKit/UIKit.h>
#else
#ifndef FOUNDATION_EXPORT
#if defined(__cplusplus)
#define FOUNDATION_EXPORT extern "C"
#else
#define FOUNDATION_EXPORT extern
#endif
#endif
#endif

// YYCache
#if __has_include(<SDWebImageYYPlugin/YYDiskCache+SDAddtions.h>)
#import <SDWebImageYYPlugin/YYDiskCache+SDAddtions.h>
#import <SDWebImageYYPlugin/YYMemoryCache+SDAddtions.h>
#endif

// YYImage
#if __has_include(<SDWebImageYYPlugin/YYImage+SDAddtions.h>)
#import <SDWebImageYYPlugin/SDAnimatedImage+YYAddtions.h>
#import <SDWebImageYYPlugin/YYAnimatedImageView+WebCache.h>
#import <SDWebImageYYPlugin/YYImage+SDAddtions.h>
#endif

FOUNDATION_EXPORT double SDWebImageYYPluginVersionNumber;
FOUNDATION_EXPORT const unsigned char SDWebImageYYPluginVersionString[];

