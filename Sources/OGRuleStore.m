#import "OGRuleStore.h"
#import "OGPresets.h"
#import <AppKit/AppKit.h>

NSString * const OGRuleExtensionKey = @"extension";
NSString * const OGRuleIdentifierKey = @"ruleIdentifier";
NSString * const OGRuleNameKey = @"name";
NSString * const OGRuleBundleIdentifierKey = @"bundleIdentifier";
NSString * const OGRuleApplicationNameKey = @"applicationName";
NSString * const OGRuleApplicationPathKey = @"applicationPath";
NSString * const OGGroupIdentifierKey = @"identifier";
NSString * const OGGroupTitleKey = @"titleKey";
NSString * const OGGroupNameKey = @"title";
NSString * const OGGroupItemsKey = @"items";

static NSString * const OGTreeDefaultsKey = @"tree.v4";
static NSString * const OGGroupsDefaultsKey = @"groups.v3";
static NSString * const OGLegacyGroupsDefaultsKey = @"groups.v2";
static NSString * const OGLegacyRulesDefaultsKey = @"rules.v1";
static NSString * const OGMonitoringDefaultsKey = @"monitoringEnabled";

@interface OGRuleStore ()
@property (nonatomic, strong) NSUserDefaults *userDefaults;
@end

@implementation OGRuleStore

- (instancetype)init {
    return [self initWithUserDefaults:[NSUserDefaults standardUserDefaults]];
}

- (instancetype)initWithUserDefaults:(NSUserDefaults *)userDefaults {
    self = [super init];
    if (!self) return nil;
    _userDefaults = userDefaults;
    NSArray *savedTree = [userDefaults arrayForKey:OGTreeDefaultsKey];
    if (savedTree) {
        _rootItems = [savedTree copy];
    } else {
        NSArray *savedGroups = [userDefaults arrayForKey:OGGroupsDefaultsKey];
        if (savedGroups) {
            _rootItems = [savedGroups copy];
        } else {
            NSArray *oldGroups = [userDefaults arrayForKey:OGLegacyGroupsDefaultsKey];
            NSArray *legacy = oldGroups ? [self rulesFromGroups:oldGroups]
                                        : ([userDefaults arrayForKey:OGLegacyRulesDefaultsKey] ?: [self initialVSCodeRule]);
            _rootItems = [self groupsByApplyingLegacyRules:legacy toGroups:[OGPresets defaultGroups]];
        }
    }
    NSMutableArray *identified = [NSMutableArray array];
    for (NSDictionary *item in _rootItems) {
        NSMutableDictionary *next = [item mutableCopy];
        if ([self isGroup:item]) {
            NSMutableArray *children = [NSMutableArray array];
            for (NSDictionary *rule in item[OGGroupItemsKey]) {
                NSMutableDictionary *child = [rule mutableCopy];
                if (!child[OGRuleIdentifierKey]) child[OGRuleIdentifierKey] = NSUUID.UUID.UUIDString;
                [children addObject:child];
            }
            next[OGGroupItemsKey] = children;
        } else if (!next[OGRuleIdentifierKey]) next[OGRuleIdentifierKey] = NSUUID.UUID.UUIDString;
        [identified addObject:next];
    }
    _rootItems = identified;
    _monitoringEnabled = [userDefaults objectForKey:OGMonitoringDefaultsKey]
        ? [userDefaults boolForKey:OGMonitoringDefaultsKey] : YES;
    [self save];
    return self;
}

- (BOOL)isGroup:(NSDictionary *)item {
    return [item[OGGroupItemsKey] isKindOfClass:[NSArray class]];
}

- (NSArray<NSDictionary *> *)groups {
    return [self.rootItems filteredArrayUsingPredicate:
            [NSPredicate predicateWithBlock:^BOOL(NSDictionary *item, NSDictionary *bindings) {
        return [self isGroup:item];
    }]];
}

- (NSString *)normalizedExtension:(NSString *)extension {
    NSString *normalized = [[extension stringByTrimmingCharactersInSet:
                             [NSCharacterSet whitespaceAndNewlineCharacterSet]] lowercaseString];
    while ([normalized hasPrefix:@"."]) normalized = [normalized substringFromIndex:1];
    return normalized;
}

- (NSArray<NSDictionary *> *)rulesFromGroups:(NSArray<NSDictionary *> *)groups {
    NSMutableArray *rules = [NSMutableArray array];
    for (NSDictionary *group in groups) {
        for (NSDictionary *item in group[OGGroupItemsKey] ?: @[]) {
            NSString *bundleID = item[OGRuleBundleIdentifierKey] ?: group[OGRuleBundleIdentifierKey];
            if (!bundleID) continue;
            NSMutableDictionary *rule = [item mutableCopy];
            if (!item[OGRuleBundleIdentifierKey]) [self copyApplicationFrom:group to:rule];
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
    for (NSDictionary *rule in rules) {
        if ([matched containsObject:rule[OGRuleExtensionKey]]) continue;
        NSMutableDictionary *item = [@{OGRuleExtensionKey: rule[OGRuleExtensionKey],
                                        OGRuleNameKey: rule[OGRuleExtensionKey]} mutableCopy];
        [self copyApplicationFrom:rule to:item];
        [result addObject:item];
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
    [self.userDefaults setObject:self.rootItems forKey:OGTreeDefaultsKey];
    [self.userDefaults setBool:self.monitoringEnabled forKey:OGMonitoringDefaultsKey];
}

- (NSDictionary *)groupWithIdentifier:(NSString *)identifier {
    for (NSDictionary *item in self.rootItems) {
        if ([self isGroup:item] && [item[OGGroupIdentifierKey] isEqualToString:identifier]) return item;
    }
    return nil;
}

- (BOOL)containsRuleWithExtension:(NSString *)extension {
    NSString *normalized = [self normalizedExtension:extension];
    if (!normalized.length) return NO;
    for (NSDictionary *item in self.rootItems) {
        if ([self isGroup:item]) {
            for (NSDictionary *rule in item[OGGroupItemsKey]) {
                if ([rule[OGRuleExtensionKey] isEqualToString:normalized]) return YES;
            }
        } else if ([item[OGRuleExtensionKey] isEqualToString:normalized]) {
            return YES;
        }
    }
    return NO;
}

- (NSArray<NSDictionary *> *)allRulesPreservingApplications {
    NSMutableArray *rules = [NSMutableArray array];
    for (NSDictionary *item in self.rootItems) {
        if (![self isGroup:item]) {
            [rules addObject:[item copy]];
            continue;
        }
        for (NSDictionary *child in item[OGGroupItemsKey]) {
            NSMutableDictionary *rule = [child mutableCopy];
            if (!rule[OGRuleBundleIdentifierKey] && item[OGRuleBundleIdentifierKey]) {
                [self copyApplicationFrom:item to:rule];
            }
            [rules addObject:rule];
        }
    }
    return rules;
}

- (NSArray<NSDictionary *> *)effectiveRules {
    NSMutableArray *rules = [NSMutableArray array];
    for (NSDictionary *rule in [self allRulesPreservingApplications]) {
        if ([rule[OGRuleExtensionKey] length] && rule[OGRuleBundleIdentifierKey]) [rules addObject:rule];
    }
    return rules;
}

- (NSString *)addGroupWithTitle:(NSString *)title {
    NSString *identifier = [[NSUUID UUID] UUIDString];
    NSDictionary *group = @{OGGroupIdentifierKey: identifier,
                            OGGroupNameKey: [title copy],
                            OGGroupItemsKey: @[]};
    self.rootItems = [self.rootItems arrayByAddingObject:group];
    [self save];
    return identifier;
}

- (BOOL)addRuleWithExtension:(NSString *)extension
                        name:(NSString *)name
                     toGroup:(NSString *)identifier {
    NSString *normalized = [self normalizedExtension:extension];
    if (!normalized.length || [self containsRuleWithExtension:normalized]) return NO;
    NSString *trimmedName = [name stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    NSDictionary *rule = @{OGRuleIdentifierKey: NSUUID.UUID.UUIDString, OGRuleExtensionKey: normalized,
                           OGRuleNameKey: trimmedName.length ? trimmedName : normalized.uppercaseString};
    NSMutableArray *rootItems = [self.rootItems mutableCopy];
    if (!identifier.length) {
        [rootItems addObject:rule];
    } else {
        NSUInteger groupIndex = [rootItems indexOfObjectPassingTest:
                                 ^BOOL(NSDictionary *item, NSUInteger index, BOOL *stop) {
            return [self isGroup:item] && [item[OGGroupIdentifierKey] isEqualToString:identifier];
        }];
        if (groupIndex == NSNotFound) return NO;
        NSMutableDictionary *group = [rootItems[groupIndex] mutableCopy];
        group[OGGroupItemsKey] = [group[OGGroupItemsKey] arrayByAddingObject:rule];
        rootItems[groupIndex] = group;
    }
    self.rootItems = rootItems;
    [self save];
    return YES;
}

- (NSDictionary *)ruleWithIdentifier:(NSString *)identifier {
    for (NSDictionary *item in self.rootItems) {
        NSArray *rules = [self isGroup:item] ? item[OGGroupItemsKey] : @[item];
        for (NSDictionary *rule in rules)
            if ([rule[OGRuleIdentifierKey] isEqualToString:identifier]) return rule;
    }
    return nil;
}

- (NSString *)addDraftRuleToGroup:(NSString *)groupIdentifier {
    NSString *identifier = NSUUID.UUID.UUIDString;
    NSDictionary *rule = @{OGRuleIdentifierKey: identifier, OGRuleExtensionKey: @"", OGRuleNameKey: @""};
    NSMutableArray *root = [self.rootItems mutableCopy];
    NSDictionary *group = groupIdentifier ? [self groupWithIdentifier:groupIdentifier] : nil;
    if (group) {
        NSMutableDictionary *next = [group mutableCopy];
        next[OGGroupItemsKey] = [group[OGGroupItemsKey] arrayByAddingObject:rule];
        root[[root indexOfObject:group]] = next;
    } else [root addObject:rule];
    self.rootItems = root;
    [self save];
    return identifier;
}

- (void)replaceRule:(NSString *)identifier withRule:(NSDictionary *)replacement {
    NSMutableArray *root = [NSMutableArray array];
    for (NSDictionary *item in self.rootItems) {
        if ([self isGroup:item]) {
            NSMutableDictionary *group = [item mutableCopy];
            NSMutableArray *children = [NSMutableArray array];
            for (NSDictionary *rule in item[OGGroupItemsKey]) {
                if (![rule[OGRuleIdentifierKey] isEqualToString:identifier]) [children addObject:rule];
                else if (replacement) [children addObject:replacement];
            }
            group[OGGroupItemsKey] = children;
            [root addObject:group];
        } else if (![item[OGRuleIdentifierKey] isEqualToString:identifier]) [root addObject:item];
        else if (replacement) [root addObject:replacement];
    }
    self.rootItems = root;
    [self save];
}

- (BOOL)updateRule:(NSString *)identifier extension:(NSString *)extension name:(NSString *)name {
    NSDictionary *old = [self ruleWithIdentifier:identifier];
    NSString *normalized = [self normalizedExtension:extension];
    NSCharacterSet *invalid = [NSCharacterSet characterSetWithCharactersInString:@"./:\\ "];
    if (!old || !normalized.length || normalized.length > 32 ||
        [normalized rangeOfCharacterFromSet:invalid].location != NSNotFound ||
        [normalized rangeOfCharacterFromSet:NSCharacterSet.whitespaceAndNewlineCharacterSet].location != NSNotFound)
        return NO;
    if (![old[OGRuleExtensionKey] isEqualToString:normalized] && [self containsRuleWithExtension:normalized]) return NO;
    NSMutableDictionary *next = [old mutableCopy];
    next[OGRuleExtensionKey] = normalized;
    NSString *trimmed = [name stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    next[OGRuleNameKey] = trimmed.length ? trimmed : normalized.uppercaseString;
    [self replaceRule:identifier withRule:next];
    return YES;
}

- (void)removeRule:(NSString *)identifier { [self replaceRule:identifier withRule:nil]; }

- (void)setApplication:(NSDictionary *)application forRule:(NSString *)identifier {
    NSMutableDictionary *rule = [[self ruleWithIdentifier:identifier] mutableCopy];
    if (!rule) return;
    [self copyApplicationFrom:application to:rule];
    [self replaceRule:identifier withRule:rule];
}

- (void)renameGroup:(NSString *)identifier title:(NSString *)title {
    NSString *trimmed = [title stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (!trimmed.length) return;
    NSMutableArray *rootItems = [self.rootItems mutableCopy];
    for (NSUInteger index = 0; index < rootItems.count; index++) {
        NSDictionary *item = rootItems[index];
        if (![self isGroup:item] || ![item[OGGroupIdentifierKey] isEqualToString:identifier]) continue;
        NSMutableDictionary *group = [item mutableCopy];
        group[OGGroupNameKey] = trimmed;
        rootItems[index] = group;
        break;
    }
    self.rootItems = rootItems;
    [self save];
}

- (void)setApplication:(NSDictionary *)application forGroup:(NSString *)identifier {
    NSMutableArray *rootItems = [self.rootItems mutableCopy];
    for (NSUInteger index = 0; index < rootItems.count; index++) {
        NSDictionary *group = rootItems[index];
        if (![self isGroup:group] || ![group[OGGroupIdentifierKey] isEqualToString:identifier]) continue;
        NSMutableDictionary *next = [group mutableCopy];
        [self copyApplicationFrom:application to:next];
        NSMutableArray *items = [NSMutableArray array];
        for (NSDictionary *item in group[OGGroupItemsKey]) {
            NSMutableDictionary *cleanItem = [item mutableCopy];
            for (NSString *key in @[OGRuleBundleIdentifierKey, OGRuleApplicationNameKey, OGRuleApplicationPathKey]) {
                [cleanItem removeObjectForKey:key];
            }
            [items addObject:cleanItem];
        }
        next[OGGroupItemsKey] = items;
        rootItems[index] = next;
        break;
    }
    self.rootItems = rootItems;
    [self save];
}

- (void)setApplication:(NSDictionary *)application
           forExtension:(NSString *)extension
                 inGroup:(NSString *)identifier {
    NSMutableArray *rootItems = [self.rootItems mutableCopy];
    if (!identifier.length) {
        for (NSUInteger index = 0; index < rootItems.count; index++) {
            NSDictionary *rule = rootItems[index];
            if ([self isGroup:rule] || ![rule[OGRuleExtensionKey] isEqualToString:extension]) continue;
            NSMutableDictionary *nextRule = [rule mutableCopy];
            [self copyApplicationFrom:application to:nextRule];
            rootItems[index] = nextRule;
            break;
        }
    } else {
        for (NSUInteger groupIndex = 0; groupIndex < rootItems.count; groupIndex++) {
            NSDictionary *group = rootItems[groupIndex];
            if (![self isGroup:group] || ![group[OGGroupIdentifierKey] isEqualToString:identifier]) continue;
            NSMutableArray *items = [group[OGGroupItemsKey] mutableCopy];
            for (NSUInteger itemIndex = 0; itemIndex < items.count; itemIndex++) {
                NSDictionary *rule = items[itemIndex];
                if (![rule[OGRuleExtensionKey] isEqualToString:extension]) continue;
                NSMutableDictionary *nextRule = [rule mutableCopy];
                [self copyApplicationFrom:application to:nextRule];
                items[itemIndex] = nextRule;
                break;
            }
            NSMutableDictionary *nextGroup = [group mutableCopy];
            nextGroup[OGGroupItemsKey] = items;
            rootItems[groupIndex] = nextGroup;
            break;
        }
    }
    self.rootItems = rootItems;
    [self save];
}

- (void)removeGroup:(NSString *)identifier {
    NSMutableArray *rootItems = [self.rootItems mutableCopy];
    NSUInteger groupIndex = [rootItems indexOfObjectPassingTest:
                             ^BOOL(NSDictionary *item, NSUInteger index, BOOL *stop) {
        return [self isGroup:item] && [item[OGGroupIdentifierKey] isEqualToString:identifier];
    }];
    if (groupIndex == NSNotFound) return;
    NSDictionary *group = rootItems[groupIndex];
    NSMutableArray *rules = [NSMutableArray array];
    for (NSDictionary *child in group[OGGroupItemsKey]) {
        NSMutableDictionary *rule = [child mutableCopy];
        if (!rule[OGRuleBundleIdentifierKey] && group[OGRuleBundleIdentifierKey]) {
            [self copyApplicationFrom:group to:rule];
        }
        [rules addObject:rule];
    }
    [rootItems removeObjectAtIndex:groupIndex];
    NSIndexSet *indexes = [NSIndexSet indexSetWithIndexesInRange:NSMakeRange(groupIndex, rules.count)];
    [rootItems insertObjects:rules atIndexes:indexes];
    self.rootItems = rootItems;
    [self save];
}

- (BOOL)moveGroup:(NSString *)identifier toIndex:(NSUInteger)index {
    NSMutableArray *rootItems = [self.rootItems mutableCopy];
    NSUInteger sourceIndex = [rootItems indexOfObjectPassingTest:
                              ^BOOL(NSDictionary *item, NSUInteger candidate, BOOL *stop) {
        return [self isGroup:item] && [item[OGGroupIdentifierKey] isEqualToString:identifier];
    }];
    if (sourceIndex == NSNotFound) return NO;
    NSDictionary *group = rootItems[sourceIndex];
    [rootItems removeObjectAtIndex:sourceIndex];
    if (index > sourceIndex) index--;
    index = MIN(index, rootItems.count);
    [rootItems insertObject:group atIndex:index];
    self.rootItems = rootItems;
    [self save];
    return YES;
}

- (BOOL)moveRuleWithExtension:(NSString *)extension
                    fromGroup:(NSString *)sourceIdentifier
                      toGroup:(NSString *)destinationIdentifier
                      atIndex:(NSUInteger)index {
    NSMutableArray *rootItems = [self.rootItems mutableCopy];
    NSDictionary *sourceGroup = sourceIdentifier.length ? [self groupWithIdentifier:sourceIdentifier] : nil;
    NSMutableDictionary *rule = nil;
    NSUInteger sourceIndex = NSNotFound;

    if (sourceGroup) {
        NSMutableArray *children = [sourceGroup[OGGroupItemsKey] mutableCopy];
        sourceIndex = [children indexOfObjectPassingTest:^BOOL(NSDictionary *item, NSUInteger candidate, BOOL *stop) {
            return [item[OGRuleExtensionKey] isEqualToString:extension];
        }];
        if (sourceIndex == NSNotFound) return NO;
        rule = [children[sourceIndex] mutableCopy];
        [children removeObjectAtIndex:sourceIndex];
        NSUInteger groupIndex = [rootItems indexOfObjectPassingTest:
                                 ^BOOL(NSDictionary *item, NSUInteger candidate, BOOL *stop) {
            return [self isGroup:item] && [item[OGGroupIdentifierKey] isEqualToString:sourceIdentifier];
        }];
        NSMutableDictionary *nextGroup = [sourceGroup mutableCopy];
        nextGroup[OGGroupItemsKey] = children;
        rootItems[groupIndex] = nextGroup;
    } else {
        sourceIndex = [rootItems indexOfObjectPassingTest:^BOOL(NSDictionary *item, NSUInteger candidate, BOOL *stop) {
            return ![self isGroup:item] && [item[OGRuleExtensionKey] isEqualToString:extension];
        }];
        if (sourceIndex == NSNotFound) return NO;
        rule = [rootItems[sourceIndex] mutableCopy];
        [rootItems removeObjectAtIndex:sourceIndex];
    }

    if (!destinationIdentifier.length) {
        if (sourceGroup && !rule[OGRuleBundleIdentifierKey] && sourceGroup[OGRuleBundleIdentifierKey]) {
            [self copyApplicationFrom:sourceGroup to:rule];
        }
        if (!sourceIdentifier.length && index > sourceIndex) index--;
        index = MIN(index, rootItems.count);
        [rootItems insertObject:rule atIndex:index];
    } else {
        NSUInteger destinationGroupIndex = [rootItems indexOfObjectPassingTest:
                                            ^BOOL(NSDictionary *item, NSUInteger candidate, BOOL *stop) {
            return [self isGroup:item] && [item[OGGroupIdentifierKey] isEqualToString:destinationIdentifier];
        }];
        if (destinationGroupIndex == NSNotFound) return NO;
        NSMutableDictionary *destinationGroup = [rootItems[destinationGroupIndex] mutableCopy];
        NSMutableArray *children = [destinationGroup[OGGroupItemsKey] mutableCopy];
        if ([sourceIdentifier isEqualToString:destinationIdentifier] && index > sourceIndex) index--;
        index = MIN(index, children.count);
        [children insertObject:rule atIndex:index];
        destinationGroup[OGGroupItemsKey] = children;
        rootItems[destinationGroupIndex] = destinationGroup;
    }

    self.rootItems = rootItems;
    [self save];
    return YES;
}

- (void)restoreDefaultGroups {
    NSArray *existingRules = [self allRulesPreservingApplications];
    NSMutableDictionary *rulesByExtension = [NSMutableDictionary dictionary];
    for (NSDictionary *rule in existingRules) {
        if (rule[OGRuleExtensionKey]) rulesByExtension[rule[OGRuleExtensionKey]] = rule;
    }

    NSMutableArray *rootItems = [NSMutableArray array];
    NSMutableSet *usedExtensions = [NSMutableSet set];
    for (NSDictionary *templateGroup in [OGPresets defaultGroups]) {
        NSMutableDictionary *group = [templateGroup mutableCopy];
        NSMutableArray *children = [NSMutableArray array];
        for (NSDictionary *templateRule in templateGroup[OGGroupItemsKey]) {
            NSMutableDictionary *rule = [templateRule mutableCopy];
            rule[OGRuleIdentifierKey] = NSUUID.UUID.UUIDString;
            NSDictionary *existingRule = rulesByExtension[templateRule[OGRuleExtensionKey]];
            if (existingRule) {
                [self copyApplicationFrom:existingRule to:rule];
                rule[OGRuleIdentifierKey] = existingRule[OGRuleIdentifierKey] ?: NSUUID.UUID.UUIDString;
                rule[OGRuleNameKey] = existingRule[OGRuleNameKey] ?: templateRule[OGRuleNameKey];
            }
            [children addObject:rule];
            [usedExtensions addObject:templateRule[OGRuleExtensionKey]];
        }
        group[OGGroupItemsKey] = children;
        [rootItems addObject:group];
    }
    for (NSDictionary *rule in existingRules) {
        if (![usedExtensions containsObject:rule[OGRuleExtensionKey]]) [rootItems addObject:rule];
    }
    self.rootItems = rootItems;
    [self save];
}

@end
