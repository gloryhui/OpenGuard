#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

extern NSString * const OGRuleExtensionKey;
extern NSString * const OGRuleIdentifierKey;
extern NSString * const OGRuleNameKey;
extern NSString * const OGRuleBundleIdentifierKey;
extern NSString * const OGRuleApplicationNameKey;
extern NSString * const OGRuleApplicationPathKey;
extern NSString * const OGGroupIdentifierKey;
extern NSString * const OGGroupTitleKey;
extern NSString * const OGGroupNameKey;
extern NSString * const OGGroupItemsKey;

@interface OGRuleStore : NSObject
@property (nonatomic, copy) NSArray<NSDictionary *> *rootItems;
@property (nonatomic, readonly) NSArray<NSDictionary *> *groups;
@property (nonatomic) BOOL monitoringEnabled;
- (instancetype)initWithUserDefaults:(NSUserDefaults *)userDefaults;
- (void)save;
- (NSArray<NSDictionary *> *)effectiveRules;
- (nullable NSDictionary *)groupWithIdentifier:(NSString *)identifier;
- (BOOL)containsRuleWithExtension:(NSString *)extension;
- (nullable NSDictionary *)ruleWithIdentifier:(NSString *)identifier;
- (NSString *)addDraftRuleToGroup:(nullable NSString *)groupIdentifier;
- (BOOL)updateRule:(NSString *)identifier extension:(NSString *)extension name:(NSString *)name;
- (void)removeRule:(NSString *)identifier;
- (NSString *)addGroupWithTitle:(NSString *)title;
- (BOOL)addRuleWithExtension:(NSString *)extension
                        name:(NSString *)name
                     toGroup:(nullable NSString *)identifier;
- (void)renameGroup:(NSString *)identifier title:(NSString *)title;
- (void)setApplication:(NSDictionary *)application forGroup:(NSString *)identifier;
- (void)setApplication:(NSDictionary *)application forRule:(NSString *)identifier;
- (void)setApplication:(NSDictionary *)application
           forExtension:(NSString *)extension
                 inGroup:(nullable NSString *)identifier;
- (void)removeGroup:(NSString *)identifier;
- (void)removeGroupAndRules:(NSString *)identifier;
- (BOOL)moveGroup:(NSString *)identifier toIndex:(NSUInteger)index;
- (BOOL)moveRuleWithExtension:(NSString *)extension
                    fromGroup:(nullable NSString *)sourceIdentifier
                      toGroup:(nullable NSString *)destinationIdentifier
                      atIndex:(NSUInteger)index;
- (void)restoreDefaultGroups;
@end

NS_ASSUME_NONNULL_END
