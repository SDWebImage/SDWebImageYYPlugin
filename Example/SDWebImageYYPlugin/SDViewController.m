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
    [self.view addSubview:self.imageView];
    
    NSURL *url = [NSURL URLWithString:@"http://apng.onevcat.com/assets/elephant.png"];
    [self.imageView sd_setImageWithURL:url completed:^(UIImage * _Nullable image, NSError * _Nullable error, SDImageCacheType cacheType, NSURL * _Nullable imageURL) {
        NSLog(@"%@", error);
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
