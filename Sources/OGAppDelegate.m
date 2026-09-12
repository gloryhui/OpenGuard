#import "OGAppDelegate.h"
#import "OGApplicationPicker.h"
#import "OGLaunchAgent.h"
#import "OGLaunchServices.h"
#import "OGRuleStore.h"
#import "OGLanguage.h"

static const NSTimeInterval OGMonitoringInterval = 3.0;
static NSString * const OGOutlinePasteboardType = @"com.gloryhuis.OpenGuard.outline-item";

@interface OGRuleOutlineView : NSOutlineView
@property (copy) void (^deleteSelection)(void);
@end

@implementation OGRuleOutlineView
- (BOOL)performKeyEquivalent:(NSEvent *)event {
    NSEventModifierFlags modifiers = event.modifierFlags & NSEventModifierFlagDeviceIndependentFlagsMask;
    if (self.window.firstResponder == self && modifiers == NSEventModifierFlagCommand &&
        [event.charactersIgnoringModifiers.lowercaseString isEqualToString:@"a"]) {
        [self selectAll:nil];
        return YES;
    }
    return [super performKeyEquivalent:event];
}
- (void)keyDown:(NSEvent *)event {
    NSEventModifierFlags modifiers = event.modifierFlags &
        (NSEventModifierFlagCommand | NSEventModifierFlagControl | NSEventModifierFlagOption | NSEventModifierFlagShift);
    if (!modifiers && (event.keyCode == 51 || event.keyCode == 117)) {
        if (self.deleteSelection) self.deleteSelection();
        return;
    }
    [super keyDown:event];
}
@end

@interface OGAppDelegate ()
@property OGRuleStore *store;
@property OGLanguage *language;
@property NSStatusItem *statusItem;
@property (nonatomic, strong) NSWindow *window;
@property NSOutlineView *outlineView;
@property NSTextField *summaryLabel;
@property NSButton *monitoringCheckbox;
@property NSButton *loginCheckbox;
@property NSButton *removeGroupButton;
@property NSButton *checkUpdatesButton;
@property NSMenu *outlineMenu;
@property NSTextField *ruleExtensionField;
@property NSTextField *ruleNameField;
@property (nonatomic, weak) NSTextField *editingGroupField;
@property (copy, nullable) NSString *editingRuleIdentifier;
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
- (BOOL)applicationShouldHandleReopen:(NSApplication *)sender hasVisibleWindows:(BOOL)hasVisibleWindows {
    if (!hasVisibleWindows) [self showWindow:nil];
    return YES;
}

- (void)buildStatusItem {
    self.statusItem = [[NSStatusBar systemStatusBar] statusItemWithLength:NSVariableStatusItemLength];
    [self updateStatusItemWithWarning:NO];
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

    // Status-item shortcuts alone are not routed from the app's key window.
    NSMenu *mainMenu = [[NSMenu alloc] initWithTitle:@"OpenGuard"];
    NSMenuItem *applicationItem = [[NSMenuItem alloc] initWithTitle:@"OpenGuard" action:NULL keyEquivalent:@""];
    applicationItem.submenu = [menu copy];
    [mainMenu addItem:applicationItem];
    NSApp.mainMenu = mainMenu;
}

- (NSImage *)statusImageWithWarning:(BOOL)warning {
    NSImage *image = [NSImage imageWithSize:NSMakeSize(18, 18)
                                    flipped:NO
                             drawingHandler:^BOOL(NSRect destinationRect) {
        [[NSColor blackColor] setStroke];
        NSBezierPath *shield = [NSBezierPath bezierPath];
        [shield moveToPoint:NSMakePoint(9.0, 16.4)];
        [shield lineToPoint:NSMakePoint(15.1, 13.8)];
        [shield lineToPoint:NSMakePoint(14.8, 8.2)];
        [shield curveToPoint:NSMakePoint(9.0, 1.6)
               controlPoint1:NSMakePoint(14.5, 5.0)
               controlPoint2:NSMakePoint(11.7, 2.6)];
        [shield curveToPoint:NSMakePoint(3.2, 8.2)
               controlPoint1:NSMakePoint(6.3, 2.6)
               controlPoint2:NSMakePoint(3.5, 5.0)];
        [shield lineToPoint:NSMakePoint(2.9, 13.8)];
        [shield closePath];
        shield.lineWidth = 1.5;
        shield.lineJoinStyle = NSRoundLineJoinStyle;
        [shield stroke];

        if (warning) {
            NSBezierPath *mark = [NSBezierPath bezierPath];
            [mark moveToPoint:NSMakePoint(9.0, 11.9)];
            [mark lineToPoint:NSMakePoint(9.0, 7.0)];
            mark.lineWidth = 1.7;
            mark.lineCapStyle = NSRoundLineCapStyle;
            [mark stroke];
            [[NSColor blackColor] setFill];
            [[NSBezierPath bezierPathWithOvalInRect:NSMakeRect(8.1, 4.3, 1.8, 1.8)] fill];
        } else {
            NSBezierPath *check = [NSBezierPath bezierPath];
            [check moveToPoint:NSMakePoint(5.8, 8.7)];
            [check lineToPoint:NSMakePoint(8.0, 6.5)];
            [check lineToPoint:NSMakePoint(12.5, 11.2)];
            check.lineWidth = 1.7;
            check.lineCapStyle = NSRoundLineCapStyle;
            check.lineJoinStyle = NSRoundLineJoinStyle;
            [check stroke];
        }
        return YES;
    }];
    image.template = YES;
    return image;
}

- (void)updateStatusItemWithWarning:(BOOL)warning {
    self.statusItem.button.image = [self statusImageWithWarning:warning];
    self.statusItem.button.imagePosition = NSImageOnly;
    self.statusItem.button.title = @"";
    self.statusItem.button.toolTip = [self.language text:(warning ? @"menu_status_attention" : @"menu_status_protected")];
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
    self.window = [[NSWindow alloc] initWithContentRect:NSMakeRect(0, 0, 1080, 620)
                                              styleMask:(NSWindowStyleMaskTitled | NSWindowStyleMaskClosable |
                                                         NSWindowStyleMaskMiniaturizable | NSWindowStyleMaskResizable)
                                                backing:NSBackingStoreBuffered defer:NO];
    self.window.title = @"OpenGuard";
    self.window.minSize = NSMakeSize(1000, 520);
    self.window.releasedWhenClosed = NO;
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
    OGRuleOutlineView *outline = [[OGRuleOutlineView alloc] initWithFrame:NSZeroRect];
    __weak typeof(self) weakSelf = self;
    outline.deleteSelection = ^{ [weakSelf deleteSelectedItems:nil]; };
    self.outlineView = outline;
    self.outlineView.dataSource = self;
    self.outlineView.delegate = self;
    self.outlineView.headerView = [[NSTableHeaderView alloc] initWithFrame:NSMakeRect(0, 0, 100, 25)];
    self.outlineView.usesAlternatingRowBackgroundColors = YES;
    self.outlineView.allowsMultipleSelection = YES;
    self.outlineView.rowHeight = 28;
    [self.outlineView registerForDraggedTypes:@[OGOutlinePasteboardType]];
    [self.outlineView setDraggingSourceOperationMask:NSDragOperationMove forLocal:YES];
    self.outlineMenu = [[NSMenu alloc] initWithTitle:@""];
    self.outlineMenu.delegate = self;
    NSMenuItem *renameItem = [self.outlineMenu addItemWithTitle:[self.language text:@"rename_group"]
                                                         action:@selector(renameGroup:) keyEquivalent:@""];
    renameItem.target = self;
    NSMenuItem *removeItem = [self.outlineMenu addItemWithTitle:[self.language text:@"remove_group"]
                                                         action:@selector(deleteGroup:) keyEquivalent:@""];
    removeItem.target = self;
    self.outlineView.menu = self.outlineMenu;
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
    typeColumn.width = 205;
    NSTableColumn *nameColumn = [[NSTableColumn alloc] initWithIdentifier:@"displayName"];
    nameColumn.title = [self.language text:@"display_name"];
    nameColumn.width = 180;
    [self.outlineView addTableColumn:nameColumn];
    [self.outlineView addTableColumn:applicationColumn];
    applicationColumn.width = 245;
    [self.outlineView addTableColumn:statusColumn];
    NSTableColumn *actionsColumn = [[NSTableColumn alloc] initWithIdentifier:@"actions"];
    actionsColumn.title = [self.language text:@"actions"];
    actionsColumn.width = 144;
    actionsColumn.minWidth = 144;
    actionsColumn.maxWidth = 144;
    [self.outlineView addTableColumn:actionsColumn];
    self.outlineView.outlineTableColumn = typeColumn;
    scroll.documentView = self.outlineView;

    NSButton *addGroup = [self button:[self.language text:@"add_group"] action:@selector(addGroup:)];
    NSButton *addRule = [self button:[self.language text:@"add_rule"] action:@selector(showRuleEditor:)];
    self.removeGroupButton = [self button:[self.language text:@"remove_group"] action:@selector(deleteGroup:)];
    self.removeGroupButton.enabled = NO;
    NSPopUpButton *settings = [[NSPopUpButton alloc] initWithFrame:NSZeroRect pullsDown:YES];
    settings.translatesAutoresizingMaskIntoConstraints = NO;
    [settings addItemWithTitle:[self.language text:@"settings"]];
    [settings.menu addItem:[NSMenuItem separatorItem]];
    NSMenuItem *initializeItem = [settings.menu addItemWithTitle:[self.language text:@"restore_groups"]
                                                          action:@selector(restoreGroups:) keyEquivalent:@""];
    initializeItem.target = self;
    self.checkUpdatesButton = [self button:[self.language text:@"check_updates"] action:@selector(checkForUpdates:)];
    NSButton *about = [self button:[self.language text:@"about"] action:@selector(showAbout:)];
    NSView *toolbar = [[NSView alloc] initWithFrame:NSZeroRect];
    toolbar.translatesAutoresizingMaskIntoConstraints = NO;
    for (NSView *view in @[addGroup, addRule, self.removeGroupButton, settings, self.checkUpdatesButton, about]) {
        [toolbar addSubview:view];
        [toolbar addConstraint:[NSLayoutConstraint constraintWithItem:view attribute:NSLayoutAttributeCenterY
                                                            relatedBy:NSLayoutRelationEqual toItem:toolbar
                                                            attribute:NSLayoutAttributeCenterY multiplier:1 constant:0]];
    }
    NSDictionary *toolbarViews = NSDictionaryOfVariableBindings(addGroup, addRule, _removeGroupButton,
                                                                  settings, _checkUpdatesButton, about);
    [toolbar addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:
                             @"H:|[addGroup]-8-[addRule]-8-[_removeGroupButton]-(>=12)-[settings]-8-[_checkUpdatesButton]-8-[about]|"
                                                                     options:NSLayoutFormatAlignAllCenterY
                                                                     metrics:nil views:toolbarViews]];


    NSButton *apply = [self button:[self.language text:@"apply_all"] action:@selector(applyNow:)];
    self.monitoringCheckbox = [NSButton checkboxWithTitle:[self.language text:@"monitor_auto"] target:self
                                                    action:@selector(toggleMonitoring:)];
    self.monitoringCheckbox.translatesAutoresizingMaskIntoConstraints = NO;
    self.monitoringCheckbox.state = self.store.monitoringEnabled ? NSControlStateValueOn : NSControlStateValueOff;
    self.loginCheckbox = [NSButton checkboxWithTitle:[self.language text:@"start_login"] target:self
                                               action:@selector(toggleLogin:)];
    self.loginCheckbox.translatesAutoresizingMaskIntoConstraints = NO;
    self.loginCheckbox.state = [OGLaunchAgent isEnabled] ? NSControlStateValueOn : NSControlStateValueOff;

    for (NSView *view in @[title, toolbar, self.summaryLabel, languageLabel, languagePopup,
                           scroll, apply, self.monitoringCheckbox, self.loginCheckbox]) [content addSubview:view];
    NSDictionary *views = NSDictionaryOfVariableBindings(title, toolbar, _summaryLabel,
                                                           languageLabel, languagePopup, scroll, apply,
                                                           _monitoringCheckbox, _loginCheckbox);
    [content addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"H:|-24-[title]-(>=20)-[languageLabel]-6-[languagePopup]-24-|"
                                                                    options:NSLayoutFormatAlignAllCenterY metrics:nil views:views]];
    [content addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"H:|-24-[_summaryLabel]-24-|"
                                                                    options:0 metrics:nil views:views]];
    [content addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"H:|-24-[toolbar]-24-|"
                                                                    options:0 metrics:nil views:views]];
    [content addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"H:|-24-[scroll]-24-|"
                                                                    options:0 metrics:nil views:views]];
    [content addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"H:|-24-[_monitoringCheckbox]-(>=12)-[apply]-24-|"
                                                                    options:NSLayoutFormatAlignAllCenterY metrics:nil views:views]];
    [content addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"H:|-24-[_loginCheckbox]-24-|"
                                                                    options:0 metrics:nil views:views]];
    [content addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"V:|-18-[title]-10-[toolbar(30)]-6-[_summaryLabel]-12-[scroll]-12-[_monitoringCheckbox]-6-[_loginCheckbox]-16-|"
                                                                    options:0 metrics:nil views:views]];
    [self.outlineView reloadData];
    [self expandAllGroups];
}

- (void)showWindow:(id)sender {
    NSWindow *window = self.window;
    [NSApp activateIgnoringOtherApps:YES];
    [window makeKeyAndOrderFront:nil];
}
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
- (NSString *)titleForGroup:(NSDictionary *)group {
    NSString *customTitle = group[OGGroupNameKey];
    return customTitle.length ? customTitle : [self.language text:group[OGGroupTitleKey]];
}

#pragma mark - Outline table

- (NSInteger)outlineView:(NSOutlineView *)outlineView numberOfChildrenOfItem:(id)item {
    return item ? [item[OGGroupItemsKey] count] : self.store.rootItems.count;
}
- (id)outlineView:(NSOutlineView *)outlineView child:(NSInteger)index ofItem:(id)item {
    return item ? item[OGGroupItemsKey][index] : self.store.rootItems[index];
}
- (BOOL)outlineView:(NSOutlineView *)outlineView isItemExpandable:(id)item { return [self isGroup:item]; }

- (NSView *)outlineView:(NSOutlineView *)outlineView viewForTableColumn:(NSTableColumn *)column item:(NSDictionary *)item {
    BOOL group = [self isGroup:item];
    BOOL editing = !group && [item[OGRuleIdentifierKey] isEqualToString:self.editingRuleIdentifier];
    if ([column.identifier isEqualToString:@"actions"]) return group ? [self actionsCellForGroup:item] : [self actionsCellForRule:item];
    if (editing && [column.identifier isEqualToString:@"filetype"]) return self.ruleExtensionField;
    if (editing && [column.identifier isEqualToString:@"displayName"]) return self.ruleNameField;
    if ([column.identifier isEqualToString:@"displayName"]) {
        return [NSTextField labelWithString:group ? @"" : ([item[OGRuleNameKey] length] ? item[OGRuleNameKey] : [self.language text:@"new_rule"])];
    }
    if ([column.identifier isEqualToString:@"application"]) return [self applicationCellForItem:item group:group];
    NSTextField *cell = [NSTextField labelWithString:@""];
    cell.lineBreakMode = NSLineBreakByTruncatingTail;
    if ([column.identifier isEqualToString:@"filetype"]) {
        cell.stringValue = group ? [self titleForGroup:item]
                                 : ([item[OGRuleExtensionKey] length] ? [@"." stringByAppendingString:item[OGRuleExtensionKey]] : @"—");
        if (group) {
            cell.font = [NSFont boldSystemFontOfSize:13];
            cell.editable = NO;
            cell.selectable = NO;
            cell.delegate = self;
            cell.identifier = @"groupTitle";
        }
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
    NSArray<NSDictionary *> *items = [group[OGGroupItemsKey] filteredArrayUsingPredicate:
        [NSPredicate predicateWithBlock:^BOOL(NSDictionary *rule, NSDictionary *bindings) {
            return [rule[OGRuleExtensionKey] length] > 0;
        }]] ?: @[];
    if (items.count == 0 && [group[OGRuleBundleIdentifierKey] length]) {
        NSString *name = group[OGRuleApplicationNameKey];
        return name.length ? name : group[OGRuleBundleIdentifierKey];
    }
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
        if (![item[OGRuleExtensionKey] length]) continue;
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
    self.removeGroupButton.enabled = item && [self isGroup:item];
}

- (NSDictionary *)dragPayloadFromInfo:(id<NSDraggingInfo>)info {
    NSString *JSON = [[info draggingPasteboard] stringForType:OGOutlinePasteboardType];
    NSData *data = [JSON dataUsingEncoding:NSUTF8StringEncoding];
    id payload = data ? [NSJSONSerialization JSONObjectWithData:data options:0 error:nil] : nil;
    return [payload isKindOfClass:[NSDictionary class]] ? payload : nil;
}

- (id<NSPasteboardWriting>)outlineView:(NSOutlineView *)outlineView
               pasteboardWriterForItem:(NSDictionary *)item {
    if (self.editingRuleIdentifier || (![self isGroup:item] && ![item[OGRuleExtensionKey] length])) return nil;
    NSMutableDictionary *payload = [NSMutableDictionary dictionary];
    if ([self isGroup:item]) {
        payload[@"kind"] = @"group";
        payload[@"identifier"] = item[OGGroupIdentifierKey];
    } else {
        payload[@"kind"] = @"rule";
        payload[@"extension"] = item[OGRuleExtensionKey];
        NSDictionary *parent = [outlineView parentForItem:item];
        if (parent[OGGroupIdentifierKey]) payload[@"parent"] = parent[OGGroupIdentifierKey];
    }
    NSData *data = [NSJSONSerialization dataWithJSONObject:payload options:0 error:nil];
    if (!data) return nil;
    NSPasteboardItem *pasteboardItem = [[NSPasteboardItem alloc] init];
    [pasteboardItem setString:[[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding]
                      forType:OGOutlinePasteboardType];
    return pasteboardItem;
}

- (NSDragOperation)outlineView:(NSOutlineView *)outlineView
                   validateDrop:(id<NSDraggingInfo>)info
                   proposedItem:(NSDictionary *)item
             proposedChildIndex:(NSInteger)index {
    NSDictionary *payload = [self dragPayloadFromInfo:info];
    if ([payload[@"kind"] isEqualToString:@"group"]) {
        if (!item) return index >= 0 ? NSDragOperationMove : NSDragOperationNone;
        // A group cannot be nested. Convert drops over rows (including children
        // of expanded groups) to a root insertion before/after the target group.
        NSDictionary *rootItem = [outlineView parentForItem:item] ?: item;
        NSUInteger targetIndex = [self.store.rootItems indexOfObject:rootItem];
        NSDictionary *source = [self.store groupWithIdentifier:payload[@"identifier"]];
        NSUInteger sourceIndex = source ? [self.store.rootItems indexOfObject:source] : NSNotFound;
        if (targetIndex == NSNotFound || sourceIndex == NSNotFound || sourceIndex == targetIndex)
            return NSDragOperationNone;
        NSInteger insertion = (NSInteger)targetIndex + (sourceIndex < targetIndex ? 1 : 0);
        [outlineView setDropItem:nil dropChildIndex:insertion];
        return NSDragOperationMove;
    }
    if (![payload[@"kind"] isEqualToString:@"rule"]) return NSDragOperationNone;
    if (item && ![self isGroup:item]) return NSDragOperationNone;
    return NSDragOperationMove;
}

- (BOOL)outlineView:(NSOutlineView *)outlineView
          acceptDrop:(id<NSDraggingInfo>)info
                item:(NSDictionary *)item
          childIndex:(NSInteger)index {
    NSDictionary *payload = [self dragPayloadFromInfo:info];
    NSSet<NSString *> *expanded = [self expandedGroupIdentifiers];
    BOOL moved = NO;
    if ([payload[@"kind"] isEqualToString:@"group"]) {
        NSUInteger destination = index < 0 ? self.store.rootItems.count : (NSUInteger)index;
        moved = [self.store moveGroup:payload[@"identifier"] toIndex:destination];
    } else if ([payload[@"kind"] isEqualToString:@"rule"]) {
        NSString *destinationIdentifier = [self isGroup:item] ? item[OGGroupIdentifierKey] : nil;
        NSUInteger destination = index < 0
            ? ([self isGroup:item] ? [item[OGGroupItemsKey] count] : self.store.rootItems.count)
            : (NSUInteger)index;
        moved = [self.store moveRuleWithExtension:payload[@"extension"]
                                        fromGroup:payload[@"parent"]
                                          toGroup:destinationIdentifier
                                          atIndex:destination];
        if (destinationIdentifier) expanded = [expanded setByAddingObject:destinationIdentifier];
    }
    if (!moved) return NO;
    [self reloadOutlineWithExpandedGroupIdentifiers:expanded];
    [self refreshAndRepair:NO];
    return YES;
}

#pragma mark - Group and application actions

- (void)beginEditingGroupAtRow:(NSInteger)row {
    if (self.editingRuleIdentifier) { [self focusRuleEditor]; return; }
    if (row < 0 || row >= self.outlineView.numberOfRows) return;
    NSDictionary *item = [self.outlineView itemAtRow:row];
    if (![self isGroup:item]) return;
    NSTextField *field = [self.outlineView viewAtColumn:0 row:row makeIfNecessary:YES];
    field.editable = YES;
    field.selectable = YES;
    self.editingGroupField = field;
    [self.window makeFirstResponder:self.outlineView];
    [self.outlineView editColumn:0 row:row withEvent:nil select:YES];
}

- (NSInteger)contextRow {
    NSInteger clickedRow = self.outlineView.clickedRow;
    return clickedRow >= 0 ? clickedRow : self.outlineView.selectedRow;
}

- (NSDictionary *)contextGroup {
    NSInteger row = [self contextRow];
    NSDictionary *item = row >= 0 ? [self.outlineView itemAtRow:row] : nil;
    return [self isGroup:item] ? item : nil;
}

- (void)menuNeedsUpdate:(NSMenu *)menu {
    if (menu != self.outlineMenu) return;
    [menu removeAllItems];
    NSInteger row = [self contextRow];
    NSDictionary *item = row >= 0 ? [self.outlineView itemAtRow:row] : nil;
    if (!item) return;
    BOOL group = [self isGroup:item];
    BOOL editing = !group && [item[OGRuleIdentifierKey] isEqualToString:self.editingRuleIdentifier];
    NSArray *keys = group ? @[@"rename_group", @"remove_group"]
                         : (editing ? @[@"confirm", @"cancel"] : @[@"edit_rule", @"delete_rule"]);
    SEL first = group ? @selector(renameGroup:) : (editing ? @selector(confirmAddRule:) : @selector(editRule:));
    SEL second = group ? @selector(deleteGroup:) : (editing ? @selector(cancelAddRule:) : @selector(deleteRule:));
    NSMenuItem *firstItem = [menu addItemWithTitle:[self.language text:keys[0]] action:first keyEquivalent:@""];
    NSMenuItem *secondItem = [menu addItemWithTitle:[self.language text:keys[1]] action:second keyEquivalent:@""];
    menu.autoenablesItems = NO;
    for (NSMenuItem *entry in menu.itemArray) {
        entry.target = self;
        entry.enabled = !self.editingRuleIdentifier || editing;
    }
    firstItem.image = [self ruleActionImage:editing ? @"confirm" : @"edit"];
    secondItem.image = [self ruleActionImage:editing ? @"cancel" : @"delete"];
    if (!self.editingRuleIdentifier) {
        [self.outlineView selectRowIndexes:[NSIndexSet indexSetWithIndex:(NSUInteger)row]
                     byExtendingSelection:NO];
    }
}

- (void)addGroup:(id)sender {
    if (self.editingRuleIdentifier) { [self focusRuleEditor]; return; }
    NSString *identifier = [self.store addGroupWithTitle:[self.language text:@"new_group"]];
    NSSet<NSString *> *expanded = [[self expandedGroupIdentifiers] setByAddingObject:identifier];
    [self reloadOutlineWithExpandedGroupIdentifiers:expanded];
    NSDictionary *group = [self.store groupWithIdentifier:identifier];
    NSInteger row = [self.outlineView rowForItem:group];
    if (row >= 0) {
        [self.outlineView selectRowIndexes:[NSIndexSet indexSetWithIndex:(NSUInteger)row]
                     byExtendingSelection:NO];
        [self.outlineView scrollRowToVisible:row];
        dispatch_async(dispatch_get_main_queue(), ^{
            [self beginEditingGroupAtRow:row];
        });
    }
    [self refreshAndRepair:NO];
}

- (void)renameGroup:(id)sender {
    NSInteger row = [self contextRow];
    if (![self contextGroup] || row < 0) return;
    [self.outlineView selectRowIndexes:[NSIndexSet indexSetWithIndex:(NSUInteger)row]
                 byExtendingSelection:NO];
    dispatch_async(dispatch_get_main_queue(), ^{
        [self beginEditingGroupAtRow:row];
    });
}

- (void)controlTextDidEndEditing:(NSNotification *)notification {
    NSTextField *field = notification.object;
    if (![field.identifier isEqualToString:@"groupTitle"]) return;
    self.editingGroupField = nil;
    NSInteger row = [self.outlineView rowForView:field];
    NSDictionary *group = row >= 0 ? [self.outlineView itemAtRow:row] : nil;
    NSString *title = [field.stringValue stringByTrimmingCharactersInSet:
                       [NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (group && [self isGroup:group] && title.length) {
        [self.store renameGroup:group[OGGroupIdentifierKey] title:title];
    }
    NSSet<NSString *> *expanded = [self expandedGroupIdentifiers];
    [self reloadOutlineWithExpandedGroupIdentifiers:expanded];
}

- (NSImage *)ruleActionImage:(NSString *)kind {
    NSImage *image = [NSImage imageWithSize:NSMakeSize(18, 18) flipped:NO drawingHandler:^BOOL(NSRect rect) {
        [NSColor.labelColor setStroke];
        NSBezierPath *path = [NSBezierPath bezierPath];
        path.lineWidth = 1.5;
        path.lineCapStyle = NSRoundLineCapStyle;
        path.lineJoinStyle = NSRoundLineJoinStyle;
        if ([kind isEqualToString:@"edit"]) {
            [path moveToPoint:NSMakePoint(3, 3)]; [path lineToPoint:NSMakePoint(4, 7)];
            [path lineToPoint:NSMakePoint(12, 15)]; [path lineToPoint:NSMakePoint(15, 12)];
            [path lineToPoint:NSMakePoint(7, 4)]; [path closePath];
            [path moveToPoint:NSMakePoint(10, 13)]; [path lineToPoint:NSMakePoint(13, 10)];
        } else if ([kind isEqualToString:@"delete"]) {
            [path moveToPoint:NSMakePoint(3, 13)]; [path lineToPoint:NSMakePoint(15, 13)];
            [path moveToPoint:NSMakePoint(6, 13)]; [path lineToPoint:NSMakePoint(6, 16)];
            [path lineToPoint:NSMakePoint(12, 16)]; [path lineToPoint:NSMakePoint(12, 13)];
            [path moveToPoint:NSMakePoint(4, 11)]; [path lineToPoint:NSMakePoint(5, 2)];
            [path lineToPoint:NSMakePoint(13, 2)]; [path lineToPoint:NSMakePoint(14, 11)];
            [path moveToPoint:NSMakePoint(7, 10)]; [path lineToPoint:NSMakePoint(7.5, 5)];
            [path moveToPoint:NSMakePoint(11, 10)]; [path lineToPoint:NSMakePoint(10.5, 5)];
        } else if ([kind isEqualToString:@"up"] || [kind isEqualToString:@"down"]) {
            BOOL up = [kind isEqualToString:@"up"];
            CGFloat tip = up ? 14 : 4;
            CGFloat tail = up ? 4 : 14;
            CGFloat shoulder = 9;
            [path moveToPoint:NSMakePoint(9, tail)]; [path lineToPoint:NSMakePoint(9, tip)];
            [path moveToPoint:NSMakePoint(4, shoulder)]; [path lineToPoint:NSMakePoint(9, tip)];
            [path lineToPoint:NSMakePoint(14, shoulder)];
        } else if ([kind isEqualToString:@"confirm"]) {
            [path moveToPoint:NSMakePoint(3, 9)]; [path lineToPoint:NSMakePoint(7, 5)];
            [path lineToPoint:NSMakePoint(15, 13)];
        } else {
            [path moveToPoint:NSMakePoint(4, 4)]; [path lineToPoint:NSMakePoint(14, 14)];
            [path moveToPoint:NSMakePoint(4, 14)]; [path lineToPoint:NSMakePoint(14, 4)];
        }
        [path stroke];
        return YES;
    }];
    image.template = YES;
    return image;
}

- (NSView *)actionsCellForGroup:(NSDictionary *)group {
    NSView *container = [[NSView alloc] initWithFrame:NSMakeRect(0, 0, 144, 28)];
    NSArray *icons = @[@"edit", @"up", @"down", @"delete"];
    NSArray *tips = @[@"rename_group", @"move_group_up", @"move_group_down", @"delete_group"];
    NSArray *groups = self.store.groups;
    NSUInteger index = [groups indexOfObject:group];
    for (NSUInteger i = 0; i < 4; i++) {
        NSButton *button = [NSButton buttonWithImage:[self ruleActionImage:icons[i]] target:self
                                             action:i == 0 ? @selector(editGroupFromButton:) :
                                                 (i == 3 ? @selector(deleteGroup:) : @selector(moveGroupFromButton:))];
        button.frame = NSMakeRect(4 + i * 34, 1, 30, 26);
        button.bordered = NO;
        button.imagePosition = NSImageOnly;
        button.identifier = group[OGGroupIdentifierKey];
        button.tag = i == 1 ? -1 : 1;
        button.toolTip = [self.language text:tips[i]];
        [button setAccessibilityLabel:button.toolTip];
        button.enabled = !self.editingRuleIdentifier && index != NSNotFound &&
            (i == 0 || i == 3 || (i == 1 ? index > 0 : index + 1 < groups.count));
        [container addSubview:button];
    }
    return container;
}

- (void)editGroupFromButton:(NSButton *)sender {
    if (self.editingRuleIdentifier) return;
    NSString *identifier = sender.identifier;
    [self.window makeFirstResponder:self.outlineView];
    NSDictionary *group = [self.store groupWithIdentifier:identifier];
    NSInteger row = [self.outlineView rowForItem:group];
    if (row < 0) return;
    [self.outlineView selectRowIndexes:[NSIndexSet indexSetWithIndex:row] byExtendingSelection:NO];
    [self beginEditingGroupAtRow:row];
}

- (void)moveGroupFromButton:(NSButton *)sender {
    if (self.editingRuleIdentifier) return;
    NSString *identifier = sender.identifier;
    NSInteger direction = sender.tag;
    [self.window makeFirstResponder:self.outlineView];
    NSDictionary *group = [self.store groupWithIdentifier:identifier];
    NSArray *groups = self.store.groups;
    if (!group) return;
    NSUInteger index = [groups indexOfObject:group];
    if (index == NSNotFound || (direction < 0 ? index == 0 : index + 1 >= groups.count)) return;
    NSDictionary *neighbor = groups[direction < 0 ? index - 1 : index + 1];
    NSUInteger destination = [self.store.rootItems indexOfObject:neighbor] + (direction > 0 ? 1 : 0);
    NSSet *expanded = [self expandedGroupIdentifiers];
    if (![self.store moveGroup:identifier toIndex:destination]) return;
    [self reloadOutlineWithExpandedGroupIdentifiers:expanded];
    NSInteger row = [self.outlineView rowForItem:[self.store groupWithIdentifier:identifier]];
    if (row >= 0) {
        [self.outlineView selectRowIndexes:[NSIndexSet indexSetWithIndex:row] byExtendingSelection:NO];
        [self.outlineView scrollRowToVisible:row];
    }
    [self refreshAndRepair:NO];
}

- (NSView *)actionsCellForRule:(NSDictionary *)rule {
    BOOL editing = [rule[OGRuleIdentifierKey] isEqualToString:self.editingRuleIdentifier];
    NSView *container = [[NSView alloc] initWithFrame:NSMakeRect(0, 0, 80, 28)];
    NSArray *icons = editing ? @[@"confirm", @"cancel"] : @[@"edit", @"delete"];
    NSArray *tips = editing ? @[@"confirm", @"cancel"] : @[@"edit_rule", @"delete_rule"];
    for (NSUInteger i = 0; i < 2; i++) {
        SEL action = editing ? (i == 0 ? @selector(confirmAddRule:) : @selector(cancelAddRule:))
                             : (i == 0 ? @selector(editRule:) : @selector(deleteRule:));
        NSButton *button = [NSButton buttonWithImage:[self ruleActionImage:icons[i]] target:self action:action];
        button.frame = NSMakeRect(4 + i * 34, 1, 30, 26);
        button.bordered = NO;
        button.imagePosition = NSImageOnly;
        button.toolTip = [self.language text:tips[i]];
        [button setAccessibilityLabel:button.toolTip];
        button.enabled = !self.editingRuleIdentifier || editing;
        [container addSubview:button];
    }
    return container;
}

- (NSDictionary *)ruleForAction:(id)sender {
    NSInteger row = [sender isKindOfClass:NSMenuItem.class] ? [self contextRow]
        : [self.outlineView rowForView:sender];
    NSDictionary *item = row >= 0 ? [self.outlineView itemAtRow:row] : nil;
    return item && ![self isGroup:item] ? item : nil;
}

- (void)focusRuleEditor {
    NSDictionary *rule = [self.store ruleWithIdentifier:self.editingRuleIdentifier];
    NSInteger row = [self.outlineView rowForItem:rule];
    if (row < 0) return;
    [self.outlineView selectRowIndexes:[NSIndexSet indexSetWithIndex:row] byExtendingSelection:NO];
    [self.outlineView scrollRowToVisible:row];
    [self.outlineView layoutSubtreeIfNeeded];
    [self.outlineView viewAtColumn:0 row:row makeIfNecessary:YES];
    [self.outlineView viewAtColumn:1 row:row makeIfNecessary:YES];
    [self.window makeFirstResponder:self.ruleExtensionField];
}

- (void)beginEditingRule:(NSString *)identifier {
    if (self.editingRuleIdentifier) { [self focusRuleEditor]; return; }
    [self.window makeFirstResponder:self.outlineView];
    NSDictionary *rule = [self.store ruleWithIdentifier:identifier];
    if (!rule) return;
    self.editingRuleIdentifier = identifier;
    self.ruleExtensionField = [[NSTextField alloc] initWithFrame:NSMakeRect(0, 0, 180, 24)];
    self.ruleNameField = [[NSTextField alloc] initWithFrame:NSMakeRect(0, 0, 180, 24)];
    self.ruleExtensionField.placeholderString = [self.language text:@"rule_extension_placeholder"];
    self.ruleNameField.placeholderString = [self.language text:@"rule_name_placeholder"];
    self.ruleExtensionField.stringValue = rule[OGRuleExtensionKey] ?: @"";
    self.ruleNameField.stringValue = rule[OGRuleNameKey] ?: @"";
    self.ruleExtensionField.nextKeyView = self.ruleNameField;
    for (NSTextField *field in @[self.ruleExtensionField, self.ruleNameField]) {
        field.font = [NSFont systemFontOfSize:13];
        field.focusRingType = NSFocusRingTypeExterior;
        [field setAccessibilityLabel:field.placeholderString];
    }
    NSSet *expanded = [self expandedGroupIdentifiers];
    [self reloadOutlineWithExpandedGroupIdentifiers:expanded];
    [self focusRuleEditor];
}

- (BOOL)outlineView:(NSOutlineView *)outlineView shouldCollapseItem:(NSDictionary *)item {
    if (!self.editingRuleIdentifier) return YES;
    for (NSDictionary *rule in item[OGGroupItemsKey]) {
        if ([rule[OGRuleIdentifierKey] isEqualToString:self.editingRuleIdentifier]) return NO;
    }
    return YES;
}

- (void)showRuleEditor:(id)sender {
    if (self.editingRuleIdentifier) { [self focusRuleEditor]; return; }
    NSInteger row = self.outlineView.selectedRow;
    NSDictionary *selectedItem = row >= 0 ? [self.outlineView itemAtRow:row] : nil;
    NSDictionary *group = [self isGroup:selectedItem] ? selectedItem
        : (selectedItem ? [self.outlineView parentForItem:selectedItem] : nil);
    NSString *groupIdentifier = group[OGGroupIdentifierKey];
    [self.window makeFirstResponder:self.outlineView];
    NSSet *expanded = [self expandedGroupIdentifiers];
    if (groupIdentifier) expanded = [expanded setByAddingObject:groupIdentifier];
    NSString *identifier = [self.store addDraftRuleToGroup:groupIdentifier];
    [self reloadOutlineWithExpandedGroupIdentifiers:expanded];
    [self beginEditingRule:identifier];
    [self refreshAndRepair:NO];
}

- (void)editRule:(id)sender {
    NSDictionary *rule = [self ruleForAction:sender];
    if (rule) [self beginEditingRule:rule[OGRuleIdentifierKey]];
}

- (void)cancelAddRule:(id)sender {
    if (!self.editingRuleIdentifier) return;
    NSString *identifier = self.editingRuleIdentifier;
    [self.window makeFirstResponder:self.outlineView];
    NSSet *expanded = [self expandedGroupIdentifiers];
    self.editingRuleIdentifier = nil;
    self.ruleExtensionField = nil;
    self.ruleNameField = nil;
    [self reloadOutlineWithExpandedGroupIdentifiers:expanded];
    NSInteger row = [self.outlineView rowForItem:[self.store ruleWithIdentifier:identifier]];
    if (row >= 0) [self.outlineView selectRowIndexes:[NSIndexSet indexSetWithIndex:row] byExtendingSelection:NO];
    [self refreshAndRepair:NO];
}

- (void)confirmAddRule:(id)sender {
    if (!self.editingRuleIdentifier) return;
    [self.window makeFirstResponder:self.outlineView];
    NSString *extension = [[self.ruleExtensionField.stringValue
        stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet] lowercaseString];
    while ([extension hasPrefix:@"."]) extension = [extension substringFromIndex:1];
    NSDictionary *original = [self.store ruleWithIdentifier:self.editingRuleIdentifier];
    if (![extension isEqualToString:original[OGRuleExtensionKey]] && [self.store containsRuleWithExtension:extension]) {
        [self showError:[NSString stringWithFormat:[self.language text:@"duplicate_rule"], extension]];
        return;
    }
    if (![self.store updateRule:self.editingRuleIdentifier extension:extension name:self.ruleNameField.stringValue]) {
        [self showError:[self.language text:@"invalid_extension"]];
        return;
    }
    [self cancelAddRule:nil];
}

- (void)deleteSelectedItems:(id)sender {
    if (self.editingRuleIdentifier || self.editingGroupField.currentEditor || self.window.attachedSheet) return;
    NSMutableSet<NSString *> *groupIDs = [NSMutableSet set];
    NSMutableSet<NSString *> *ruleIDs = [NSMutableSet set];
    [self.outlineView.selectedRowIndexes enumerateIndexesUsingBlock:^(NSUInteger row, BOOL *stop) {
        NSDictionary *item = [self.outlineView itemAtRow:row];
        if ([self isGroup:item]) {
            [groupIDs addObject:item[OGGroupIdentifierKey]];
            NSDictionary *group = [self.store groupWithIdentifier:item[OGGroupIdentifierKey]];
            for (NSDictionary *rule in group[OGGroupItemsKey]) [ruleIDs addObject:rule[OGRuleIdentifierKey]];
        } else if (item[OGRuleIdentifierKey]) {
            [ruleIDs addObject:item[OGRuleIdentifierKey]];
        }
    }];
    if (!groupIDs.count && !ruleIDs.count) return;
    NSAlert *alert = [[NSAlert alloc] init];
    alert.alertStyle = NSAlertStyleWarning;
    alert.messageText = [self.language text:@"delete_selection_title"];
    alert.informativeText = [NSString stringWithFormat:[self.language text:@"delete_selection_message"],
                            (unsigned long)groupIDs.count, (unsigned long)ruleIDs.count];
    [alert addButtonWithTitle:[self.language text:@"cancel"]];
    [alert addButtonWithTitle:[self.language text:@"delete_selection_confirm"]];
    [alert beginSheetModalForWindow:self.window completionHandler:^(NSModalResponse response) {
        if (response != NSAlertSecondButtonReturn) return;
        NSSet *expanded = [self expandedGroupIdentifiers];
        for (NSString *identifier in groupIDs) [self.store removeGroupAndRules:identifier];
        for (NSString *identifier in ruleIDs) [self.store removeRule:identifier];
        [self reloadOutlineWithExpandedGroupIdentifiers:expanded];
        [self refreshAndRepair:NO];
    }];
}

- (void)deleteRule:(id)sender {
    if (self.editingRuleIdentifier) { [self focusRuleEditor]; return; }
    NSDictionary *rule = [self ruleForAction:sender];
    if (!rule) return;
    NSSet *expanded = [self expandedGroupIdentifiers];
    [self.store removeRule:rule[OGRuleIdentifierKey]];
    [self reloadOutlineWithExpandedGroupIdentifiers:expanded];
    [self refreshAndRepair:NO];
}

- (void)chooseApplication:(NSButton *)sender {
    if (self.editingRuleIdentifier) { [self focusRuleEditor]; return; }
    NSInteger row = [self.outlineView rowForView:sender];
    if (row < 0) return;
    NSDictionary *item = [self.outlineView itemAtRow:row];
    BOOL group = [self isGroup:item];
    NSString *title = group ? [NSString stringWithFormat:[self.language text:@"choose_group_app"],
                               [self titleForGroup:item]]
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
        [self.store setApplication:application forRule:item[OGRuleIdentifierKey]];
    }
    [self reloadOutlineWithExpandedGroupIdentifiers:expandedGroups];
    [self refreshAndRepair:YES];
}

- (void)deleteGroup:(id)sender {
    if (self.editingRuleIdentifier) { [self focusRuleEditor]; return; }
    NSInteger row = [sender isKindOfClass:[NSMenuItem class]] ? [self contextRow] : self.outlineView.selectedRow;
    NSDictionary *candidate = row >= 0 ? [self.outlineView itemAtRow:row] : nil;
    NSDictionary *group = [self isGroup:candidate] ? candidate : nil;
    if ([sender isKindOfClass:NSButton.class] && [sender identifier])
        group = [self.store groupWithIdentifier:[sender identifier]];
    if (!group || ![self isGroup:group]) return;
    NSString *identifier = group[OGGroupIdentifierKey];
    NSAlert *alert = [[NSAlert alloc] init];
    alert.alertStyle = NSAlertStyleWarning;
    alert.messageText = [NSString stringWithFormat:[self.language text:@"delete_group_prompt"], [self titleForGroup:group]];
    alert.informativeText = [self.language text:@"delete_group_choices_message"];
    [alert addButtonWithTitle:[self.language text:@"delete_group_only"]];
    [alert addButtonWithTitle:[self.language text:@"delete_group_and_rules"]];
    NSButton *cancel = [alert addButtonWithTitle:[self.language text:@"cancel"]];
    cancel.keyEquivalent = @"\033";
    [alert beginSheetModalForWindow:self.window completionHandler:^(NSModalResponse response) {
        if (response != NSAlertFirstButtonReturn && response != NSAlertSecondButtonReturn) return;
        NSSet *expanded = [self expandedGroupIdentifiers];
        if (response == NSAlertFirstButtonReturn) [self.store removeGroup:identifier];
        else [self.store removeGroupAndRules:identifier];
        [self reloadOutlineWithExpandedGroupIdentifiers:expanded];
        self.removeGroupButton.enabled = NO;
        [self refreshAndRepair:NO];
    }];
}

- (void)restoreGroups:(id)sender {
    if (self.editingRuleIdentifier) { [self focusRuleEditor]; return; }
    NSAlert *alert = [[NSAlert alloc] init];
    alert.alertStyle = NSAlertStyleCritical;
    alert.messageText = [self.language text:@"initialize_groups_warning_title"];
    alert.informativeText = [self.language text:@"initialize_groups_warning_message"];
    [alert addButtonWithTitle:[self.language text:@"initialize_groups_confirm"]];
    [alert addButtonWithTitle:[self.language text:@"cancel"]];
    [alert beginSheetModalForWindow:self.window completionHandler:^(NSModalResponse response) {
        if (response != NSAlertFirstButtonReturn) return;
        [self.store restoreDefaultGroups];
        [self.outlineView reloadData];
        [self expandAllGroups];
        [self refreshAndRepair:NO];
    }];
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
    [self updateStatusItemWithWarning:protectedCount != rules.count];
    // Even a status-column reload can terminate AppKit's shared field editor
    // and commit unfinished IME marked text. Keep enforcing rules, but defer
    // table refreshes until the group-name edit has ended.
    if (self.editingGroupField.currentEditor || self.editingRuleIdentifier) return;
    NSInteger rowCount = self.outlineView.numberOfRows;
    if (rowCount > 0) {
        [self.outlineView reloadDataForRowIndexes:[NSIndexSet indexSetWithIndexesInRange:NSMakeRange(0, rowCount)]
                                   columnIndexes:[NSIndexSet indexSetWithIndex:[self.outlineView columnWithIdentifier:@"status"]]];
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
    if (self.editingRuleIdentifier) {
        for (NSMenuItem *item in sender.itemArray)
            if ([item.representedObject isEqualToString:self.language.code]) [sender selectItem:item];
        [self focusRuleEditor];
        return;
    }
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

- (void)showAbout:(id)sender {
    NSString *version = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleShortVersionString"] ?: @"0";
    NSAlert *alert = [[NSAlert alloc] init];
    alert.alertStyle = NSAlertStyleInformational;
    alert.messageText = @"OpenGuard";
    alert.informativeText = [NSString stringWithFormat:[self.language text:@"about_message"], version];
    [alert addButtonWithTitle:[self.language text:@"ok"]];
    [alert beginSheetModalForWindow:self.window completionHandler:nil];
}

- (void)checkForUpdates:(id)sender {
    self.checkUpdatesButton.enabled = NO;
    self.checkUpdatesButton.title = [self.language text:@"checking_updates"];
    __weak typeof(self) weakSelf = self;
    [self.updateChecker checkNowWithCompletion:^(NSString *version, NSURL *releaseURL, NSError *error) {
        __strong typeof(weakSelf) self = weakSelf;
        if (!self) return;
        self.checkUpdatesButton.enabled = YES;
        self.checkUpdatesButton.title = [self.language text:@"check_updates"];
        if ([error.domain isEqualToString:@"com.gloryhuis.OpenGuard.Update"] && error.code == 404) {
            NSAlert *alert = [[NSAlert alloc] init];
            alert.alertStyle = NSAlertStyleInformational;
            alert.messageText = [self.language text:@"no_release_title"];
            alert.informativeText = [self.language text:@"no_release_message"];
            [alert addButtonWithTitle:[self.language text:@"ok"]];
            [alert beginSheetModalForWindow:self.window completionHandler:nil];
        } else if (error) {
            [self showError:[self.language text:@"update_check_failed"]];
        } else if (version.length && releaseURL) {
            [self presentUpdateVersion:version releaseURL:releaseURL];
        } else {
            NSAlert *alert = [[NSAlert alloc] init];
            alert.alertStyle = NSAlertStyleInformational;
            alert.messageText = [self.language text:@"up_to_date_title"];
            alert.informativeText = [self.language text:@"up_to_date_message"];
            [alert addButtonWithTitle:[self.language text:@"ok"]];
            [alert beginSheetModalForWindow:self.window completionHandler:nil];
        }
    }];
}

- (void)presentUpdateVersion:(NSString *)version releaseURL:(NSURL *)releaseURL {
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

- (void)updateChecker:(OGUpdateChecker *)checker
 didFindNewVersion:(NSString *)version
          releaseURL:(NSURL *)releaseURL {
    [self presentUpdateVersion:version releaseURL:releaseURL];
}

@end
