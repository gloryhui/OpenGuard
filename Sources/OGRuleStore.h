#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

extern NSString * const OGRuleExtensionKey;
extern NSString * const OGRuleBundleIdentifierKey;
extern NSString * const OGRuleApplicationNameKey;
extern NSString * const OGRuleApplicationPathKey;

@interface OGRuleStore : NSObject
@property (nonatomic, copy) NSArray<NSDictionary *> *rules;
@property (nonatomic) BOOL monitoringEnabled;
- (void)save;
- (void)addOrReplaceRule:(NSDictionary *)rule;
- (void)removeRuleAtIndex:(NSUInteger)index;
@end

NS_ASSUME_NONNULL_END

