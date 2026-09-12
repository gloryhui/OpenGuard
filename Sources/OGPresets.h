#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface OGPresets : NSObject
+ (NSArray<NSDictionary<NSString *, NSString *> *> *)all;
+ (NSArray<NSDictionary *> *)defaultGroups;
@end

NS_ASSUME_NONNULL_END
