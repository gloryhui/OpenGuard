#import "OGApplicationPicker.h"
#import "OGLanguage.h"
#import "OGRuleStore.h"

static NSString * const OGApplicationAliasesKey = @"searchAliases";

@interface OGApplicationPicker ()
@property OGLanguage *language;
@property NSPanel *panel;
@property NSSearchField *searchField;
@property NSTableView *tableView;
@property NSTextField *countLabel;
@property NSButton *chooseButton;
@property NSArray<NSDictionary *> *applications;
@property NSArray<NSDictionary *> *filteredApplications;
@property NSDictionary *selectedApplication;
@end

@implementation OGApplicationPicker

- (instancetype)initWithLanguage:(OGLanguage *)language {
    self = [super init];
    if (!self) return nil;
    _language = language;
    _applications = [self discoverApplications];
    _filteredApplications = _applications;
    [self buildPanel];
    return self;
}

- (void)buildPanel {
    self.panel = [[NSPanel alloc] initWithContentRect:NSMakeRect(0, 0, 760, 500)
                                            styleMask:(NSWindowStyleMaskTitled | NSWindowStyleMaskClosable)
                                              backing:NSBackingStoreBuffered
                                                defer:NO];
    self.panel.delegate = self;
    self.panel.releasedWhenClosed = NO;
    self.panel.minSize = NSMakeSize(620, 400);

    NSView *content = self.panel.contentView;
    self.searchField = [[NSSearchField alloc] initWithFrame:NSZeroRect];
    self.searchField.translatesAutoresizingMaskIntoConstraints = NO;
    self.searchField.placeholderString = [self.language text:@"picker_search"];
    self.searchField.delegate = self;

    NSScrollView *scroll = [[NSScrollView alloc] initWithFrame:NSZeroRect];
    scroll.translatesAutoresizingMaskIntoConstraints = NO;
    scroll.hasVerticalScroller = YES;
    scroll.borderType = NSBezelBorder;

    self.tableView = [[NSTableView alloc] initWithFrame:NSZeroRect];
    self.tableView.dataSource = self;
    self.tableView.delegate = self;
    self.tableView.rowHeight = 36;
    self.tableView.usesAlternatingRowBackgroundColors = YES;
    self.tableView.allowsMultipleSelection = NO;
    self.tableView.doubleAction = @selector(confirmSelection:);
    self.tableView.target = self;

    NSTableColumn *nameColumn = [[NSTableColumn alloc] initWithIdentifier:@"name"];
    nameColumn.title = [self.language text:@"picker_application"];
    nameColumn.width = 220;
    NSTableColumn *bundleColumn = [[NSTableColumn alloc] initWithIdentifier:@"bundle"];
    bundleColumn.title = [self.language text:@"picker_bundle"];
    bundleColumn.width = 220;
    NSTableColumn *pathColumn = [[NSTableColumn alloc] initWithIdentifier:@"path"];
    pathColumn.title = [self.language text:@"picker_location"];
    pathColumn.width = 280;
    [self.tableView addTableColumn:nameColumn];
    [self.tableView addTableColumn:bundleColumn];
    [self.tableView addTableColumn:pathColumn];
    scroll.documentView = self.tableView;

    self.countLabel = [NSTextField labelWithString:@""];
    self.countLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.countLabel.textColor = [NSColor secondaryLabelColor];

    NSButton *cancelButton = [NSButton buttonWithTitle:[self.language text:@"picker_cancel"]
                                                target:self action:@selector(cancelSelection:)];
    cancelButton.translatesAutoresizingMaskIntoConstraints = NO;
    cancelButton.keyEquivalent = @"\e";
    self.chooseButton = [NSButton buttonWithTitle:[self.language text:@"choose"]
                                            target:self action:@selector(confirmSelection:)];
    self.chooseButton.translatesAutoresizingMaskIntoConstraints = NO;
    self.chooseButton.keyEquivalent = @"\r";
    self.chooseButton.enabled = NO;

    for (NSView *view in @[self.searchField, scroll, self.countLabel, cancelButton, self.chooseButton]) {
        [content addSubview:view];
    }
    NSDictionary *views = NSDictionaryOfVariableBindings(_searchField, scroll, _countLabel,
                                                           cancelButton, _chooseButton);
    [content addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"H:|-20-[_searchField]-20-|"
                                                                    options:0 metrics:nil views:views]];
    [content addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"H:|-20-[scroll]-20-|"
                                                                    options:0 metrics:nil views:views]];
    [content addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"H:|-20-[_countLabel]-(>=12)-[cancelButton]-8-[_chooseButton]-20-|"
                                                                    options:NSLayoutFormatAlignAllCenterY metrics:nil views:views]];
    [content addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"V:|-20-[_searchField(28)]-12-[scroll]-14-[_chooseButton]-16-|"
                                                                    options:0 metrics:nil views:views]];
    [self updateCountLabel];
}

- (NSDictionary *)runWithTitle:(NSString *)title
       currentBundleIdentifier:(NSString *)bundleIdentifier {
    self.panel.title = title;
    self.selectedApplication = nil;
    self.searchField.stringValue = @"";
    self.filteredApplications = self.applications;
    [self.tableView reloadData];
    [self.tableView deselectAll:nil];
    if (bundleIdentifier.length) {
        NSUInteger row = [self.filteredApplications indexOfObjectPassingTest:
                          ^BOOL(NSDictionary *application, NSUInteger index, BOOL *stop) {
            return [application[OGRuleBundleIdentifierKey] isEqualToString:bundleIdentifier];
        }];
        if (row != NSNotFound) {
            [self.tableView selectRowIndexes:[NSIndexSet indexSetWithIndex:row] byExtendingSelection:NO];
            [self.tableView scrollRowToVisible:row];
        }
    }
    [self updateCountLabel];
    [self.panel center];
    [self.panel makeFirstResponder:self.searchField];
    NSModalResponse response = [NSApp runModalForWindow:self.panel];
    [self.panel orderOut:nil];
    return response == NSModalResponseOK ? self.selectedApplication : nil;
}

- (NSArray<NSDictionary *> *)discoverApplications {
    NSFileManager *manager = [NSFileManager defaultManager];
    NSString *homeApplications = [NSHomeDirectory() stringByAppendingPathComponent:@"Applications"];
    NSArray<NSString *> *roots = @[@"/Applications", homeApplications, @"/System/Applications",
                                    @"/System/Library/CoreServices/Applications"];
    NSMutableArray<NSDictionary *> *applications = [NSMutableArray array];
    NSMutableSet<NSString *> *seenPaths = [NSMutableSet set];
    for (NSString *root in roots) {
        BOOL isDirectory = NO;
        if (![manager fileExistsAtPath:root isDirectory:&isDirectory] || !isDirectory) continue;
        NSDirectoryEnumerator *enumerator = [manager enumeratorAtURL:[NSURL fileURLWithPath:root isDirectory:YES]
                                          includingPropertiesForKeys:nil
                                                             options:(NSDirectoryEnumerationSkipsHiddenFiles |
                                                                      NSDirectoryEnumerationSkipsPackageDescendants)
                                                        errorHandler:^BOOL(NSURL *url, NSError *error) {
            NSLog(@"Unable to inspect %@: %@", url.path, error);
            return YES;
        }];
        for (NSURL *url in enumerator) {
            if (![[url.pathExtension lowercaseString] isEqualToString:@"app"]) continue;
            NSString *path = [url.path stringByStandardizingPath];
            if ([seenPaths containsObject:path]) continue;
            NSBundle *bundle = [NSBundle bundleWithURL:url];
            NSString *bundleIdentifier = bundle.bundleIdentifier;
            if (!bundleIdentifier.length) continue;
            NSString *name = [bundle objectForInfoDictionaryKey:@"CFBundleDisplayName"]
                ?: [bundle objectForInfoDictionaryKey:@"CFBundleName"]
                ?: [url.lastPathComponent stringByDeletingPathExtension];
            NSDictionary<NSString *, NSString *> *localizedNames = [self localizedNamesForBundle:bundle];
            NSString *displayName = localizedNames[self.language.code] ?: name;
            NSMutableOrderedSet<NSString *> *aliases = [NSMutableOrderedSet orderedSetWithObject:name];
            [aliases addObject:[url.lastPathComponent stringByDeletingPathExtension]];
            [aliases addObjectsFromArray:localizedNames.allValues];
            [seenPaths addObject:path];
            [applications addObject:@{OGRuleBundleIdentifierKey: bundleIdentifier,
                                      OGRuleApplicationNameKey: displayName,
                                      OGRuleApplicationPathKey: path,
                                      OGApplicationAliasesKey: aliases.array}];
        }
    }
    return [applications sortedArrayUsingComparator:^NSComparisonResult(NSDictionary *left, NSDictionary *right) {
        NSComparisonResult nameResult = [left[OGRuleApplicationNameKey]
                                         localizedStandardCompare:right[OGRuleApplicationNameKey]];
        if (nameResult != NSOrderedSame) return nameResult;
        return [left[OGRuleApplicationPathKey] localizedStandardCompare:right[OGRuleApplicationPathKey]];
    }];
}

- (NSDictionary<NSString *, NSString *> *)localizedNamesForBundle:(NSBundle *)bundle {
    NSDictionary<NSString *, NSArray<NSString *> *> *localizations = @{
        @"en": @[@"en"],
        @"zh-Hans": @[@"zh_CN", @"zh-Hans", @"zh_Hans", @"zh"],
        @"ja": @[@"ja"],
        @"ko": @[@"ko"],
        @"es": @[@"es", @"es_419"]
    };
    NSString *resourcesPath = bundle.resourcePath;
    NSDictionary *localizationTable = [NSDictionary dictionaryWithContentsOfFile:
                                        [resourcesPath stringByAppendingPathComponent:@"InfoPlist.loctable"]];
    NSMutableDictionary<NSString *, NSString *> *names = [NSMutableDictionary dictionary];
    for (NSString *languageCode in localizations) {
        for (NSString *localization in localizations[languageCode]) {
            NSDictionary *values = [localizationTable[localization] isKindOfClass:[NSDictionary class]]
                ? localizationTable[localization] : nil;
            if (!values) {
                NSString *path = [resourcesPath stringByAppendingPathComponent:
                                  [NSString stringWithFormat:@"%@.lproj/InfoPlist.strings", localization]];
                values = [NSDictionary dictionaryWithContentsOfFile:path];
            }
            NSString *name = [values[@"CFBundleDisplayName"] isKindOfClass:[NSString class]]
                ? values[@"CFBundleDisplayName"] : nil;
            if (!name && [values[@"CFBundleName"] isKindOfClass:[NSString class]]) {
                name = values[@"CFBundleName"];
            }
            if (name.length) {
                names[languageCode] = name;
                break;
            }
        }
    }
    return names;
}

- (void)filterApplications:(id)sender {
    NSString *query = [self.searchField.stringValue
                       stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (!query.length) {
        self.filteredApplications = self.applications;
    } else {
        NSStringCompareOptions options = NSCaseInsensitiveSearch | NSDiacriticInsensitiveSearch;
        self.filteredApplications = [self.applications filteredArrayUsingPredicate:
                                     [NSPredicate predicateWithBlock:^BOOL(NSDictionary *application,
                                                                           NSDictionary *bindings) {
            for (NSString *key in @[OGRuleApplicationNameKey, OGRuleBundleIdentifierKey,
                                    OGRuleApplicationPathKey]) {
                if ([application[key] rangeOfString:query options:options].location != NSNotFound) return YES;
            }
            for (NSString *alias in application[OGApplicationAliasesKey]) {
                if ([alias rangeOfString:query options:options].location != NSNotFound) return YES;
            }
            return NO;
        }]];
    }
    [self.tableView reloadData];
    [self.tableView deselectAll:nil];
    if (self.filteredApplications.count) {
        [self.tableView selectRowIndexes:[NSIndexSet indexSetWithIndex:0] byExtendingSelection:NO];
        [self.tableView scrollRowToVisible:0];
    } else {
        self.chooseButton.enabled = NO;
    }
    [self updateCountLabel];
}

- (void)controlTextDidChange:(NSNotification *)notification {
    if (notification.object == self.searchField) [self filterApplications:self.searchField];
}

- (BOOL)control:(NSControl *)control
       textView:(NSTextView *)textView
doCommandBySelector:(SEL)commandSelector {
    if (control != self.searchField) return NO;
    if (commandSelector == @selector(insertNewline:)) {
        [self confirmSelection:nil];
        return YES;
    }
    if (commandSelector == @selector(cancelOperation:)) {
        [self cancelSelection:nil];
        return YES;
    }
    return NO;
}

- (void)updateCountLabel {
    self.countLabel.stringValue = [NSString stringWithFormat:[self.language text:@"picker_count"],
                                   (unsigned long)self.filteredApplications.count];
}

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView {
    return self.filteredApplications.count;
}

- (NSView *)tableView:(NSTableView *)tableView
   viewForTableColumn:(NSTableColumn *)column
                  row:(NSInteger)row {
    NSDictionary *application = self.filteredApplications[row];
    if ([column.identifier isEqualToString:@"name"]) {
        NSView *container = [[NSView alloc] initWithFrame:NSMakeRect(0, 0, column.width, 36)];
        NSImageView *icon = [[NSImageView alloc] initWithFrame:NSZeroRect];
        icon.translatesAutoresizingMaskIntoConstraints = NO;
        icon.image = [[NSWorkspace sharedWorkspace] iconForFile:application[OGRuleApplicationPathKey]];
        icon.imageScaling = NSImageScaleProportionallyUpOrDown;
        NSTextField *label = [NSTextField labelWithString:application[OGRuleApplicationNameKey]];
        label.translatesAutoresizingMaskIntoConstraints = NO;
        label.lineBreakMode = NSLineBreakByTruncatingTail;
        [container addSubview:icon];
        [container addSubview:label];
        NSDictionary *views = NSDictionaryOfVariableBindings(icon, label);
        [container addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"H:|-6-[icon(24)]-8-[label]-6-|"
                                                                        options:NSLayoutFormatAlignAllCenterY
                                                                        metrics:nil views:views]];
        [container addConstraint:[NSLayoutConstraint constraintWithItem:icon attribute:NSLayoutAttributeHeight
                                                               relatedBy:NSLayoutRelationEqual toItem:nil
                                                               attribute:NSLayoutAttributeNotAnAttribute multiplier:1 constant:24]];
        [container addConstraint:[NSLayoutConstraint constraintWithItem:icon attribute:NSLayoutAttributeCenterY
                                                               relatedBy:NSLayoutRelationEqual toItem:container
                                                               attribute:NSLayoutAttributeCenterY multiplier:1 constant:0]];
        return container;
    }
    NSString *value = [column.identifier isEqualToString:@"bundle"]
        ? application[OGRuleBundleIdentifierKey]
        : [application[OGRuleApplicationPathKey] stringByAbbreviatingWithTildeInPath];
    NSTextField *label = [NSTextField labelWithString:value];
    label.lineBreakMode = NSLineBreakByTruncatingMiddle;
    label.toolTip = value;
    return label;
}

- (void)tableViewSelectionDidChange:(NSNotification *)notification {
    self.chooseButton.enabled = self.tableView.selectedRow >= 0;
}

- (void)confirmSelection:(id)sender {
    NSInteger row = self.tableView.selectedRow;
    if (row < 0 || row >= (NSInteger)self.filteredApplications.count) return;
    self.selectedApplication = self.filteredApplications[row];
    [NSApp stopModalWithCode:NSModalResponseOK];
}

- (void)cancelSelection:(id)sender {
    [NSApp stopModalWithCode:NSModalResponseCancel];
}

- (BOOL)windowShouldClose:(NSWindow *)sender {
    [self cancelSelection:nil];
    return NO;
}

@end
