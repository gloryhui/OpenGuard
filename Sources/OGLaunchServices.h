#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface OGLaunchServices : NSObject
+ (nullable NSString *)normalizedExtension:(NSString *)extension;
+ (nullable NSString *)typeIdentifierForExtension:(NSString *)extension;
+ (nullable NSString *)currentHandlerForExtension:(NSString *)extension;
+ (BOOL)setHandler:(NSString *)bundleIdentifier
      forExtension:(NSString *)extension
             error:(NSError **)error;
+ (nullable NSString *)applicationNameForBundleIdentifier:(NSString *)bundleIdentifier;
@end

NS_ASSUME_NONNULL_END

