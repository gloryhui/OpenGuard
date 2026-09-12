#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface OGLanguage : NSObject
@property (nonatomic, copy) NSString *code;
+ (instancetype)shared;
+ (NSArray<NSDictionary<NSString *, NSString *> *> *)supportedLanguages;
- (NSString *)text:(NSString *)key;
- (BOOL)hasCompleteTranslations;
@end

NS_ASSUME_NONNULL_END

