/*
 * This file is part of the SDWebImageYYPlugin package.
 *
 * For the full copyright and license information, please view the LICENSE
 * file that was distributed with this source code.
 */

#import "SDTestCase.h"

static NSString *kTestImageKeyJPEG = @"TestImageKey.jpg";
static NSString *kTestImageKeyPNG = @"TestImageKey.png";

@interface SDImageCache ()

@property (nonatomic, strong, nonnull) id<SDMemoryCache> memCache;
@property (nonatomic, strong, nonnull) id<SDDiskCache> diskCache;

@end

@interface SDYYCacheTests : SDTestCase

@property (nonatomic, class, readonly) YYCache *sharedCache;

@end

@implementation SDYYCacheTests

+ (YYCache *)sharedCache {
    static dispatch_once_t onceToken;
    static YYCache *cache;
    dispatch_once(&onceToken, ^{
        cache = [YYCache cacheWithName:@"default"];
    });
    return cache;
}

#pragma mark - YYMemoryCache & YYDiskCache
- (void)testCustomMemoryCache {
    SDImageCacheConfig *config = [[SDImageCacheConfig alloc] init];
    config.memoryCacheClass = [YYMemoryCache class];
    NSString *nameSpace = @"YYMemoryCache";
    NSString *cacheDictionary = [self makeDiskCachePath:nameSpace];
    SDImageCache *cache = [[SDImageCache alloc] initWithNamespace:nameSpace diskCacheDirectory:cacheDictionary config:config];
    YYMemoryCache *memCache = cache.memCache;
    expect([memCache isKindOfClass:[YYMemoryCache class]]).to.beTruthy();
}

- (void)testCustomDiskCache {
    SDImageCacheConfig *config = [[SDImageCacheConfig alloc] init];
    config.diskCacheClass = [YYDiskCache class];
    NSString *nameSpace = @"YYDiskCache";
    NSString *cacheDictionary = [self makeDiskCachePath:nameSpace];
    SDImageCache *cache = [[SDImageCache alloc] initWithNamespace:nameSpace diskCacheDirectory:cacheDictionary config:config];
    YYDiskCache *diskCache = cache.diskCache;
    expect([diskCache isKindOfClass:[YYDiskCache class]]).to.beTruthy();
}

#pragma mark - YYCache

- (void)testCustomImageCache {
    SDWebImageManager *manager = [[SDWebImageManager alloc] initWithCache:SDYYCacheTests.sharedCache loader:SDWebImageDownloader.sharedDownloader];
    expect(manager.imageCache).to.equal(SDYYCacheTests.sharedCache);
}

- (void)testYYCacheQueryOp {
    XCTestExpectation *expectation = [self expectationWithDescription:@"SDImageCache query op works"];
    NSData *imageData = [NSData dataWithContentsOfFile:[self testJPEGPath]];
    [SDYYCacheTests.sharedCache.diskCache setObject:imageData forKey:kTestImageKeyJPEG];
    [SDYYCacheTests.sharedCache queryImageForKey:kTestImageKeyJPEG options:0 context:nil completion:^(UIImage * _Nullable image, NSData * _Nullable data, SDImageCacheType cacheType) {
        expect(image).notTo.beNil();
        [expectation fulfill];
    }];
    [self waitForExpectationsWithCommonTimeout];
}

- (void)testYYCacheStoreOp {
    XCTestExpectation *expectation = [self expectationWithDescription:@"SDImageCache store op works"];
    [SDYYCacheTests.sharedCache storeImage:[self testJPEGImage] imageData:nil forKey:kTestImageKeyJPEG cacheType:SDImageCacheTypeAll completion:^{
        UIImage *memoryImage = [SDYYCacheTests.sharedCache.memoryCache objectForKey:kTestImageKeyJPEG];
        expect(memoryImage).notTo.beNil();
        NSData *diskData = (NSData *)[SDYYCacheTests.sharedCache.diskCache objectForKey:kTestImageKeyJPEG];
        expect(diskData).notTo.beNil();
        [expectation fulfill];
    }];
    [self waitForExpectationsWithCommonTimeout];
}

- (void)testYYCacheRemoveOp {
    XCTestExpectation *expectation = [self expectationWithDescription:@"SDImageCache remove op works"];
    [SDYYCacheTests.sharedCache removeImageForKey:kTestImageKeyJPEG cacheType:SDImageCacheTypeDisk completion:^{
        UIImage *memoryImage = [SDYYCacheTests.sharedCache.memoryCache objectForKey:kTestImageKeyJPEG];
        expect(memoryImage).notTo.beNil();
        NSData *diskData = (NSData *)[SDYYCacheTests.sharedCache.diskCache objectForKey:kTestImageKeyJPEG];
        expect(diskData).to.beNil();
        [expectation fulfill];
    }];
    [self waitForExpectationsWithCommonTimeout];
}

- (void)testYYCacheContainsOp {
    XCTestExpectation *expectation = [self expectationWithDescription:@"SDImageCache contains op works"];
    [SDYYCacheTests.sharedCache setObject:[self testPNGImage] forKey:kTestImageKeyPNG];
    [SDYYCacheTests.sharedCache containsImageForKey:kTestImageKeyPNG cacheType:SDImageCacheTypeAll completion:^(SDImageCacheType containsCacheType) {
        expect(containsCacheType).equal(SDImageCacheTypeMemory);
        [expectation fulfill];
    }];
    [self waitForExpectationsWithCommonTimeout];
}

- (void)testYYCacheClearOp {
    XCTestExpectation *expectation = [self expectationWithDescription:@"SDImageCache clear op works"];
    [SDYYCacheTests.sharedCache clearWithCacheType:SDImageCacheTypeAll completion:^{
        UIImage *memoryImage = [SDYYCacheTests.sharedCache.memoryCache objectForKey:kTestImageKeyJPEG];
        expect(memoryImage).to.beNil();
        NSData *diskData = (NSData *)[SDYYCacheTests.sharedCache.diskCache objectForKey:kTestImageKeyJPEG];
        expect(diskData).to.beNil();
        [expectation fulfill];
    }];
    [self waitForExpectationsWithCommonTimeout];
}

#pragma mark Helper methods

- (UIImage *)testJPEGImage {
    static UIImage *reusableImage = nil;
    if (!reusableImage) {
        reusableImage = [[UIImage alloc] initWithContentsOfFile:[self testJPEGPath]];
    }
    return reusableImage;
}

- (UIImage *)testPNGImage {
    static UIImage *reusableImage = nil;
    if (!reusableImage) {
        reusableImage = [[UIImage alloc] initWithContentsOfFile:[self testPNGPath]];
    }
    return reusableImage;
}

- (NSString *)testJPEGPath {
    NSBundle *testBundle = [NSBundle bundleForClass:[self class]];
    return [testBundle pathForResource:@"TestImage" ofType:@"jpg"];
}

- (NSString *)testPNGPath {
    NSBundle *testBundle = [NSBundle bundleForClass:[self class]];
    return [testBundle pathForResource:@"TestImage" ofType:@"png"];
}

- (nullable NSString *)makeDiskCachePath:(nonnull NSString*)fullNamespace {
    NSArray<NSString *> *paths = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES);
    return [paths[0] stringByAppendingPathComponent:fullNamespace];
}

@end
