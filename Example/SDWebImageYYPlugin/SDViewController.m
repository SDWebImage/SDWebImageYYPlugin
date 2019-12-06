//
//  SDViewController.m
//  SDWebImageYYPlugin
//
//  Created by DreamPiggy on 05/07/2018.
//  Copyright (c) 2018 DreamPiggy. All rights reserved.
//

#import "SDViewController.h"
#import <SDWebImageYYPlugin/SDWebImageYYPlugin.h>
#import <YYImage/YYImage.h>

@interface SDViewController ()

@property (nonatomic, strong) YYAnimatedImageView *imageView;

@end

@implementation SDViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    // Setup YYCache to default cache
    SDWebImageManager.defaultImageCache = [[YYCache alloc] initWithName:@"YYCache"];
    
    [self.view addSubview:self.imageView];
    [SDWebImageManager.sharedManager.imageCache clearWithCacheType:SDImageCacheTypeAll completion:nil];
    SDWebImageManager.sharedManager.cacheSerializer = [SDWebImageCacheSerializer cacheSerializerWithBlock:^NSData * _Nullable(UIImage * _Nonnull image, NSData * _Nullable data, NSURL * _Nullable imageURL) {
        image.sd_extendedObject = @"Extended Data Here";
        return data;
    }];
    
    NSURL *url = [NSURL URLWithString:@"http://apng.onevcat.com/assets/elephant.png"];
    [self.imageView sd_setImageWithURL:url completed:^(UIImage * _Nullable image, NSError * _Nullable error, SDImageCacheType cacheType, NSURL * _Nullable imageURL) {
        NSString *extentedObject = (NSString *)image.sd_extendedObject;
        NSLog(@"%@", extentedObject);
    }];
}

- (YYAnimatedImageView *)imageView {
    if (!_imageView) {
        _imageView = [[YYAnimatedImageView alloc] initWithFrame:self.view.bounds];
        _imageView.contentMode = UIViewContentModeScaleAspectFit;
        _imageView.autoresizingMask = UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin | UIViewAutoresizingFlexibleBottomMargin;
    }
    return _imageView;
}

@end
