#import "OGAppDelegate.h"
#import "OGLaunchAgent.h"
#import "OGLaunchServices.h"
#import "OGRuleStore.h"
#import "OGLanguage.h"
#import "OGPresets.h"

@interface OGAppDelegate ()
@property (nonatomic, strong) OGRuleStore *store;
@property (nonatomic, strong) OGLanguage *language;
@property (nonatomic, strong) NSStatusItem *statusItem;
@property (nonatomic, strong) NSWindow *window;
@property (nonatomic, strong) NSTableView *tableView;
@property (nonatomic, strong) NSTextField *summaryLabel;
@property (nonatomic, strong) NSButton *monitoringCheckbox;
@property (nonatomic, strong) NSButton *loginCheckbox;
@property (nonatomic, strong) NSTextField *titleLabel;
@property (nonatomic, strong) NSButton *addButton;
@property (nonatomic, strong) NSButton *removeButton;
@property (nonatomic, strong) NSButton *applyButton;
@property (nonatomic, strong) NSPopUpButton *languagePopup;
@property (nonatomic, strong) NSTimer *timer;
@property (nonatomic, copy) NSArray<NSString *> *statuses;
@property (nonatomic) NSUInteger repairCount;
@property (nonatomic) BOOL agentLaunch;
@end

@implementation OGAppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)notification {
    self.agentLaunch = [[[NSProcessInfo processInfo] arguments] containsObject:@"--agent"];
    self.store = [[OGRuleStore alloc] init];
    self.language = [OGLanguage shared];
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
    self.statusItem.button.toolTip = [self.language text:@"tagline"];
    NSMenu *menu = [[NSMenu alloc] initWithTitle:@"OpenGuard"];
    [menu addItemWithTitle:[self.language text:@"menu_open"] action:@selector(showWindow:) keyEquivalent:@""];
    [menu addItemWithTitle:[self.language text:@"menu_apply"] action:@selector(applyNow:) keyEquivalent:@""];
    [menu addItem:[NSMenuItem separatorItem]];
    [menu addItemWithTitle:[self.language text:@"menu_quit"] action:@selector(terminate:) keyEquivalent:@"q"];
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
    self.titleLabel = [self labelWithText:[self.language text:@"tagline"]
                                    font:[NSFont boldSystemFontOfSize:22]];
    self.summaryLabel = [self labelWithText:[self.language text:@"checking"] font:[NSFont systemFontOfSize:13]];
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
    extensionColumn.title = [self.language text:@"extension"];
    extensionColumn.width = 110;
    NSTableColumn *applicationColumn = [[NSTableColumn alloc] initWithIdentifier:@"application"];
    applicationColumn.title = [self.language text:@"application"];
    applicationColumn.width = 300;
    NSTableColumn *statusColumn = [[NSTableColumn alloc] initWithIdentifier:@"status"];
    statusColumn.title = [self.language text:@"status"];
    statusColumn.width = 170;
    [self.tableView addTableColumn:extensionColumn];
    [self.tableView addTableColumn:applicationColumn];
    [self.tableView addTableColumn:statusColumn];
    scroll.documentView = self.tableView;

    self.addButton = [self buttonWithTitle:[self.language text:@"add_rule"] action:@selector(addRule:)];
    self.removeButton = [self buttonWithTitle:[self.language text:@"remove"] action:@selector(removeRule:)];
    self.applyButton = [self buttonWithTitle:[self.language text:@"apply_all"] action:@selector(applyNow:)];
    self.monitoringCheckbox = [NSButton checkboxWithTitle:[self.language text:@"monitor_auto"]
                                                    target:self action:@selector(toggleMonitoring:)];
    self.monitoringCheckbox.translatesAutoresizingMaskIntoConstraints = NO;
    self.monitoringCheckbox.state = self.store.monitoringEnabled ? NSControlStateValueOn : NSControlStateValueOff;
    self.loginCheckbox = [NSButton checkboxWithTitle:[self.language text:@"start_login"]
                                               target:self action:@selector(toggleLogin:)];
    self.loginCheckbox.translatesAutoresizingMaskIntoConstraints = NO;
    self.loginCheckbox.state = [OGLaunchAgent isEnabled] ? NSControlStateValueOn : NSControlStateValueOff;

    NSTextField *languageLabel = [self labelWithText:[self.language text:@"language"] font:[NSFont systemFontOfSize:12]];
    self.languagePopup = [[NSPopUpButton alloc] initWithFrame:NSZeroRect pullsDown:NO];
    self.languagePopup.translatesAutoresizingMaskIntoConstraints = NO;
    for (NSDictionary *entry in [OGLanguage supportedLanguages]) {
        [self.languagePopup addItemWithTitle:entry[@"name"]];
        self.languagePopup.lastItem.representedObject = entry[@"code"];
        if ([entry[@"code"] isEqualToString:self.language.code]) [self.languagePopup selectItem:self.languagePopup.lastItem];
    }
    self.languagePopup.target = self;
    self.languagePopup.action = @selector(changeLanguage:);

    for (NSView *view in @[self.titleLabel, self.summaryLabel, scroll, self.addButton, self.removeButton, self.applyButton,
                           self.monitoringCheckbox, self.loginCheckbox, languageLabel, self.languagePopup]) {
        [content addSubview:view];
    }
    NSDictionary *views = NSDictionaryOfVariableBindings(_titleLabel, _summaryLabel, scroll, _addButton, _removeButton, _applyButton,
                                                           _monitoringCheckbox, _loginCheckbox, languageLabel, _languagePopup);
    [content addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"H:|-24-[_titleLabel]-(>=12)-[languageLabel]-6-[_languagePopup]-24-|"
                                                                    options:0 metrics:nil views:views]];
    [content addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"H:|-24-[_summaryLabel]-24-|"
                                                                    options:0 metrics:nil views:views]];
    [content addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"H:|-24-[scroll]-24-|"
                                                                    options:0 metrics:nil views:views]];
    [content addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"H:|-24-[_addButton]-8-[_removeButton]-(>=8)-[_applyButton]-24-|"
                                                                    options:NSLayoutFormatAlignAllCenterY metrics:nil views:views]];
    [content addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"H:|-24-[_monitoringCheckbox]-(>=12)-[_loginCheckbox]-24-|"
                                                                    options:NSLayoutFormatAlignAllCenterY metrics:nil views:views]];
    [content addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"V:|-22-[_titleLabel]-4-[_summaryLabel]-14-[scroll]-14-[_addButton]-14-[_monitoringCheckbox]-20-|"
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
        BOOL healthy = [value isEqualToString:[self.language text:@"protected"]]
            || [value isEqualToString:[self.language text:@"restored"]];
        cell.textColor = healthy ? [NSColor systemGreenColor] : [NSColor secondaryLabelColor];
    }
    return cell;
}

- (void)addRule:(id)sender {
    NSAlert *alert = [[NSAlert alloc] init];
    alert.messageText = [self.language text:@"add_title"];
    alert.informativeText = [self.language text:@"add_info"];
    [alert addButtonWithTitle:[self.language text:@"choose_app"]];
    [alert addButtonWithTitle:[self.language text:@"cancel"]];
    NSPopUpButton *presetPopup = [[NSPopUpButton alloc] initWithFrame:NSMakeRect(0, 0, 320, 26) pullsDown:NO];
    for (NSDictionary *preset in [OGPresets all]) {
        [presetPopup addItemWithTitle:[NSString stringWithFormat:@".%@ — %@", preset[@"extension"], preset[@"name"]]];
        presetPopup.lastItem.representedObject = preset[@"extension"];
    }
    [presetPopup.menu addItem:[NSMenuItem separatorItem]];
    [presetPopup addItemWithTitle:[self.language text:@"custom"]];
    presetPopup.lastItem.representedObject = @"__custom__";
    alert.accessoryView = presetPopup;
    if ([alert runModal] != NSAlertFirstButtonReturn) return;
    NSString *extension = presetPopup.selectedItem.representedObject;
    if ([extension isEqualToString:@"__custom__"]) {
        NSAlert *customAlert = [[NSAlert alloc] init];
        customAlert.messageText = [self.language text:@"custom_title"];
        customAlert.informativeText = [self.language text:@"custom_info"];
        [customAlert addButtonWithTitle:[self.language text:@"choose_app"]];
        [customAlert addButtonWithTitle:[self.language text:@"cancel"]];
        NSTextField *field = [[NSTextField alloc] initWithFrame:NSMakeRect(0, 0, 280, 24)];
        field.placeholderString = @"md";
        customAlert.accessoryView = field;
        [customAlert.window setInitialFirstResponder:field];
        if ([customAlert runModal] != NSAlertFirstButtonReturn) return;
        extension = [OGLaunchServices normalizedExtension:field.stringValue];
    }
    if (!extension) {
        [self showErrorText:[self.language text:@"invalid_extension"]];
        return;
    }

    NSOpenPanel *panel = [NSOpenPanel openPanel];
    panel.title = [NSString stringWithFormat:[self.language text:@"choose_title"], extension];
    panel.prompt = [self.language text:@"choose"];
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
        [self showErrorText:[self.language text:@"invalid_app"]];
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
            [statuses addObject:[self.language text:@"protected"]];
            protectedCount++;
            continue;
        }
        if (repair) {
            NSError *error = nil;
            if ([OGLaunchServices setHandler:wanted forExtension:extension error:&error]) {
                [statuses addObject:[self.language text:@"restored"]];
                protectedCount++;
                self.repairCount++;
                NSLog(@"Restored .%@ to %@ (previous handler: %@)", extension, wanted, current ?: @"none");
            } else {
                [statuses addObject:[self.language text:@"repair_failed"]];
                NSLog(@"Failed to restore .%@: %@", extension, error);
            }
        } else {
            NSString *name = current ? [OGLaunchServices applicationNameForBundleIdentifier:current] : [self.language text:@"none"];
            [statuses addObject:[NSString stringWithFormat:[self.language text:@"changed"], name]];
        }
    }
    self.statuses = statuses;
    self.summaryLabel.stringValue = self.store.rules.count == 0
        ? [self.language text:@"no_rules"]
        : [NSString stringWithFormat:[self.language text:@"summary"],
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
        [self showErrorText:error.localizedDescription ?: [self.language text:@"login_error"]];
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

- (void)showErrorText:(NSString *)text {
    NSAlert *alert = [[NSAlert alloc] init];
    alert.alertStyle = NSAlertStyleWarning;
    alert.messageText = @"OpenGuard";
    alert.informativeText = text;
    [alert runModal];
}

@end
