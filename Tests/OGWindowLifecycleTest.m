#import <Cocoa/Cocoa.h>
#import "OGAppDelegate.h"
#import "OGLanguage.h"
#import "OGRuleStore.h"

@interface OGAppDelegate (WindowLifecycleTesting)
- (void)buildStatusItem;
- (void)buildWindow;
- (void)addGroup:(id)sender;
- (void)refreshAndRepair:(BOOL)repair;
- (void)showRuleEditor:(id)sender;
- (void)cancelAddRule:(id)sender;
- (void)confirmAddRule:(id)sender;
- (void)beginEditingRule:(NSString *)identifier;
@end

int main(void) {
    @autoreleasepool {
        [NSApplication sharedApplication];

        NSString *suiteName = [NSString stringWithFormat:@"com.gloryhuis.OpenGuard.window-tests.%@",
                               NSUUID.UUID.UUIDString];
        NSUserDefaults *defaults = [[NSUserDefaults alloc] initWithSuiteName:suiteName];
        [defaults removePersistentDomainForName:suiteName];
        OGRuleStore *store = [[OGRuleStore alloc] initWithUserDefaults:defaults];
        OGAppDelegate *delegate = [[OGAppDelegate alloc] init];
        [delegate setValue:store forKey:@"store"];
        [delegate setValue:[OGLanguage shared] forKey:@"language"];
        [delegate buildStatusItem];
        [delegate buildWindow];

        __weak NSWindow *window = [delegate valueForKey:@"window"];
        NSStatusItem *statusItem = [delegate valueForKey:@"statusItem"];
        BOOL passed = YES;
        for (NSUInteger cycle = 0; cycle < 5; cycle++) {
            [window makeKeyAndOrderFront:nil];
            [window close];
            [statusItem.menu performActionForItemAtIndex:0];
            if (window == nil || window != [delegate valueForKey:@"window"] || !window.visible) {
                passed = NO;
                break;
            }
        }

        NSUInteger groupCount = store.groups.count;
        [delegate addGroup:nil];
        NSOutlineView *outlineView = [delegate valueForKey:@"outlineView"];
        NSTextField *groupTitleField = nil;
        NSDate *deadline = [NSDate dateWithTimeIntervalSinceNow:0.5];
        do {
            [[NSRunLoop mainRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.01]];
            if (outlineView.selectedRow >= 0) {
                groupTitleField = [outlineView viewAtColumn:0 row:outlineView.selectedRow makeIfNecessary:NO];
            }
        } while (!groupTitleField.currentEditor && [deadline timeIntervalSinceNow] > 0);
        BOOL groupEditingStarted = store.groups.count == groupCount + 1 &&
            groupTitleField.currentEditor != nil;

        NSTextView *editor = (NSTextView *)groupTitleField.currentEditor;
        NSString *originalTitle = store.groups.lastObject[OGGroupNameKey];
        [editor setMarkedText:@"中文pin" selectedRange:NSMakeRange(5, 0)
             replacementRange:NSMakeRange(0, editor.string.length)];
        [delegate refreshAndRepair:NO];
        BOOL compositionPreserved = groupTitleField.currentEditor == editor && editor.hasMarkedText &&
            [store.groups.lastObject[OGGroupNameKey] isEqualToString:originalTitle];
        [editor insertText:@"中文拼音分组" replacementRange:editor.markedRange];
        [window makeFirstResponder:outlineView];
        BOOL completedNameSaved = [store.groups.lastObject[OGGroupNameKey] isEqualToString:@"中文拼音分组"];

        NSString *targetGroup = store.groups.lastObject[OGGroupIdentifierKey];
        NSInteger groupRow = [outlineView rowForItem:[store groupWithIdentifier:targetGroup]];
        [outlineView selectRowIndexes:[NSIndexSet indexSetWithIndex:groupRow] byExtendingSelection:NO];
        [delegate showRuleEditor:nil];
        NSString *draftID = [delegate valueForKey:@"editingRuleIdentifier"];
        NSDictionary *draft = [store ruleWithIdentifier:draftID];
        BOOL insertedInGroup = [[store groupWithIdentifier:targetGroup][OGGroupItemsKey] containsObject:draft];
        [delegate cancelAddRule:nil];
        BOOL cancelRetainsDraft = [store ruleWithIdentifier:draftID] != nil &&
            [delegate valueForKey:@"editingRuleIdentifier"] == nil;
        [delegate beginEditingRule:draftID];
        [[NSRunLoop mainRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.1]];
        NSTextField *extensionField = [delegate valueForKey:@"ruleExtensionField"];
        NSTextField *nameField = [delegate valueForKey:@"ruleNameField"];
        extensionField.stringValue = @"oguitest";
        [window makeFirstResponder:nameField];
        NSTextView *ruleEditor = (NSTextView *)nameField.currentEditor;
        [ruleEditor setMarkedText:@"中文pin" selectedRange:NSMakeRange(5, 0)
                 replacementRange:NSMakeRange(0, ruleEditor.string.length)];
        [delegate refreshAndRepair:NO];
        BOOL ruleIMEPreserved = ruleEditor != nil && nameField.currentEditor == ruleEditor && ruleEditor.hasMarkedText;
        [ruleEditor insertText:@"中文规则" replacementRange:ruleEditor.markedRange];
        [delegate confirmAddRule:nil];
        BOOL confirmedRule = [[store ruleWithIdentifier:draftID][OGRuleExtensionKey] isEqualToString:@"oguitest"] &&
            [[store ruleWithIdentifier:draftID][OGRuleNameKey] isEqualToString:@"中文规则"];
        [delegate beginEditingRule:draftID];
        ((NSTextField *)[delegate valueForKey:@"ruleNameField"]).stringValue = @"discard me";
        [delegate cancelAddRule:nil];
        BOOL cancelPreservesName = [[store ruleWithIdentifier:draftID][OGRuleNameKey] isEqualToString:@"中文规则"];
        BOOL ruleEditingPassed = insertedInGroup && cancelRetainsDraft && ruleIMEPreserved && confirmedRule && cancelPreservesName;
        printf("inline_rule_insert=%s\ncancel_retains_rule=%s\nrule_ime_preserved=%s\nrule_confirm_and_cancel=%s\n",
               insertedInGroup ? "yes" : "no", cancelRetainsDraft ? "yes" : "no",
               ruleIMEPreserved ? "yes" : "no", confirmedRule && cancelPreservesName ? "yes" : "no");

        printf("window_retained=%s\nmenu_reopen_cycles=%s\nadd_group_inline_edit=%s\nime_composition_preserved=%s\nime_completed_name_saved=%s\n",
               window != nil && window == [delegate valueForKey:@"window"] ? "yes" : "no",
               passed ? "5/5" : "failed",
               groupEditingStarted ? "yes" : "no", compositionPreserved ? "yes" : "no",
               completedNameSaved ? "yes" : "no");
        [defaults removePersistentDomainForName:suiteName];
        return passed && groupEditingStarted && compositionPreserved && completedNameSaved && ruleEditingPassed ? 0 : 1;
    }
}
