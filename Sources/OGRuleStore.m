#import "OGRuleStore.h"
#import "OGPresets.h"
#import <AppKit/AppKit.h>

NSString * const OGRuleExtensionKey = @"extension";
NSString * const OGRuleNameKey = @"name";
NSString * const OGRuleBundleIdentifierKey = @"bundleIdentifier";
NSString * const OGRuleApplicationNameKey = @"applicationName";
NSString * const OGRuleApplicationPathKey = @"applicationPath";
NSString * const OGGroupIdentifierKey = @"identifier";
NSString * const OGGroupTitleKey = @"titleKey";
NSString * const OGGroupItemsKey = @"items";

static NSString * const OGGroupsDefaultsKey = @"groups.v3";
static NSString * const OGLegacyGroupsDefaultsKey = @"groups.v2";
static NSString * const OGLegacyRulesDefaultsKey = @"rules.v1";
static NSString * const OGMonitoringDefaultsKey = @"monitoringEnabled";

@implementation OGRuleStore

- (instancetype)init {
    self = [super init];
    if (!self) return nil;
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSArray *saved = [defaults arrayForKey:OGGroupsDefaultsKey];
    if (saved) {
        _groups = saved;
    } else {
        NSArray *oldGroups = [defaults arrayForKey:OGLegacyGroupsDefaultsKey];
        NSArray *legacy = oldGroups ? [self rulesFromGroups:oldGroups]
                                    : ([defaults arrayForKey:OGLegacyRulesDefaultsKey] ?: [self initialVSCodeRule]);
        _groups = [self groupsByApplyingLegacyRules:legacy toGroups:[OGPresets defaultGroups]];
    }
    _monitoringEnabled = [defaults objectForKey:OGMonitoringDefaultsKey]
        ? [defaults boolForKey:OGMonitoringDefaultsKey] : YES;
    [self save];
    return self;
}

- (NSArray<NSDictionary *> *)rulesFromGroups:(NSArray<NSDictionary *> *)groups {
    NSMutableArray *rules = [NSMutableArray array];
    for (NSDictionary *group in groups) {
        for (NSDictionary *item in group[OGGroupItemsKey] ?: @[]) {
            NSString *bundleID = item[OGRuleBundleIdentifierKey] ?: group[OGRuleBundleIdentifierKey];
            if (!bundleID) continue;
            NSMutableDictionary *rule = [item mutableCopy];
            if (!item[OGRuleBundleIdentifierKey]) {
                rule[OGRuleBundleIdentifierKey] = bundleID;
                rule[OGRuleApplicationNameKey] = group[OGRuleApplicationNameKey];
                rule[OGRuleApplicationPathKey] = group[OGRuleApplicationPathKey];
            }
            [rules addObject:rule];
        }
    }
    return rules;
}

- (NSArray<NSDictionary *> *)initialVSCodeRule {
    NSString *path = [[NSWorkspace sharedWorkspace] absolutePathForAppBundleWithIdentifier:@"com.microsoft.VSCode"];
    if (!path) return @[];
    return @[@{OGRuleExtensionKey: @"md", OGRuleBundleIdentifierKey: @"com.microsoft.VSCode",
               OGRuleApplicationNameKey: @"Visual Studio Code", OGRuleApplicationPathKey: path}];
}

- (NSArray<NSDictionary *> *)groupsByApplyingLegacyRules:(NSArray<NSDictionary *> *)rules
                                                 toGroups:(NSArray<NSDictionary *> *)groups {
    NSMutableDictionary *byExtension = [NSMutableDictionary dictionary];
    for (NSDictionary *rule in rules) if (rule[OGRuleExtensionKey]) byExtension[rule[OGRuleExtensionKey]] = rule;
    NSMutableArray *result = [NSMutableArray array];
    NSMutableSet *matched = [NSMutableSet set];
    for (NSDictionary *group in groups) {
        NSMutableDictionary *nextGroup = [group mutableCopy];
        NSMutableArray *items = [NSMutableArray array];
        for (NSDictionary *item in group[OGGroupItemsKey]) {
            NSMutableDictionary *nextItem = [item mutableCopy];
            NSDictionary *rule = byExtension[item[OGRuleExtensionKey]];
            if (rule) {
                [self copyApplicationFrom:rule to:nextItem];
                [matched addObject:item[OGRuleExtensionKey]];
            }
            [items addObject:nextItem];
        }
        nextGroup[OGGroupItemsKey] = items;
        [result addObject:nextGroup];
    }
    NSMutableArray *customItems = [NSMutableArray array];
    for (NSDictionary *rule in rules) {
        if (![matched containsObject:rule[OGRuleExtensionKey]]) {
            NSMutableDictionary *item = [@{OGRuleExtensionKey: rule[OGRuleExtensionKey],
                                            OGRuleNameKey: rule[OGRuleExtensionKey]} mutableCopy];
            [self copyApplicationFrom:rule to:item];
            [customItems addObject:item];
        }
    }
    if (customItems.count) {
        [result addObject:@{OGGroupIdentifierKey: @"custom", OGGroupTitleKey: @"group_custom",
                            OGGroupItemsKey: customItems}];
    }
    return result;
}

- (void)copyApplicationFrom:(NSDictionary *)source to:(NSMutableDictionary *)destination {
    for (NSString *key in @[OGRuleBundleIdentifierKey, OGRuleApplicationNameKey, OGRuleApplicationPathKey]) {
        if (source[key]) destination[key] = source[key];
        else [destination removeObjectForKey:key];
    }
}

- (void)save {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [defaults setObject:self.groups forKey:OGGroupsDefaultsKey];
    [defaults setBool:self.monitoringEnabled forKey:OGMonitoringDefaultsKey];
}

- (NSDictionary *)groupWithIdentifier:(NSString *)identifier {
    for (NSDictionary *group in self.groups) if ([group[OGGroupIdentifierKey] isEqualToString:identifier]) return group;
    return nil;
}

- (NSArray<NSDictionary *> *)effectiveRules {
    NSMutableArray *rules = [NSMutableArray array];
    for (NSDictionary *group in self.groups) {
        for (NSDictionary *item in group[OGGroupItemsKey]) {
            NSString *bundleID = item[OGRuleBundleIdentifierKey] ?: group[OGRuleBundleIdentifierKey];
            if (!bundleID) continue;
            NSMutableDictionary *rule = [item mutableCopy];
            if (!item[OGRuleBundleIdentifierKey]) {
                rule[OGRuleBundleIdentifierKey] = bundleID;
                rule[OGRuleApplicationNameKey] = group[OGRuleApplicationNameKey];
                rule[OGRuleApplicationPathKey] = group[OGRuleApplicationPathKey];
            }
            [rules addObject:rule];
        }
    }
    return rules;
}

- (void)setApplication:(NSDictionary *)application forGroup:(NSString *)identifier {
    NSMutableArray *groups = [self.groups mutableCopy];
    for (NSUInteger index = 0; index < groups.count; index++) {
        NSDictionary *group = groups[index];
        if (![group[OGGroupIdentifierKey] isEqualToString:identifier]) continue;
        NSMutableDictionary *next = [group mutableCopy];
        [self copyApplicationFrom:application to:next];
        NSMutableArray *items = [NSMutableArray array];
        for (NSDictionary *item in group[OGGroupItemsKey]) {
            NSMutableDictionary *cleanItem = [item mutableCopy];
            for (NSString *key in @[OGRuleBundleIdentifierKey, OGRuleApplicationNameKey, OGRuleApplicationPathKey])
                [cleanItem removeObjectForKey:key];
            [items addObject:cleanItem];
        }
        next[OGGroupItemsKey] = items;
        groups[index] = next;
        break;
    }
    self.groups = groups;
    [self save];
}

- (void)setApplication:(NSDictionary *)application forExtension:(NSString *)extension inGroup:(NSString *)identifier {
    NSMutableArray *groups = [self.groups mutableCopy];
    for (NSUInteger groupIndex = 0; groupIndex < groups.count; groupIndex++) {
        NSDictionary *group = groups[groupIndex];
        if (![group[OGGroupIdentifierKey] isEqualToString:identifier]) continue;
        NSMutableArray *items = [group[OGGroupItemsKey] mutableCopy];
        for (NSUInteger itemIndex = 0; itemIndex < items.count; itemIndex++) {
            NSDictionary *item = items[itemIndex];
            if (![item[OGRuleExtensionKey] isEqualToString:extension]) continue;
            NSMutableDictionary *nextItem = [item mutableCopy];
            [self copyApplicationFrom:application to:nextItem];
            items[itemIndex] = nextItem;
            break;
        }
        NSMutableDictionary *nextGroup = [group mutableCopy];
        nextGroup[OGGroupItemsKey] = items;
        groups[groupIndex] = nextGroup;
        break;
    }
    self.groups = groups;
    [self save];
}

- (void)removeGroup:(NSString *)identifier {
    self.groups = [self.groups filteredArrayUsingPredicate:
                   [NSPredicate predicateWithBlock:^BOOL(NSDictionary *group, NSDictionary *bindings) {
        return ![group[OGGroupIdentifierKey] isEqualToString:identifier];
    }]];
    [self save];
}

- (void)restoreDefaultGroups {
    NSMutableArray *restored = [NSMutableArray array];
    for (NSDictionary *templateGroup in [OGPresets defaultGroups]) {
        NSDictionary *existing = [self groupWithIdentifier:templateGroup[OGGroupIdentifierKey]];
        NSMutableDictionary *group = [templateGroup mutableCopy];
        if (existing) [self copyApplicationFrom:existing to:group];
        NSMutableDictionary *existingItems = [NSMutableDictionary dictionary];
        for (NSDictionary *item in existing[OGGroupItemsKey] ?: @[]) existingItems[item[OGRuleExtensionKey]] = item;
        NSMutableArray *items = [NSMutableArray array];
        for (NSDictionary *templateItem in templateGroup[OGGroupItemsKey]) {
            NSMutableDictionary *item = [templateItem mutableCopy];
            NSDictionary *existingItem = existingItems[item[OGRuleExtensionKey]];
            if (existingItem) [self copyApplicationFrom:existingItem to:item];
            [items addObject:item];
        }
        group[OGGroupItemsKey] = items;
        [restored addObject:group];
    }
    self.groups = restored;
    [self save];
}

@end
