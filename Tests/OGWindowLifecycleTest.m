#import <Cocoa/Cocoa.h>
#import "OGAppDelegate.h"
#import "OGLanguage.h"
#import "OGRuleStore.h"

@interface OGAppDelegate (WindowLifecycleTesting)
- (void)buildStatusItem;
- (void)buildWindow;
@end

int main(void) {
    @autoreleasepool {
        [NSApplication sharedApplication];

        OGAppDelegate *delegate = [[OGAppDelegate alloc] init];
        [delegate setValue:[[OGRuleStore alloc] init] forKey:@"store"];
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

        printf("window_retained=%s\nmenu_reopen_cycles=%s\n",
               window != nil && window == [delegate valueForKey:@"window"] ? "yes" : "no",
               passed ? "5/5" : "failed");
        return passed ? 0 : 1;
    }
}
