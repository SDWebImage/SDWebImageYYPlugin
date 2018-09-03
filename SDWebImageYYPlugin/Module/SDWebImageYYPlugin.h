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
#if __has_include(<SDWebImageYYPlugin/YYCache+SDAdditions.h>)
#import <SDWebImageYYPlugin/YYCache+SDAdditions.h>
#import <SDWebImageYYPlugin/YYMemoryCache+SDAdditions.h>
#import <SDWebImageYYPlugin/YYDiskCache+SDAdditions.h>
#endif

// YYImage
#if __has_include(<SDWebImageYYPlugin/YYImage+SDAdditions.h>)
#import <SDWebImageYYPlugin/SDAnimatedImage+YYAdditions.h>
#import <SDWebImageYYPlugin/YYAnimatedImageView+WebCache.h>
#import <SDWebImageYYPlugin/YYImage+SDAdditions.h>
#import <SDWebImageYYPlugin/SDImageYYCoder.h>
#endif

FOUNDATION_EXPORT double SDWebImageYYPluginVersionNumber;
FOUNDATION_EXPORT const unsigned char SDWebImageYYPluginVersionString[];

