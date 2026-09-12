#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

extern NSString * const OGRuleExtensionKey;
extern NSString * const OGRuleNameKey;
extern NSString * const OGRuleBundleIdentifierKey;
extern NSString * const OGRuleApplicationNameKey;
extern NSString * const OGRuleApplicationPathKey;
extern NSString * const OGGroupIdentifierKey;
extern NSString * const OGGroupTitleKey;
extern NSString * const OGGroupItemsKey;

@interface OGRuleStore : NSObject
@property (nonatomic, copy) NSArray<NSDictionary *> *groups;
@property (nonatomic) BOOL monitoringEnabled;
- (void)save;
- (NSArray<NSDictionary *> *)effectiveRules;
- (nullable NSDictionary *)groupWithIdentifier:(NSString *)identifier;
- (void)setApplication:(NSDictionary *)application forGroup:(NSString *)identifier;
- (void)setApplication:(NSDictionary *)application forExtension:(NSString *)extension inGroup:(NSString *)identifier;
- (void)removeGroup:(NSString *)identifier;
- (void)restoreDefaultGroups;
@end

NS_ASSUME_NONNULL_END

