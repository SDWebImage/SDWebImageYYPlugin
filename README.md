# SDWebImageYYPlugin

[![CI Status](https://img.shields.io/travis/DreamPiggy/SDWebImageYYPlugin.svg?style=flat)](https://travis-ci.org/DreamPiggy/SDWebImageYYPlugin)
[![Version](https://img.shields.io/cocoapods/v/SDWebImageYYPlugin.svg?style=flat)](https://cocoapods.org/pods/SDWebImageYYPlugin)
[![License](https://img.shields.io/cocoapods/l/SDWebImageYYPlugin.svg?style=flat)](https://cocoapods.org/pods/SDWebImageYYPlugin)
[![Platform](https://img.shields.io/cocoapods/p/SDWebImageYYPlugin.svg?style=flat)](https://cocoapods.org/pods/SDWebImageYYPlugin)


## What's for
SDWebImageYYPlugin is a plugin for [SDWebImage](https://github.com/rs/SDWebImage/) framework, which provide the image loading support for [YYImage](https://github.com/ibireme/YYImage) (including YYImage's decoding system and `YYAnimatedImageView`) and [YYCache](https://github.com/ibireme/YYCache) cache system.

By using SDWebImageYYPlugin, you can use all you familiar SDWebImage's loading method, on the `YYAnimatedImageView`.

And you can also use `YYCache` instead of `SDImageCache` for image cache system, which may better memory cache performance (By taking advanced of LRU algorithm), and disk cache performance (By taking advanced of sqlite blob storage)

## Usage
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

To enable `YYCache` instead of `SDImageCache`, you can bind the cache for shared manager, or create a custom manager instead.

You can also use `YYMemoryCache` or `YYDiskcache` to customize memory cache / disk cache only. See [Custom Cache](https://github.com/rs/SDWebImage/wiki/Advanced-Usage#custom-cache-50) wiki in SDWebImage.

+ Objective-C

```objectivec
// Assign to shared manager
SDWebImageManger.defaultCache = [YYCache sharedCache];
```

+ Swift

```swift
SDWebImageManger.defaultCache = YYCache.shared
```

## Requirements

+ iOS 8+
+ Xcode 9+

## Installation

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

## Author

DreamPiggy, lizhuoli1126@126.com

## License

SDWebImageYYPlugin is available under the MIT license. See the LICENSE file for more info.


