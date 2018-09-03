/*
 * This file is part of the SDWebImage package.
 * (c) Olivier Poitrey <rs@dailymotion.com>
 * (c) Matt Galloway
 *
 * For the full copyright and license information, please view the LICENSE
 * file that was distributed with this source code.
 */

#import "SDTestCase.h"

@interface SDYYImageTests : SDTestCase

@property (nonatomic, strong) UIWindow *window;

@end

@implementation SDYYImageTests

- (void)tearDown {
    for (UIView *view in self.window.subviews) {
        [view removeFromSuperview];
    }
}

- (void)testYYAnimatedImageViewSetImageWithURL {
    XCTestExpectation *expectation = [self expectationWithDescription:@"YYAnimatedImageView setImageWithURL"];
    
    YYAnimatedImageView *imageView = [[YYAnimatedImageView alloc] init];
    NSURL *originalImageURL = [NSURL URLWithString:kTestGIFURL];
    
    [imageView sd_setImageWithURL:originalImageURL
                        completed:^(UIImage * _Nullable image, NSError * _Nullable error, SDImageCacheType cacheType, NSURL * _Nullable imageURL) {
                            expect(image).toNot.beNil();
                            expect(error).to.beNil();
                            expect(originalImageURL).to.equal(imageURL);
                            
                            expect(imageView.image.class).to.equal(YYImage.class);
                            [expectation fulfill];
                        }];
    [self waitForExpectationsWithCommonTimeout];
}

- (void)testSDAnimatedImageWorksForYYAnimatedImageView {
    YYAnimatedImageView *imageView = [[YYAnimatedImageView alloc] init];
    [self.window addSubview:imageView];
    SDAnimatedImage *image = [SDAnimatedImage imageWithData:[self testGIFData]];
    imageView.image = image;
    expect(imageView.image).notTo.beNil();
    expect(imageView.currentAnimatedImageIndex).to.equal(0); // current frame
    expect(imageView.currentIsPlayingAnimation).to.beTruthy(); // animating
}

- (void)testYYImageWorksForSDAnimatedImageView {
    SDAnimatedImageView *imageView = [SDAnimatedImageView new];
    [self.window addSubview:imageView];
    YYImage *image = [YYImage imageWithData:[self testGIFData]];
    imageView.image = image;
    expect(imageView.image).notTo.beNil();
    expect(imageView.currentFrame).notTo.beNil(); // current frame
    expect(imageView.isAnimating).to.beTruthy(); // animating
}

- (void)testSDImageYYCoderStaticWebPCoderWorks {
    NSURL *staticWebPURL = [[NSBundle bundleForClass:[self class]] URLForResource:@"TestImageStatic" withExtension:@"webp"];
    [self verifyCoder:[SDImageYYCoder sharedCoder]
    withLocalImageURL:staticWebPURL
     supportsEncoding:YES
      isAnimatedImage:NO];
}

- (void)testSDImageYYCoderAnimatedWebPCoderWorks {
    NSURL *animatedWebPURL = [[NSBundle bundleForClass:[self class]] URLForResource:@"TestImageAnimated" withExtension:@"webp"];
    [self verifyCoder:[SDImageYYCoder sharedCoder]
    withLocalImageURL:animatedWebPURL
     supportsEncoding:YES
      isAnimatedImage:YES];
}

- (void)testSDImageYYCoderAPNGPCoderWorks {
    NSURL *animatedWebPURL = [[NSBundle bundleForClass:[self class]] URLForResource:@"TestImageAnimated" withExtension:@"apng"];
    [self verifyCoder:[SDImageYYCoder sharedCoder]
    withLocalImageURL:animatedWebPURL
     supportsEncoding:YES
      isAnimatedImage:YES];
}

- (void)testSDImageYYCoderGIFCoderWorks {
    NSURL *gifURL = [[NSBundle bundleForClass:[self class]] URLForResource:@"TestImage" withExtension:@"gif"];
    [self verifyCoder:[SDImageYYCoder sharedCoder]
    withLocalImageURL:gifURL
     supportsEncoding:YES
      isAnimatedImage:YES];
}

- (void)verifyCoder:(id<SDImageCoder>)coder
  withLocalImageURL:(NSURL *)imageUrl
   supportsEncoding:(BOOL)supportsEncoding
    isAnimatedImage:(BOOL)isAnimated {
    NSData *inputImageData = [NSData dataWithContentsOfURL:imageUrl];
    expect(inputImageData).toNot.beNil();
    SDImageFormat inputImageFormat = [NSData sd_imageFormatForImageData:inputImageData];
    expect(inputImageFormat).toNot.equal(SDImageFormatUndefined);
    
    // 1 - check if we can decode - should be true
    expect([coder canDecodeFromData:inputImageData]).to.beTruthy();
    
    // 2 - decode from NSData to UIImage and check it
    UIImage *inputImage = [coder decodedImageWithData:inputImageData options:nil];
    expect(inputImage).toNot.beNil();
    
    if (isAnimated) {
        // 2a - check images count > 0 (only for animated images)
        expect(inputImage.sd_isAnimated).to.beTruthy();
        
        // 2b - check image size and scale for each frameImage (only for animated images)
#if SD_UIKIT
        CGSize imageSize = inputImage.size;
        CGFloat imageScale = inputImage.scale;
        [inputImage.images enumerateObjectsUsingBlock:^(UIImage * frameImage, NSUInteger idx, BOOL * stop) {
            expect(imageSize).to.equal(frameImage.size);
            expect(imageScale).to.equal(frameImage.scale);
        }];
#endif
    }
    
    if (supportsEncoding) {
        // 3 - check if we can encode to the original format
        expect([coder canEncodeToFormat:inputImageFormat]).to.beTruthy();
        
        // 4 - encode from UIImage to NSData using the inputImageFormat and check it
        NSData *outputImageData = [coder encodedDataWithImage:inputImage format:inputImageFormat options:nil];
        expect(outputImageData).toNot.beNil();
        UIImage *outputImage = [coder decodedImageWithData:outputImageData options:nil];
        expect(outputImage.size).to.equal(inputImage.size);
        expect(outputImage.scale).to.equal(inputImage.scale);
#if SD_UIKIT
        expect(outputImage.images.count).to.equal(inputImage.images.count);
#endif
    }
}

#pragma mark - Util

- (NSString *)testGIFPath {
    NSBundle *testBundle = [NSBundle bundleForClass:[self class]];
    return [testBundle pathForResource:@"TestImage" ofType:@"gif"];
}

- (NSData *)testGIFData {
    NSData *testData = [NSData dataWithContentsOfFile:[self testGIFPath]];
    return testData;
}

#pragma mark - Helper

- (UIWindow *)window {
    if (!_window) {
        UIScreen *mainScreen = [UIScreen mainScreen];
        _window = [[UIWindow alloc] initWithFrame:mainScreen.bounds];
    }
    return _window;
}

@end

