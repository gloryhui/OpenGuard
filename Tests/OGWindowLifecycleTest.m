#import <Cocoa/Cocoa.h>
#import "OGAppDelegate.h"
#import "OGLanguage.h"
#import "OGRuleStore.h"

@interface OGAppDelegate (WindowLifecycleTesting)
- (void)buildStatusItem;
- (void)buildWindow;
- (void)addGroup:(id)sender;
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

        printf("window_retained=%s\nmenu_reopen_cycles=%s\nadd_group_inline_edit=%s\n",
               window != nil && window == [delegate valueForKey:@"window"] ? "yes" : "no",
               passed ? "5/5" : "failed",
               groupEditingStarted ? "yes" : "no");
        [defaults removePersistentDomainForName:suiteName];
        return passed && groupEditingStarted ? 0 : 1;
    }
}
