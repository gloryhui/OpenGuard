#import <Foundation/Foundation.h>
#import "OGRuleStore.h"

static BOOL ruleHasBundle(OGRuleStore *store, NSString *extension, NSString *bundleIdentifier) {
    for (NSDictionary *rule in store.effectiveRules) {
        if ([rule[OGRuleExtensionKey] isEqualToString:extension]) {
            return [rule[OGRuleBundleIdentifierKey] isEqualToString:bundleIdentifier];
        }
    }
    return NO;
}

int main(void) {
    @autoreleasepool {
        NSString *suiteName = [NSString stringWithFormat:@"com.gloryhuis.OpenGuard.tests.%@",
                               NSUUID.UUID.UUIDString];
        NSUserDefaults *defaults = [[NSUserDefaults alloc] initWithSuiteName:suiteName];
        [defaults removePersistentDomainForName:suiteName];
        [defaults setObject:@[@{OGGroupIdentifierKey: @"legacy-group",
                                OGGroupNameKey: @"Legacy",
                                OGRuleBundleIdentifierKey: @"example.old",
                                OGRuleApplicationNameKey: @"Old App",
                                OGRuleApplicationPathKey: @"/Applications/Old.app",
                                OGGroupItemsKey: @[
                                    @{OGRuleExtensionKey: @"aaa", OGRuleNameKey: @"AAA"},
                                    @{OGRuleExtensionKey: @"bbb", OGRuleNameKey: @"BBB"}
                                ]}]
                    forKey:@"groups.v3"];

        OGRuleStore *store = [[OGRuleStore alloc] initWithUserDefaults:defaults];
        BOOL migrated = store.rootItems.count == 1 && store.groups.count == 1;
        NSString *newGroup = [store addGroupWithTitle:@"Second"];
        BOOL added = [store addRuleWithExtension:@".foo" name:@"Foo" toGroup:nil];
        BOOL movedIntoGroup = [store moveRuleWithExtension:@"foo" fromGroup:nil
                                                   toGroup:newGroup atIndex:0];
        BOOL addedSecondRule = [store addRuleWithExtension:@"bar" name:@"Bar" toGroup:newGroup];
        BOOL reorderedInGroup = [store moveRuleWithExtension:@"foo" fromGroup:newGroup
                                                      toGroup:newGroup atIndex:2];
        NSArray *newGroupItems = [store groupWithIdentifier:newGroup][OGGroupItemsKey];
        reorderedInGroup = reorderedInGroup &&
            [newGroupItems.firstObject[OGRuleExtensionKey] isEqualToString:@"bar"] &&
            [newGroupItems.lastObject[OGRuleExtensionKey] isEqualToString:@"foo"];
        BOOL reordered = [store moveGroup:newGroup toIndex:0] &&
            [store.rootItems.firstObject[OGGroupIdentifierKey] isEqualToString:newGroup];

        BOOL movedBackToRoot = [store moveRuleWithExtension:@"foo" fromGroup:newGroup
                                                     toGroup:nil atIndex:store.rootItems.count];
        BOOL rootMovePreservedRule = movedBackToRoot &&
            [store.rootItems.lastObject[OGRuleExtensionKey] isEqualToString:@"foo"];

        [store removeGroup:@"legacy-group"];
        BOOL rulesMovedToRoot = [store containsRuleWithExtension:@"aaa"] &&
            [store containsRuleWithExtension:@"bbb"] && ruleHasBundle(store, @"aaa", @"example.old") &&
            ruleHasBundle(store, @"bbb", @"example.old");

        [store restoreDefaultGroups];
        BOOL resetPreservedRules = store.groups.count == 5 &&
            [store groupWithIdentifier:@"legacy-group"] == nil &&
            [store groupWithIdentifier:newGroup] == nil &&
            [store containsRuleWithExtension:@"aaa"] && [store containsRuleWithExtension:@"bbb"] &&
            [store containsRuleWithExtension:@"foo"] && [store containsRuleWithExtension:@"bar"];

        NSString *draftGroup = store.groups.firstObject[OGGroupIdentifierKey];
        NSUInteger effectiveCount = store.effectiveRules.count;
        NSString *draftID = [store addDraftRuleToGroup:draftGroup];
        BOOL draftInactive = store.effectiveRules.count == effectiveCount;
        NSDictionary *application = @{OGRuleBundleIdentifierKey: @"example.editor", OGRuleApplicationNameKey: @"Editor"};
        [store setApplication:application forExtension:@"" inGroup:draftGroup];
        draftInactive = draftInactive && store.effectiveRules.count == effectiveCount;
        BOOL edited = [store updateRule:draftID extension:@".OGTEST" name:@"测试名称"] &&
            ruleHasBundle(store, @"ogtest", @"example.editor");
        BOOL rejectsDuplicate = ![store updateRule:draftID extension:@"aaa" name:@"Duplicate"] &&
            [[store ruleWithIdentifier:draftID][OGRuleExtensionKey] isEqualToString:@"ogtest"];
        BOOL rejectsInvalid = ![store updateRule:draftID extension:@"bad/path" name:@"Invalid"];
        OGRuleStore *reloaded = [[OGRuleStore alloc] initWithUserDefaults:defaults];
        BOOL persisted = [[reloaded ruleWithIdentifier:draftID][OGRuleNameKey] isEqualToString:@"测试名称"];
        [store removeRule:draftID];
        BOOL removedOnlyTarget = [store ruleWithIdentifier:draftID] == nil && [store containsRuleWithExtension:@"aaa"];
        BOOL editingPassed = draftInactive && edited && rejectsDuplicate && rejectsInvalid && persisted && removedOnlyTarget;
        printf("rule_edit_delete_persistence=%s\n", editingPassed ? "yes" : "no");

        BOOL passed = editingPassed && migrated && added && movedIntoGroup && addedSecondRule && reorderedInGroup && reordered &&
            rootMovePreservedRule &&
            rulesMovedToRoot && resetPreservedRules;
        printf("migration=%s\nadd_and_cross_group_move=%s\nin_group_and_root_reorder=%s\n"
               "remove_group_preserves_rules=%s\n"
               "initialize_preserves_rules=%s\n",
               migrated ? "yes" : "no",
               added && movedIntoGroup && addedSecondRule && reordered ? "yes" : "no",
               reorderedInGroup && rootMovePreservedRule ? "yes" : "no",
               rulesMovedToRoot ? "yes" : "no",
               resetPreservedRules ? "yes" : "no");
        [defaults removePersistentDomainForName:suiteName];
        return passed ? 0 : 1;
    }
}
