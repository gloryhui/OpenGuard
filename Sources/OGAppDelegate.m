#import "OGAppDelegate.h"
#import "OGApplicationPicker.h"
#import "OGLaunchAgent.h"
#import "OGLaunchServices.h"
#import "OGRuleStore.h"
#import "OGLanguage.h"

static const NSTimeInterval OGMonitoringInterval = 3.0;
static NSString * const OGOutlinePasteboardType = @"com.gloryhuis.OpenGuard.outline-item";

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
@property NSView *ruleEditor;
@property NSLayoutConstraint *ruleEditorHeightConstraint;
@property NSTextField *ruleExtensionField;
@property NSTextField *ruleNameField;
@property NSTextField *ruleDestinationLabel;
@property (copy, nullable) NSString *pendingRuleGroupIdentifier;
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
    self.window = [[NSWindow alloc] initWithContentRect:NSMakeRect(0, 0, 940, 620)
                                              styleMask:(NSWindowStyleMaskTitled | NSWindowStyleMaskClosable |
                                                         NSWindowStyleMaskMiniaturizable | NSWindowStyleMaskResizable)
                                                backing:NSBackingStoreBuffered defer:NO];
    self.window.title = @"OpenGuard";
    self.window.minSize = NSMakeSize(800, 520);
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
    self.outlineView = [[NSOutlineView alloc] initWithFrame:NSZeroRect];
    self.outlineView.dataSource = self;
    self.outlineView.delegate = self;
    self.outlineView.headerView = [[NSTableHeaderView alloc] initWithFrame:NSMakeRect(0, 0, 100, 25)];
    self.outlineView.usesAlternatingRowBackgroundColors = YES;
    self.outlineView.allowsMultipleSelection = NO;
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
    [self.outlineView addTableColumn:applicationColumn];
    [self.outlineView addTableColumn:statusColumn];
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

    self.ruleEditor = [[NSView alloc] initWithFrame:NSZeroRect];
    self.ruleEditor.translatesAutoresizingMaskIntoConstraints = NO;
    self.ruleEditor.hidden = YES;
    self.ruleDestinationLabel = [self label:@"" font:[NSFont systemFontOfSize:12]];
    self.ruleDestinationLabel.textColor = [NSColor secondaryLabelColor];
    self.ruleExtensionField = [[NSTextField alloc] initWithFrame:NSZeroRect];
    self.ruleExtensionField.translatesAutoresizingMaskIntoConstraints = NO;
    self.ruleExtensionField.placeholderString = [self.language text:@"rule_extension_placeholder"];
    self.ruleNameField = [[NSTextField alloc] initWithFrame:NSZeroRect];
    self.ruleNameField.translatesAutoresizingMaskIntoConstraints = NO;
    self.ruleNameField.placeholderString = [self.language text:@"rule_name_placeholder"];
    self.ruleNameField.target = self;
    self.ruleNameField.action = @selector(confirmAddRule:);
    NSButton *cancelRule = [self button:[self.language text:@"cancel"] action:@selector(cancelAddRule:)];
    NSButton *confirmRule = [self button:[self.language text:@"add"] action:@selector(confirmAddRule:)];
    for (NSView *view in @[self.ruleDestinationLabel, self.ruleExtensionField, self.ruleNameField,
                           cancelRule, confirmRule]) [self.ruleEditor addSubview:view];
    NSDictionary *editorViews = NSDictionaryOfVariableBindings(_ruleDestinationLabel, _ruleExtensionField,
                                                                 _ruleNameField, cancelRule, confirmRule);
    [self.ruleEditor addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:
                                     @"H:|[_ruleDestinationLabel(>=130)]-12-[_ruleExtensionField(100)]-8-[_ruleNameField(180)]-(>=8)-[cancelRule]-8-[confirmRule]|"
                                                                            options:NSLayoutFormatAlignAllCenterY
                                                                            metrics:nil views:editorViews]];
    [self.ruleEditor addConstraint:[NSLayoutConstraint constraintWithItem:self.ruleExtensionField
                                                                 attribute:NSLayoutAttributeCenterY
                                                                 relatedBy:NSLayoutRelationEqual toItem:self.ruleEditor
                                                                 attribute:NSLayoutAttributeCenterY multiplier:1 constant:0]];

    NSButton *apply = [self button:[self.language text:@"apply_all"] action:@selector(applyNow:)];
    self.monitoringCheckbox = [NSButton checkboxWithTitle:[self.language text:@"monitor_auto"] target:self
                                                    action:@selector(toggleMonitoring:)];
    self.monitoringCheckbox.translatesAutoresizingMaskIntoConstraints = NO;
    self.monitoringCheckbox.state = self.store.monitoringEnabled ? NSControlStateValueOn : NSControlStateValueOff;
    self.loginCheckbox = [NSButton checkboxWithTitle:[self.language text:@"start_login"] target:self
                                               action:@selector(toggleLogin:)];
    self.loginCheckbox.translatesAutoresizingMaskIntoConstraints = NO;
    self.loginCheckbox.state = [OGLaunchAgent isEnabled] ? NSControlStateValueOn : NSControlStateValueOff;

    for (NSView *view in @[title, toolbar, self.summaryLabel, self.ruleEditor, languageLabel, languagePopup,
                           scroll, apply, self.monitoringCheckbox, self.loginCheckbox]) [content addSubview:view];
    self.ruleEditorHeightConstraint = [NSLayoutConstraint constraintWithItem:self.ruleEditor
                                                                    attribute:NSLayoutAttributeHeight
                                                                    relatedBy:NSLayoutRelationEqual toItem:nil
                                                                    attribute:NSLayoutAttributeNotAnAttribute
                                                                   multiplier:1 constant:0];
    [self.ruleEditor addConstraint:self.ruleEditorHeightConstraint];
    NSDictionary *views = NSDictionaryOfVariableBindings(title, toolbar, _summaryLabel, _ruleEditor,
                                                           languageLabel, languagePopup, scroll, apply,
                                                           _monitoringCheckbox, _loginCheckbox);
    [content addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"H:|-24-[title]-(>=20)-[languageLabel]-6-[languagePopup]-24-|"
                                                                    options:NSLayoutFormatAlignAllCenterY metrics:nil views:views]];
    [content addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"H:|-24-[_summaryLabel]-24-|"
                                                                    options:0 metrics:nil views:views]];
    [content addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"H:|-24-[toolbar]-24-|"
                                                                    options:0 metrics:nil views:views]];
    [content addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"H:|-24-[_ruleEditor]-24-|"
                                                                    options:0 metrics:nil views:views]];
    [content addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"H:|-24-[scroll]-24-|"
                                                                    options:0 metrics:nil views:views]];
    [content addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"H:|-24-[_monitoringCheckbox]-(>=12)-[apply]-24-|"
                                                                    options:NSLayoutFormatAlignAllCenterY metrics:nil views:views]];
    [content addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"H:|-24-[_loginCheckbox]-24-|"
                                                                    options:0 metrics:nil views:views]];
    [content addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"V:|-18-[title]-10-[toolbar(30)]-6-[_summaryLabel]-8-[_ruleEditor]-8-[scroll]-12-[_monitoringCheckbox]-6-[_loginCheckbox]-16-|"
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
    if ([column.identifier isEqualToString:@"application"]) return [self applicationCellForItem:item group:group];
    NSTextField *cell = [NSTextField labelWithString:@""];
    cell.lineBreakMode = NSLineBreakByTruncatingTail;
    if ([column.identifier isEqualToString:@"filetype"]) {
        cell.stringValue = group ? [self titleForGroup:item]
                                 : [NSString stringWithFormat:@".%@  —  %@", item[OGRuleExtensionKey], item[OGRuleNameKey]];
        if (group) {
            cell.font = [NSFont boldSystemFontOfSize:13];
            cell.editable = YES;
            cell.selectable = YES;
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
    NSArray<NSDictionary *> *items = group[OGGroupItemsKey] ?: @[];
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
        return item == nil && index >= 0 ? NSDragOperationMove : NSDragOperationNone;
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
    NSInteger row = [self contextRow];
    NSDictionary *group = [self contextGroup];
    if (group && row >= 0) {
        [self.outlineView selectRowIndexes:[NSIndexSet indexSetWithIndex:(NSUInteger)row]
                     byExtendingSelection:NO];
    }
    for (NSMenuItem *item in menu.itemArray) item.enabled = group != nil;
}

- (void)addGroup:(id)sender {
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
            [self.window makeFirstResponder:self.outlineView];
            [self.outlineView editColumn:0 row:row withEvent:nil select:YES];
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
        [self.window makeFirstResponder:self.outlineView];
        [self.outlineView editColumn:0 row:row withEvent:nil select:YES];
    });
}

- (void)controlTextDidEndEditing:(NSNotification *)notification {
    NSTextField *field = notification.object;
    if (![field.identifier isEqualToString:@"groupTitle"]) return;
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

- (void)showRuleEditor:(id)sender {
    NSInteger row = self.outlineView.selectedRow;
    NSDictionary *selectedItem = row >= 0 ? [self.outlineView itemAtRow:row] : nil;
    NSDictionary *group = [self isGroup:selectedItem] ? selectedItem
        : (selectedItem ? [self.outlineView parentForItem:selectedItem] : nil);
    self.pendingRuleGroupIdentifier = group[OGGroupIdentifierKey];
    NSString *destination = group ? [self titleForGroup:group] : [self.language text:@"ungrouped"];
    self.ruleDestinationLabel.stringValue = [NSString stringWithFormat:
                                              [self.language text:@"add_rule_destination"], destination];
    self.ruleExtensionField.stringValue = @"";
    self.ruleNameField.stringValue = @"";
    self.ruleEditor.hidden = NO;
    self.ruleEditorHeightConstraint.constant = 34;
    [self.window.contentView layoutSubtreeIfNeeded];
    [self.window makeFirstResponder:self.ruleExtensionField];
}

- (void)cancelAddRule:(id)sender {
    self.ruleEditor.hidden = YES;
    self.ruleEditorHeightConstraint.constant = 0;
    self.pendingRuleGroupIdentifier = nil;
}

- (void)confirmAddRule:(id)sender {
    NSString *extension = [[self.ruleExtensionField.stringValue
                            stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]]
                           lowercaseString];
    while ([extension hasPrefix:@"."]) extension = [extension substringFromIndex:1];
    NSCharacterSet *invalidCharacters = [NSCharacterSet characterSetWithCharactersInString:@"./:\\"];
    if (!extension.length || extension.length > 32 ||
        [extension rangeOfCharacterFromSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]].location != NSNotFound ||
        [extension rangeOfCharacterFromSet:invalidCharacters].location != NSNotFound) {
        [self showError:[self.language text:@"invalid_extension"]];
        return;
    }
    if ([self.store containsRuleWithExtension:extension]) {
        [self showError:[NSString stringWithFormat:[self.language text:@"duplicate_rule"], extension]];
        return;
    }
    NSSet<NSString *> *expanded = [self expandedGroupIdentifiers];
    if (self.pendingRuleGroupIdentifier) {
        expanded = [expanded setByAddingObject:self.pendingRuleGroupIdentifier];
    }
    if (![self.store addRuleWithExtension:extension name:self.ruleNameField.stringValue
                                  toGroup:self.pendingRuleGroupIdentifier]) return;
    [self cancelAddRule:nil];
    [self reloadOutlineWithExpandedGroupIdentifiers:expanded];
    [self refreshAndRepair:NO];
}

- (void)chooseApplication:(NSButton *)sender {
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
        [self.store setApplication:application forExtension:item[OGRuleExtensionKey]
                                                   inGroup:parent[OGGroupIdentifierKey]];
    }
    [self reloadOutlineWithExpandedGroupIdentifiers:expandedGroups];
    [self refreshAndRepair:YES];
}

- (void)deleteGroup:(id)sender {
    NSInteger row = [sender isKindOfClass:[NSMenuItem class]] ? [self contextRow] : self.outlineView.selectedRow;
    NSDictionary *candidate = row >= 0 ? [self.outlineView itemAtRow:row] : nil;
    NSDictionary *group = [self isGroup:candidate] ? candidate : nil;
    if (!group || ![self isGroup:group]) return;
    NSSet<NSString *> *expanded = [self expandedGroupIdentifiers];
    [self.store removeGroup:group[OGGroupIdentifierKey]];
    [self reloadOutlineWithExpandedGroupIdentifiers:expanded];
    self.removeGroupButton.enabled = NO;
    [self refreshAndRepair:NO];
}

- (void)restoreGroups:(id)sender {
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
