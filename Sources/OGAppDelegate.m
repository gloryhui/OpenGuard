#import "OGAppDelegate.h"
#import "OGApplicationPicker.h"
#import "OGLaunchAgent.h"
#import "OGLaunchServices.h"
#import "OGRuleStore.h"
#import "OGLanguage.h"

static const NSTimeInterval OGMonitoringInterval = 3.0;

@interface OGAppDelegate ()
@property OGRuleStore *store;
@property OGLanguage *language;
@property NSStatusItem *statusItem;
@property NSWindow *window;
@property NSOutlineView *outlineView;
@property NSTextField *summaryLabel;
@property NSButton *monitoringCheckbox;
@property NSButton *loginCheckbox;
@property NSButton *deleteGroupButton;
@property NSTimer *timer;
@property OGUpdateChecker *updateChecker;
@property (copy) NSDictionary<NSString *, NSString *> *statusByExtension;
@property NSUInteger repairCount;
@property BOOL agentLaunch;
@end

@implementation OGAppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)notification {
    self.agentLaunch = [[[NSProcessInfo processInfo] arguments] containsObject:@"--agent"];
    self.store = [[OGRuleStore alloc] init];
    self.language = [OGLanguage shared];
    self.statusByExtension = @{};
    [[[NSWorkspace sharedWorkspace] notificationCenter] addObserver:self
                                                           selector:@selector(workspaceDidWake:)
                                                               name:NSWorkspaceDidWakeNotification
                                                             object:nil];
    if ([OGLaunchAgent isEnabled]) {
        NSError *error = nil;
        if (![OGLaunchAgent setEnabled:YES error:&error]) NSLog(@"Unable to refresh login agent: %@", error);
    }
    [self buildStatusItem];
    [self buildWindow];
    [self refreshAndRepair:self.store.monitoringEnabled];
    [self restartTimer];
    NSString *version = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleShortVersionString"] ?: @"0";
    self.updateChecker = [[OGUpdateChecker alloc] initWithCurrentVersion:version delegate:self];
    [self.updateChecker start];
    if (!self.agentLaunch) [self showWindow:nil];
}

- (void)applicationWillTerminate:(NSNotification *)notification {
    [self.timer invalidate];
    [self.updateChecker stop];
    [[[NSWorkspace sharedWorkspace] notificationCenter] removeObserver:self];
}
- (void)applicationDidBecomeActive:(NSNotification *)notification {
    if (self.store.monitoringEnabled) [self refreshAndRepair:YES];
}
- (BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)sender { return NO; }

- (void)buildStatusItem {
    self.statusItem = [[NSStatusBar systemStatusBar] statusItemWithLength:NSVariableStatusItemLength];
    self.statusItem.button.title = @"◉";
    self.statusItem.button.toolTip = [self.language text:@"tagline"];
    NSMenu *menu = [[NSMenu alloc] initWithTitle:@"OpenGuard"];
    [menu addItemWithTitle:[self.language text:@"menu_open"] action:@selector(showWindow:) keyEquivalent:@""];
    [menu addItemWithTitle:[self.language text:@"menu_apply"] action:@selector(applyNow:) keyEquivalent:@""];
    [menu addItem:[NSMenuItem separatorItem]];
    NSMenuItem *quitItem = [menu addItemWithTitle:[self.language text:@"menu_quit"]
                                            action:@selector(terminate:)
                                     keyEquivalent:@"q"];
    for (NSMenuItem *item in menu.itemArray) item.target = self;
    quitItem.target = NSApp;
    self.statusItem.menu = menu;
}

- (NSTextField *)label:(NSString *)text font:(NSFont *)font {
    NSTextField *label = [NSTextField labelWithString:text];
    label.font = font;
    label.translatesAutoresizingMaskIntoConstraints = NO;
    label.lineBreakMode = NSLineBreakByTruncatingTail;
    return label;
}

- (NSButton *)button:(NSString *)title action:(SEL)action {
    NSButton *button = [NSButton buttonWithTitle:title target:self action:action];
    button.translatesAutoresizingMaskIntoConstraints = NO;
    return button;
}

- (void)buildWindow {
    self.window = [[NSWindow alloc] initWithContentRect:NSMakeRect(0, 0, 780, 560)
                                              styleMask:(NSWindowStyleMaskTitled | NSWindowStyleMaskClosable |
                                                         NSWindowStyleMaskMiniaturizable | NSWindowStyleMaskResizable)
                                                backing:NSBackingStoreBuffered defer:NO];
    self.window.title = @"OpenGuard";
    self.window.minSize = NSMakeSize(680, 460);
    [self.window center];
    NSView *content = self.window.contentView;

    NSTextField *title = [self label:[self.language text:@"tagline"] font:[NSFont boldSystemFontOfSize:22]];
    self.summaryLabel = [self label:[self.language text:@"checking"] font:[NSFont systemFontOfSize:13]];
    self.summaryLabel.textColor = [NSColor secondaryLabelColor];
    NSTextField *languageLabel = [self label:[self.language text:@"language"] font:[NSFont systemFontOfSize:12]];
    NSPopUpButton *languagePopup = [[NSPopUpButton alloc] initWithFrame:NSZeroRect pullsDown:NO];
    languagePopup.translatesAutoresizingMaskIntoConstraints = NO;
    for (NSDictionary *entry in [OGLanguage supportedLanguages]) {
        [languagePopup addItemWithTitle:entry[@"name"]];
        languagePopup.lastItem.representedObject = entry[@"code"];
        if ([entry[@"code"] isEqualToString:self.language.code]) [languagePopup selectItem:languagePopup.lastItem];
    }
    languagePopup.target = self;
    languagePopup.action = @selector(changeLanguage:);

    NSScrollView *scroll = [[NSScrollView alloc] initWithFrame:NSZeroRect];
    scroll.translatesAutoresizingMaskIntoConstraints = NO;
    scroll.hasVerticalScroller = YES;
    scroll.borderType = NSBezelBorder;
    self.outlineView = [[NSOutlineView alloc] initWithFrame:NSZeroRect];
    self.outlineView.dataSource = self;
    self.outlineView.delegate = self;
    self.outlineView.headerView = [[NSTableHeaderView alloc] initWithFrame:NSMakeRect(0, 0, 100, 25)];
    self.outlineView.usesAlternatingRowBackgroundColors = YES;
    self.outlineView.allowsMultipleSelection = NO;
    self.outlineView.rowHeight = 28;
    NSTableColumn *typeColumn = [[NSTableColumn alloc] initWithIdentifier:@"filetype"];
    typeColumn.title = [self.language text:@"file_type"];
    typeColumn.width = 255;
    NSTableColumn *applicationColumn = [[NSTableColumn alloc] initWithIdentifier:@"application"];
    applicationColumn.title = [self.language text:@"open_with"];
    applicationColumn.width = 315;
    NSTableColumn *statusColumn = [[NSTableColumn alloc] initWithIdentifier:@"status"];
    statusColumn.title = [self.language text:@"status"];
    statusColumn.width = 170;
    [self.outlineView addTableColumn:typeColumn];
    [self.outlineView addTableColumn:applicationColumn];
    [self.outlineView addTableColumn:statusColumn];
    self.outlineView.outlineTableColumn = typeColumn;
    scroll.documentView = self.outlineView;

    NSButton *restoreGroups = [self button:[self.language text:@"restore_groups"] action:@selector(restoreGroups:)];
    self.deleteGroupButton = [self button:[self.language text:@"delete_group"] action:@selector(deleteGroup:)];
    self.deleteGroupButton.enabled = NO;
    NSButton *apply = [self button:[self.language text:@"apply_all"] action:@selector(applyNow:)];
    self.monitoringCheckbox = [NSButton checkboxWithTitle:[self.language text:@"monitor_auto"] target:self
                                                    action:@selector(toggleMonitoring:)];
    self.monitoringCheckbox.translatesAutoresizingMaskIntoConstraints = NO;
    self.monitoringCheckbox.state = self.store.monitoringEnabled ? NSControlStateValueOn : NSControlStateValueOff;
    self.loginCheckbox = [NSButton checkboxWithTitle:[self.language text:@"start_login"] target:self
                                               action:@selector(toggleLogin:)];
    self.loginCheckbox.translatesAutoresizingMaskIntoConstraints = NO;
    self.loginCheckbox.state = [OGLaunchAgent isEnabled] ? NSControlStateValueOn : NSControlStateValueOff;

    for (NSView *view in @[title, self.summaryLabel, languageLabel, languagePopup, scroll, restoreGroups,
                           self.deleteGroupButton, apply, self.monitoringCheckbox, self.loginCheckbox]) [content addSubview:view];
    NSDictionary *views = NSDictionaryOfVariableBindings(title, _summaryLabel, languageLabel, languagePopup, scroll,
                                                           restoreGroups, _deleteGroupButton, apply,
                                                           _monitoringCheckbox, _loginCheckbox);
    [content addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"H:|-24-[title]-(>=20)-[languageLabel]-6-[languagePopup]-24-|"
                                                                    options:NSLayoutFormatAlignAllCenterY metrics:nil views:views]];
    [content addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"H:|-24-[_summaryLabel]-24-|"
                                                                    options:0 metrics:nil views:views]];
    [content addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"H:|-24-[scroll]-24-|"
                                                                    options:0 metrics:nil views:views]];
    [content addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"H:|-24-[restoreGroups]-8-[_deleteGroupButton]-(>=12)-[apply]-24-|"
                                                                    options:NSLayoutFormatAlignAllCenterY metrics:nil views:views]];
    [content addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"H:|-24-[_monitoringCheckbox]-24-|"
                                                                    options:0 metrics:nil views:views]];
    [content addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"H:|-24-[_loginCheckbox]-24-|"
                                                                    options:0 metrics:nil views:views]];
    [content addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"V:|-22-[title]-4-[_summaryLabel]-14-[scroll]-12-[restoreGroups]-14-[_monitoringCheckbox]-6-[_loginCheckbox]-18-|"
                                                                    options:0 metrics:nil views:views]];
    [self.outlineView reloadData];
    [self expandAllGroups];
}

- (void)showWindow:(id)sender { [NSApp activateIgnoringOtherApps:YES]; [self.window makeKeyAndOrderFront:nil]; }
- (void)expandAllGroups { for (NSDictionary *group in self.store.groups) [self.outlineView expandItem:group]; }
- (NSSet<NSString *> *)expandedGroupIdentifiers {
    NSMutableSet *identifiers = [NSMutableSet set];
    for (NSDictionary *group in self.store.groups) {
        if ([self.outlineView isItemExpanded:group]) [identifiers addObject:group[OGGroupIdentifierKey]];
    }
    return identifiers;
}
- (void)reloadOutlineWithExpandedGroupIdentifiers:(NSSet<NSString *> *)identifiers {
    [self.outlineView reloadData];
    for (NSDictionary *group in self.store.groups) {
        if ([identifiers containsObject:group[OGGroupIdentifierKey]]) [self.outlineView expandItem:group];
        else [self.outlineView collapseItem:group];
    }
}
- (BOOL)isGroup:(NSDictionary *)item { return item[OGGroupItemsKey] != nil; }

#pragma mark - Outline table

- (NSInteger)outlineView:(NSOutlineView *)outlineView numberOfChildrenOfItem:(id)item {
    return item ? [item[OGGroupItemsKey] count] : self.store.groups.count;
}
- (id)outlineView:(NSOutlineView *)outlineView child:(NSInteger)index ofItem:(id)item {
    return item ? item[OGGroupItemsKey][index] : self.store.groups[index];
}
- (BOOL)outlineView:(NSOutlineView *)outlineView isItemExpandable:(id)item { return [self isGroup:item]; }

- (NSView *)outlineView:(NSOutlineView *)outlineView viewForTableColumn:(NSTableColumn *)column item:(NSDictionary *)item {
    BOOL group = [self isGroup:item];
    if ([column.identifier isEqualToString:@"application"]) return [self applicationCellForItem:item group:group];
    NSTextField *cell = [NSTextField labelWithString:@""];
    cell.lineBreakMode = NSLineBreakByTruncatingTail;
    if ([column.identifier isEqualToString:@"filetype"]) {
        cell.stringValue = group ? [self.language text:item[OGGroupTitleKey]]
                                 : [NSString stringWithFormat:@".%@  —  %@", item[OGRuleExtensionKey], item[OGRuleNameKey]];
        if (group) cell.font = [NSFont boldSystemFontOfSize:13];
    } else {
        cell.stringValue = group ? [self groupStatus:item]
                                 : (self.statusByExtension[item[OGRuleExtensionKey]] ?: [self.language text:@"not_configured"]);
        BOOL good = [cell.stringValue isEqualToString:[self.language text:@"protected"]] ||
                    [cell.stringValue isEqualToString:[self.language text:@"restored"]];
        cell.textColor = good ? [NSColor systemGreenColor] : [NSColor secondaryLabelColor];
    }
    return cell;
}

- (NSView *)applicationCellForItem:(NSDictionary *)item group:(BOOL)isGroup {
    NSView *container = [[NSView alloc] initWithFrame:NSMakeRect(0, 0, 300, 28)];
    NSTextField *label = [NSTextField labelWithString:[self applicationTextForItem:item group:isGroup]];
    label.translatesAutoresizingMaskIntoConstraints = NO;
    label.lineBreakMode = NSLineBreakByTruncatingMiddle;
    if (isGroup) label.font = [NSFont boldSystemFontOfSize:13];
    NSButton *choose = [NSButton buttonWithTitle:@"…" target:self action:@selector(chooseApplication:)];
    choose.translatesAutoresizingMaskIntoConstraints = NO;
    choose.bezelStyle = NSBezelStyleRounded;
    choose.toolTip = [self.language text:@"choose_app_tooltip"];
    [container addSubview:label];
    [container addSubview:choose];
    NSDictionary *views = NSDictionaryOfVariableBindings(label, choose);
    [container addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"H:|-[label]-6-[choose(34)]-|"
                                                                     options:NSLayoutFormatAlignAllCenterY metrics:nil views:views]];
    [container addConstraint:[NSLayoutConstraint constraintWithItem:choose attribute:NSLayoutAttributeCenterY
                                                          relatedBy:NSLayoutRelationEqual toItem:container
                                                          attribute:NSLayoutAttributeCenterY multiplier:1 constant:0]];
    return container;
}

- (NSString *)applicationTextForItem:(NSDictionary *)item group:(BOOL)isGroup {
    if (isGroup) return [self applicationTextForGroup:item];
    if (item[OGRuleApplicationNameKey]) return item[OGRuleApplicationNameKey];
    NSDictionary *parent = [self.outlineView parentForItem:item];
    if (parent[OGRuleApplicationNameKey])
        return [NSString stringWithFormat:[self.language text:@"inherited_app"], parent[OGRuleApplicationNameKey]];
    return [self.language text:@"not_set"];
}

- (NSString *)applicationTextForGroup:(NSDictionary *)group {
    NSArray<NSDictionary *> *items = group[OGGroupItemsKey] ?: @[];
    NSMutableSet<NSString *> *bundleIdentifiers = [NSMutableSet set];
    NSMutableDictionary<NSString *, NSString *> *names = [NSMutableDictionary dictionary];
    NSUInteger configured = 0;
    for (NSDictionary *item in items) {
        NSString *bundleIdentifier = item[OGRuleBundleIdentifierKey] ?: group[OGRuleBundleIdentifierKey];
        if (!bundleIdentifier.length) continue;
        configured++;
        [bundleIdentifiers addObject:bundleIdentifier];
        NSString *name = item[OGRuleApplicationNameKey] ?: group[OGRuleApplicationNameKey];
        if (!name.length) name = [OGLaunchServices applicationNameForBundleIdentifier:bundleIdentifier];
        if (name.length && !names[bundleIdentifier]) names[bundleIdentifier] = name;
    }
    if (configured == 0) return [self.language text:@"not_set"];
    if (configured == items.count && bundleIdentifiers.count == 1) {
        NSString *bundleIdentifier = bundleIdentifiers.anyObject;
        return names[bundleIdentifier] ?: bundleIdentifier;
    }
    if (configured < items.count) {
        return [NSString stringWithFormat:[self.language text:@"partial_apps"],
                (unsigned long)configured, (unsigned long)items.count];
    }
    return [self.language text:@"multiple_apps"];
}

- (NSString *)groupStatus:(NSDictionary *)group {
    NSUInteger configured = 0, protected = 0;
    for (NSDictionary *item in group[OGGroupItemsKey]) {
        if (item[OGRuleBundleIdentifierKey] || group[OGRuleBundleIdentifierKey]) configured++;
        NSString *status = self.statusByExtension[item[OGRuleExtensionKey]];
        if ([status isEqualToString:[self.language text:@"protected"]] ||
            [status isEqualToString:[self.language text:@"restored"]]) protected++;
    }
    return [NSString stringWithFormat:[self.language text:@"group_status"], (unsigned long)protected,
            (unsigned long)configured, (unsigned long)[group[OGGroupItemsKey] count]];
}

- (void)outlineViewSelectionDidChange:(NSNotification *)notification {
    NSInteger row = self.outlineView.selectedRow;
    id item = row >= 0 ? [self.outlineView itemAtRow:row] : nil;
    self.deleteGroupButton.enabled = item && [self isGroup:item];
}

#pragma mark - Group and application actions

- (void)chooseApplication:(NSButton *)sender {
    NSInteger row = [self.outlineView rowForView:sender];
    if (row < 0) return;
    NSDictionary *item = [self.outlineView itemAtRow:row];
    BOOL group = [self isGroup:item];
    NSString *title = group ? [NSString stringWithFormat:[self.language text:@"choose_group_app"],
                               [self.language text:item[OGGroupTitleKey]]]
                            : [NSString stringWithFormat:[self.language text:@"choose_title"],
                               item[OGRuleExtensionKey]];
    NSDictionary *parent = group ? nil : [self.outlineView parentForItem:item];
    NSString *currentBundleIdentifier = item[OGRuleBundleIdentifierKey]
        ?: parent[OGRuleBundleIdentifierKey];
    OGApplicationPicker *picker = [[OGApplicationPicker alloc] initWithLanguage:self.language];
    NSDictionary *application = [picker runWithTitle:title
                             currentBundleIdentifier:currentBundleIdentifier];
    if (!application) return;
    NSSet<NSString *> *expandedGroups = [self expandedGroupIdentifiers];
    if (group) {
        [self.store setApplication:application forGroup:item[OGGroupIdentifierKey]];
    } else {
        [self.store setApplication:application forExtension:item[OGRuleExtensionKey]
                                                   inGroup:parent[OGGroupIdentifierKey]];
    }
    [self reloadOutlineWithExpandedGroupIdentifiers:expandedGroups];
    [self refreshAndRepair:YES];
}

- (void)deleteGroup:(id)sender {
    NSInteger row = self.outlineView.selectedRow;
    NSDictionary *group = row >= 0 ? [self.outlineView itemAtRow:row] : nil;
    if (!group || ![self isGroup:group]) return;
    [self.store removeGroup:group[OGGroupIdentifierKey]];
    [self.outlineView reloadData];
    [self expandAllGroups];
    self.deleteGroupButton.enabled = NO;
    [self refreshAndRepair:NO];
}

- (void)restoreGroups:(id)sender {
    [self.store restoreDefaultGroups];
    [self.outlineView reloadData];
    [self expandAllGroups];
    [self refreshAndRepair:NO];
}

#pragma mark - Rule enforcement

- (void)applyNow:(id)sender { [self refreshAndRepair:YES]; }

- (void)refreshAndRepair:(BOOL)repair {
    NSArray *rules = [self.store effectiveRules];
    NSMutableDictionary *statuses = [NSMutableDictionary dictionary];
    NSUInteger protectedCount = 0;
    for (NSDictionary *rule in rules) {
        NSString *extension = rule[OGRuleExtensionKey];
        NSString *wanted = rule[OGRuleBundleIdentifierKey];
        NSString *current = [OGLaunchServices currentHandlerForExtension:extension];
        if ([current isEqualToString:wanted]) {
            statuses[extension] = [self.language text:@"protected"];
            protectedCount++;
        } else if (repair) {
            NSError *error = nil;
            if ([OGLaunchServices setHandler:wanted forExtension:extension error:&error]) {
                statuses[extension] = [self.language text:@"restored"];
                protectedCount++;
                self.repairCount++;
                NSLog(@"Restored .%@ to %@ (previous handler: %@)", extension, wanted, current ?: @"none");
            } else {
                statuses[extension] = [self.language text:@"repair_failed"];
                NSLog(@"Failed to restore .%@: %@", extension, error);
            }
        } else {
            NSString *name = current ? [OGLaunchServices applicationNameForBundleIdentifier:current]
                                     : [self.language text:@"none"];
            statuses[extension] = [NSString stringWithFormat:[self.language text:@"changed"], name];
        }
    }
    self.statusByExtension = statuses;
    self.summaryLabel.stringValue = [NSString stringWithFormat:[self.language text:@"group_summary"],
                                     (unsigned long)self.store.groups.count, (unsigned long)protectedCount,
                                     (unsigned long)rules.count, (unsigned long)self.repairCount];
    self.statusItem.button.title = protectedCount == rules.count ? @"◉" : @"!";
    NSInteger rowCount = self.outlineView.numberOfRows;
    if (rowCount > 0) {
        [self.outlineView reloadDataForRowIndexes:[NSIndexSet indexSetWithIndexesInRange:NSMakeRange(0, rowCount)]
                                   columnIndexes:[NSIndexSet indexSetWithIndex:2]];
    }
}

#pragma mark - Settings

- (void)toggleMonitoring:(NSButton *)sender {
    self.store.monitoringEnabled = sender.state == NSControlStateValueOn;
    [self.store save];
    [self restartTimer];
    if (self.store.monitoringEnabled) [self refreshAndRepair:YES];
}

- (void)restartTimer {
    [self.timer invalidate];
    self.timer = nil;
    if (!self.store.monitoringEnabled) return;
    self.timer = [NSTimer scheduledTimerWithTimeInterval:OGMonitoringInterval target:self selector:@selector(timerFired:)
                                                userInfo:nil repeats:YES];
    self.timer.tolerance = 0.5;
}

- (void)timerFired:(NSTimer *)timer { [self refreshAndRepair:YES]; }
- (void)workspaceDidWake:(NSNotification *)notification {
    if (self.store.monitoringEnabled) [self refreshAndRepair:YES];
}

- (void)toggleLogin:(NSButton *)sender {
    BOOL enabled = sender.state == NSControlStateValueOn;
    NSError *error = nil;
    if (![OGLaunchAgent setEnabled:enabled error:&error]) {
        sender.state = enabled ? NSControlStateValueOff : NSControlStateValueOn;
        [self showError:error.localizedDescription ?: [self.language text:@"login_error"]];
    }
}

- (void)changeLanguage:(NSPopUpButton *)sender {
    self.language.code = sender.selectedItem.representedObject;
    [self.window orderOut:nil];
    [[NSStatusBar systemStatusBar] removeStatusItem:self.statusItem];
    [self buildStatusItem];
    [self buildWindow];
    [self refreshAndRepair:NO];
    [self showWindow:nil];
}

- (void)showError:(NSString *)text {
    NSAlert *alert = [[NSAlert alloc] init];
    alert.alertStyle = NSAlertStyleWarning;
    alert.messageText = @"OpenGuard";
    alert.informativeText = text;
    [alert runModal];
}

#pragma mark - Updates

- (void)updateChecker:(OGUpdateChecker *)checker
 didFindNewVersion:(NSString *)version
          releaseURL:(NSURL *)releaseURL {
    NSAlert *alert = [[NSAlert alloc] init];
    alert.alertStyle = NSAlertStyleInformational;
    alert.messageText = [self.language text:@"update_available"];
    alert.informativeText = [NSString stringWithFormat:[self.language text:@"update_message"], version];
    [alert addButtonWithTitle:[self.language text:@"update_view_release"]];
    [alert addButtonWithTitle:[self.language text:@"update_later"]];
    [NSApp activateIgnoringOtherApps:YES];
    [alert beginSheetModalForWindow:self.window completionHandler:^(NSModalResponse returnCode) {
        if (returnCode == NSAlertFirstButtonReturn) {
            [[NSWorkspace sharedWorkspace] openURL:releaseURL];
        }
    }];
}

@end
