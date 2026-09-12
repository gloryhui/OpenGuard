#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface OGLaunchAgent : NSObject
+ (BOOL)isEnabled;
+ (BOOL)setEnabled:(BOOL)enabled error:(NSError **)error;
+ (NSString *)plistPath;
@end

NS_ASSUME_NONNULL_END

