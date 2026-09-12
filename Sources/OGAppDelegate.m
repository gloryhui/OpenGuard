#import "OGAppDelegate.h"
#import "OGLaunchAgent.h"
#import "OGLaunchServices.h"
#import "OGRuleStore.h"

@interface OGAppDelegate ()
@property (nonatomic, strong) OGRuleStore *store;
@property (nonatomic, strong) NSStatusItem *statusItem;
@property (nonatomic, strong) NSWindow *window;
@property (nonatomic, strong) NSTableView *tableView;
@property (nonatomic, strong) NSTextField *summaryLabel;
@property (nonatomic, strong) NSButton *monitoringCheckbox;
@property (nonatomic, strong) NSButton *loginCheckbox;
@property (nonatomic, strong) NSTimer *timer;
@property (nonatomic, copy) NSArray<NSString *> *statuses;
@property (nonatomic) NSUInteger repairCount;
@property (nonatomic) BOOL agentLaunch;
@end

@implementation OGAppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)notification {
    self.agentLaunch = [[[NSProcessInfo processInfo] arguments] containsObject:@"--agent"];
    self.store = [[OGRuleStore alloc] init];
    self.statuses = @[];
    [self buildStatusItem];
    [self buildWindow];
    [self refreshAndRepair:self.store.monitoringEnabled];
    [self restartTimer];
    if (!self.agentLaunch) [self showWindow:nil];
}

- (void)applicationWillTerminate:(NSNotification *)notification {
    [self.timer invalidate];
}

- (BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)sender {
    return NO;
}

#pragma mark - Status menu

- (void)buildStatusItem {
    self.statusItem = [[NSStatusBar systemStatusBar] statusItemWithLength:NSVariableStatusItemLength];
    self.statusItem.button.title = @"◉";
    self.statusItem.button.toolTip = @"OpenGuard — default app protection";
    NSMenu *menu = [[NSMenu alloc] initWithTitle:@"OpenGuard"];
    [menu addItemWithTitle:@"Open OpenGuard…" action:@selector(showWindow:) keyEquivalent:@""];
    [menu addItemWithTitle:@"Apply Rules Now" action:@selector(applyNow:) keyEquivalent:@""];
    [menu addItem:[NSMenuItem separatorItem]];
    [menu addItemWithTitle:@"Quit OpenGuard" action:@selector(terminate:) keyEquivalent:@"q"];
    for (NSMenuItem *item in menu.itemArray) item.target = self;
    self.statusItem.menu = menu;
}

#pragma mark - Window

- (NSTextField *)labelWithText:(NSString *)text font:(NSFont *)font {
    NSTextField *label = [NSTextField labelWithString:text];
    label.font = font;
    label.translatesAutoresizingMaskIntoConstraints = NO;
    return label;
}

- (NSButton *)buttonWithTitle:(NSString *)title action:(SEL)action {
    NSButton *button = [NSButton buttonWithTitle:title target:self action:action];
    button.translatesAutoresizingMaskIntoConstraints = NO;
    return button;
}

- (void)buildWindow {
    NSRect frame = NSMakeRect(0, 0, 640, 430);
    self.window = [[NSWindow alloc] initWithContentRect:frame
                                              styleMask:(NSWindowStyleMaskTitled |
                                                         NSWindowStyleMaskClosable |
                                                         NSWindowStyleMaskMiniaturizable)
                                                backing:NSBackingStoreBuffered defer:NO];
    self.window.title = @"OpenGuard";
    self.window.minSize = NSMakeSize(560, 360);
    [self.window center];

    NSView *content = self.window.contentView;
    NSTextField *title = [self labelWithText:@"Default apps, held in place."
                                        font:[NSFont boldSystemFontOfSize:22]];
    self.summaryLabel = [self labelWithText:@"Checking rules…" font:[NSFont systemFontOfSize:13]];
    self.summaryLabel.textColor = [NSColor secondaryLabelColor];

    NSScrollView *scroll = [[NSScrollView alloc] initWithFrame:NSZeroRect];
    scroll.translatesAutoresizingMaskIntoConstraints = NO;
    scroll.hasVerticalScroller = YES;
    scroll.borderType = NSBezelBorder;
    self.tableView = [[NSTableView alloc] initWithFrame:NSZeroRect];
    self.tableView.dataSource = self;
    self.tableView.delegate = self;
    self.tableView.headerView = [[NSTableHeaderView alloc] initWithFrame:NSZeroRect];
    self.tableView.usesAlternatingRowBackgroundColors = YES;
    self.tableView.allowsMultipleSelection = NO;
    NSTableColumn *extensionColumn = [[NSTableColumn alloc] initWithIdentifier:@"extension"];
    extensionColumn.title = @"Extension";
    extensionColumn.width = 110;
    NSTableColumn *applicationColumn = [[NSTableColumn alloc] initWithIdentifier:@"application"];
    applicationColumn.title = @"Required application";
    applicationColumn.width = 300;
    NSTableColumn *statusColumn = [[NSTableColumn alloc] initWithIdentifier:@"status"];
    statusColumn.title = @"Status";
    statusColumn.width = 170;
    [self.tableView addTableColumn:extensionColumn];
    [self.tableView addTableColumn:applicationColumn];
    [self.tableView addTableColumn:statusColumn];
    scroll.documentView = self.tableView;

    NSButton *add = [self buttonWithTitle:@"＋ Add Rule" action:@selector(addRule:)];
    NSButton *remove = [self buttonWithTitle:@"－ Remove" action:@selector(removeRule:)];
    NSButton *apply = [self buttonWithTitle:@"Apply All Now" action:@selector(applyNow:)];
    self.monitoringCheckbox = [NSButton checkboxWithTitle:@"Automatically restore changed handlers"
                                                    target:self action:@selector(toggleMonitoring:)];
    self.monitoringCheckbox.translatesAutoresizingMaskIntoConstraints = NO;
    self.monitoringCheckbox.state = self.store.monitoringEnabled ? NSControlStateValueOn : NSControlStateValueOff;
    self.loginCheckbox = [NSButton checkboxWithTitle:@"Start OpenGuard at login"
                                               target:self action:@selector(toggleLogin:)];
    self.loginCheckbox.translatesAutoresizingMaskIntoConstraints = NO;
    self.loginCheckbox.state = [OGLaunchAgent isEnabled] ? NSControlStateValueOn : NSControlStateValueOff;

    for (NSView *view in @[title, self.summaryLabel, scroll, add, remove, apply,
                           self.monitoringCheckbox, self.loginCheckbox]) {
        [content addSubview:view];
    }
    NSDictionary *views = NSDictionaryOfVariableBindings(title, _summaryLabel, scroll, add, remove, apply,
                                                           _monitoringCheckbox, _loginCheckbox);
    [content addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"H:|-24-[title]-24-|"
                                                                    options:0 metrics:nil views:views]];
    [content addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"H:|-24-[_summaryLabel]-24-|"
                                                                    options:0 metrics:nil views:views]];
    [content addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"H:|-24-[scroll]-24-|"
                                                                    options:0 metrics:nil views:views]];
    [content addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"H:|-24-[add]-8-[remove]-(>=8)-[apply]-24-|"
                                                                    options:NSLayoutFormatAlignAllCenterY metrics:nil views:views]];
    [content addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"H:|-24-[_monitoringCheckbox]-(>=12)-[_loginCheckbox]-24-|"
                                                                    options:NSLayoutFormatAlignAllCenterY metrics:nil views:views]];
    [content addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"V:|-22-[title]-4-[_summaryLabel]-14-[scroll]-14-[add]-14-[_monitoringCheckbox]-20-|"
                                                                    options:0 metrics:nil views:views]];
}

- (void)showWindow:(id)sender {
    [NSApp activateIgnoringOtherApps:YES];
    [self.window makeKeyAndOrderFront:nil];
}

#pragma mark - Rules

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView {
    return self.store.rules.count;
}

- (NSView *)tableView:(NSTableView *)tableView
   viewForTableColumn:(NSTableColumn *)tableColumn
                  row:(NSInteger)row {
    NSDictionary *rule = self.store.rules[row];
    NSString *value = @"";
    if ([tableColumn.identifier isEqualToString:@"extension"]) {
        value = [@"." stringByAppendingString:rule[OGRuleExtensionKey]];
    } else if ([tableColumn.identifier isEqualToString:@"application"]) {
        value = rule[OGRuleApplicationNameKey];
    } else if (row < (NSInteger)self.statuses.count) {
        value = self.statuses[row];
    }
    NSTextField *cell = [tableView makeViewWithIdentifier:tableColumn.identifier owner:self];
    if (!cell) {
        cell = [NSTextField labelWithString:@""];
        cell.identifier = tableColumn.identifier;
        cell.lineBreakMode = NSLineBreakByTruncatingTail;
    }
    cell.stringValue = value ?: @"";
    if ([tableColumn.identifier isEqualToString:@"status"]) {
        cell.textColor = [value hasPrefix:@"Protected"] ? [NSColor systemGreenColor] : [NSColor secondaryLabelColor];
    }
    return cell;
}

- (void)addRule:(id)sender {
    NSAlert *alert = [[NSAlert alloc] init];
    alert.messageText = @"Add a filename extension";
    alert.informativeText = @"Enter an extension, with or without the leading dot.";
    [alert addButtonWithTitle:@"Choose Application…"];
    [alert addButtonWithTitle:@"Cancel"];
    NSTextField *field = [[NSTextField alloc] initWithFrame:NSMakeRect(0, 0, 280, 24)];
    field.placeholderString = @"md";
    alert.accessoryView = field;
    [alert.window setInitialFirstResponder:field];
    if ([alert runModal] != NSAlertFirstButtonReturn) return;
    NSString *extension = [OGLaunchServices normalizedExtension:field.stringValue];
    if (!extension) {
        [self showErrorText:@"Please enter a valid extension using letters or numbers only."];
        return;
    }

    NSOpenPanel *panel = [NSOpenPanel openPanel];
    panel.title = [NSString stringWithFormat:@"Choose the application for .%@ files", extension];
    panel.prompt = @"Choose";
    panel.directoryURL = [NSURL fileURLWithPath:@"/Applications" isDirectory:YES];
    panel.canChooseFiles = YES;
    panel.canChooseDirectories = NO;
    panel.allowsMultipleSelection = NO;
    panel.allowedFileTypes = @[@"app"];
    if ([panel runModal] != NSModalResponseOK) return;
    NSURL *url = panel.URL;
    NSBundle *bundle = [NSBundle bundleWithURL:url];
    NSString *bundleID = bundle.bundleIdentifier;
    if (!bundleID) {
        [self showErrorText:@"The selected item is not a valid macOS application."];
        return;
    }
    NSString *name = [bundle objectForInfoDictionaryKey:@"CFBundleDisplayName"]
        ?: [bundle objectForInfoDictionaryKey:@"CFBundleName"]
        ?: [[url lastPathComponent] stringByDeletingPathExtension];
    [self.store addOrReplaceRule:@{OGRuleExtensionKey: extension,
                                   OGRuleBundleIdentifierKey: bundleID,
                                   OGRuleApplicationNameKey: name,
                                   OGRuleApplicationPathKey: url.path}];
    [self refreshAndRepair:YES];
}

- (void)removeRule:(id)sender {
    NSInteger row = self.tableView.selectedRow;
    if (row < 0) {
        NSBeep();
        return;
    }
    [self.store removeRuleAtIndex:(NSUInteger)row];
    [self refreshAndRepair:NO];
}

- (void)applyNow:(id)sender {
    [self refreshAndRepair:YES];
}

- (void)refreshAndRepair:(BOOL)repair {
    NSMutableArray<NSString *> *statuses = [NSMutableArray array];
    NSUInteger protectedCount = 0;
    for (NSDictionary *rule in self.store.rules) {
        NSString *extension = rule[OGRuleExtensionKey];
        NSString *wanted = rule[OGRuleBundleIdentifierKey];
        NSString *current = [OGLaunchServices currentHandlerForExtension:extension];
        if ([current isEqualToString:wanted]) {
            [statuses addObject:@"Protected ✓"];
            protectedCount++;
            continue;
        }
        if (repair) {
            NSError *error = nil;
            if ([OGLaunchServices setHandler:wanted forExtension:extension error:&error]) {
                [statuses addObject:@"Restored ✓"];
                protectedCount++;
                self.repairCount++;
                NSLog(@"Restored .%@ to %@ (previous handler: %@)", extension, wanted, current ?: @"none");
            } else {
                [statuses addObject:@"Repair failed"];
                NSLog(@"Failed to restore .%@: %@", extension, error);
            }
        } else {
            NSString *name = current ? [OGLaunchServices applicationNameForBundleIdentifier:current] : @"None";
            [statuses addObject:[NSString stringWithFormat:@"Changed: %@", name]];
        }
    }
    self.statuses = statuses;
    self.summaryLabel.stringValue = self.store.rules.count == 0
        ? @"No rules yet. Add one to start protecting a file type."
        : [NSString stringWithFormat:@"%lu of %lu rules protected · %lu automatic restorations this run",
           (unsigned long)protectedCount, (unsigned long)self.store.rules.count,
           (unsigned long)self.repairCount];
    self.statusItem.button.title = protectedCount == self.store.rules.count ? @"◉" : @"!";
    [self.tableView reloadData];
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
    self.timer = [NSTimer scheduledTimerWithTimeInterval:10.0 target:self
                                                selector:@selector(timerFired:)
                                                userInfo:nil repeats:YES];
    self.timer.tolerance = 2.0;
}

- (void)timerFired:(NSTimer *)timer {
    [self refreshAndRepair:YES];
}

- (void)toggleLogin:(NSButton *)sender {
    BOOL enabled = sender.state == NSControlStateValueOn;
    NSError *error = nil;
    if (![OGLaunchAgent setEnabled:enabled error:&error]) {
        sender.state = enabled ? NSControlStateValueOff : NSControlStateValueOn;
        [self showErrorText:error.localizedDescription ?: @"Unable to update the login item."];
    }
}

- (void)showErrorText:(NSString *)text {
    NSAlert *alert = [[NSAlert alloc] init];
    alert.alertStyle = NSAlertStyleWarning;
    alert.messageText = @"OpenGuard";
    alert.informativeText = text;
    [alert runModal];
}

@end

