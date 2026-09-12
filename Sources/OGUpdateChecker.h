#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@class OGUpdateChecker;

@protocol OGUpdateCheckerDelegate <NSObject>
- (void)updateChecker:(OGUpdateChecker *)checker
 didFindNewVersion:(NSString *)version
          releaseURL:(NSURL *)releaseURL;
@end

@interface OGUpdateChecker : NSObject

- (instancetype)initWithCurrentVersion:(NSString *)currentVersion
                               delegate:(id<OGUpdateCheckerDelegate>)delegate;
- (void)start;
- (void)stop;
- (void)checkNow;
- (void)checkNowWithCompletion:(void (^)(NSString * _Nullable version,
                                         NSURL * _Nullable releaseURL,
                                         NSError * _Nullable error))completion;

+ (BOOL)isVersion:(NSString *)candidate newerThanVersion:(NSString *)currentVersion;

@end

NS_ASSUME_NONNULL_END
