#import "OGRuleStore.h"
#import <AppKit/AppKit.h>

NSString * const OGRuleExtensionKey = @"extension";
NSString * const OGRuleBundleIdentifierKey = @"bundleIdentifier";
NSString * const OGRuleApplicationNameKey = @"applicationName";
NSString * const OGRuleApplicationPathKey = @"applicationPath";

static NSString * const OGRulesDefaultsKey = @"rules.v1";
static NSString * const OGMonitoringDefaultsKey = @"monitoringEnabled";

@implementation OGRuleStore

- (instancetype)init {
    self = [super init];
    if (!self) return nil;
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSArray *saved = [defaults arrayForKey:OGRulesDefaultsKey];
    _rules = saved ?: [self initialRules];
    _monitoringEnabled = [defaults objectForKey:OGMonitoringDefaultsKey]
        ? [defaults boolForKey:OGMonitoringDefaultsKey] : YES;
    return self;
}

- (NSArray<NSDictionary *> *)initialRules {
    NSString *path = [[NSWorkspace sharedWorkspace] absolutePathForAppBundleWithIdentifier:@"com.microsoft.VSCode"];
    if (!path) return @[];
    return @[@{OGRuleExtensionKey: @"md",
               OGRuleBundleIdentifierKey: @"com.microsoft.VSCode",
               OGRuleApplicationNameKey: @"Visual Studio Code",
               OGRuleApplicationPathKey: path}];
}

- (void)save {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [defaults setObject:self.rules forKey:OGRulesDefaultsKey];
    [defaults setBool:self.monitoringEnabled forKey:OGMonitoringDefaultsKey];
}

- (void)addOrReplaceRule:(NSDictionary *)rule {
    NSMutableArray *next = [self.rules mutableCopy];
    NSString *extension = rule[OGRuleExtensionKey];
    NSIndexSet *matches = [next indexesOfObjectsPassingTest:^BOOL(NSDictionary *item, NSUInteger idx, BOOL *stop) {
        return [item[OGRuleExtensionKey] isEqualToString:extension];
    }];
    if (matches.count) [next removeObjectsAtIndexes:matches];
    [next addObject:rule];
    [next sortUsingComparator:^NSComparisonResult(NSDictionary *left, NSDictionary *right) {
        return [left[OGRuleExtensionKey] compare:right[OGRuleExtensionKey]];
    }];
    self.rules = next;
    [self save];
}

- (void)removeRuleAtIndex:(NSUInteger)index {
    if (index >= self.rules.count) return;
    NSMutableArray *next = [self.rules mutableCopy];
    [next removeObjectAtIndex:index];
    self.rules = next;
    [self save];
}

@end

