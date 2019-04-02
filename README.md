# SDWebImageYYPlugin

[![CI Status](https://img.shields.io/travis/SDWebImage/SDWebImageYYPlugin.svg?style=flat)](https://travis-ci.org/SDWebImage/SDWebImageYYPlugin)
[![Version](https://img.shields.io/cocoapods/v/SDWebImageYYPlugin.svg?style=flat)](https://cocoapods.org/pods/SDWebImageYYPlugin)
[![License](https://img.shields.io/cocoapods/l/SDWebImageYYPlugin.svg?style=flat)](https://cocoapods.org/pods/SDWebImageYYPlugin)
[![Platform](https://img.shields.io/cocoapods/p/SDWebImageYYPlugin.svg?style=flat)](https://cocoapods.org/pods/SDWebImageYYPlugin)
[![Carthage compatible](https://img.shields.io/badge/Carthage-compatible-4BC51D.svg?style=flat)](https://github.com/SDWebImage/SDWebImageYYPlugin)
[![codecov](https://codecov.io/gh/SDWebImage/SDWebImageYYPlugin/branch/master/graph/badge.svg)](https://codecov.io/gh/SDWebImage/SDWebImageYYPlugin)


## What's for
SDWebImageYYPlugin is a plugin for [SDWebImage](https://github.com/rs/SDWebImage/) framework, which provide the image loading support for [YYImage](https://github.com/ibireme/YYImage) (including YYImage's decoding system and `YYAnimatedImageView`) and [YYCache](https://github.com/ibireme/YYCache) cache system.

By using SDWebImageYYPlugin, you can use all you familiar SDWebImage's loading method, on the `YYAnimatedImageView`.

And you can also use `YYCache` instead of `SDImageCache` for image cache system, which may better memory cache performance (By taking advanced of LRU algorithm), and disk cache performance (By taking advanced of sqlite blob storage)

## Usage

#### YYImage Plugin
To load a network image, simply call the View Category method like UIImageView.

+ Objective-C

```objectivec
YYAnimatedImageView *imageView;
[imageView sd_setImageWithURL:[NSURL URLWithString:@"http://www.domain.com/path/to/image.gif"]];
```

+ Swift

```swift
let imageView: YYAnimatedImageView
imageView.sd_setImage(with: URL(string: "http://www.domain.com/path/to/image.gif"))
```

For advanced user, you can embed `YYImageDecoder` && `YYImageEncoder` to SDWebImage by using the wrapper class `SDImageYYCoder`. See [Custom Coder](https://github.com/rs/SDWebImage/wiki/Advanced-Usage#custom-coder-420) wiki in SDWebImage.

+ Objective-C

```objectivec
// Register YYImage decoder/encoder as coder plugin
[SDImageCodersManager.sharedManager addCoder:SDImageYYCoder.sharedCoder];
```

+ Swift

```swift
// Register YYImage decoder/encoder as coder plugin
SDImageCodersManager.shared.addCoder(SDImageYYCoder.shared)
```

#### YYCache Plugin
To enable `YYCache` instead of `SDImageCache`, you can bind the cache for shared manager, or create a custom manager instead.

+ Objective-C

```objectivec
// Use `YYCache` for shared manager
SDWebImageManger.defaultImageCache = [YYCache cacheWithName:@"name"];
```

+ Swift

```swift
// Use `YYCache` for shared manager
SDWebImageManger.defaultImageCache = YYCache(name: "name")
```

You can also use `YYMemoryCache` or `YYDiskcache` to customize memory cache / disk cache only. See [Custom Cache](https://github.com/rs/SDWebImage/wiki/Advanced-Usage#custom-cache-50) wiki in SDWebImage.

+ Objective-C

```objectivec
// Use `YYMemoryCache` for shared `SDImageCache` memory cache implementation
SDImageCacheConfig.defaultCacheConfig.memoryCacheClass = YYMemoryCache.class;
// Use `YYDiskCache` for shared `SDImageCache` disk cache implementation
SDImageCacheConfig.defaultCacheConfig.diskCacheClass = YYDiskCache.class;
```

+ Swift

```swift
// Use `YYMemoryCache` for `SDImageCache` memory cache implementation
SDImageCacheConfig.default.memoryCacheClass = YYMemoryCache.self
// Use `YYDiskCache` for `SDImageCache` disk cache implementation
SDImageCacheConfig.default.diskCacheClass = YYDiskCache.self
```

## Requirements

+ iOS 8+
+ Xcode 9+

## Installation

#### CocoaPods

SDWebImageYYPlugin is available through [CocoaPods](https://cocoapods.org). To install
it, simply add the following line to your Podfile:

```ruby
pod 'SDWebImageYYPlugin'
```

SDWebImageYYPlugin contains two subspecs, `YYCache` and `YYImage`. You can choose to enable only some of them. By default will contains all subspecs.

```ruby
pod 'SDWebImageYYPlugin/YYImage'
pod 'SDWebImageYYPlugin/YYCache'
```

#### Carthage

SDWebImageFLPlugin is available through [Carthage](https://github.com/Carthage/Carthage).

```
github "SDWebImage/SDWebImageYYPlugin"
```

Carthage does not support like CocoaPods' subspec, the built framework will contains both YYCache && YYImage support.

Note because of limit of [YYImage Carthage support](https://github.com/ibireme/YYImage#carthage), YYImage plugin with Carthage will not support WebP format. If you want to support WebP format, use CocoaPods instead.

## Author

DreamPiggy, lizhuoli1126@126.com

## License

SDWebImageYYPlugin is available under the MIT license. See the LICENSE file for more info.


