#import <Cocoa/Cocoa.h>
#import "OGAppDelegate.h"
#import "OGLaunchServices.h"
#import "OGLanguage.h"
#import "OGPresets.h"
#import "OGUpdateChecker.h"

int main(int argc, const char * argv[]) {
    @autoreleasepool {
        NSArray<NSString *> *arguments = [[NSProcessInfo processInfo] arguments];
        if ([arguments containsObject:@"--verify-content"]) {
            BOOL versionComparisonWorks = [OGUpdateChecker isVersion:@"v1.10.0" newerThanVersion:@"1.9.9"] &&
                                          ![OGUpdateChecker isVersion:@"1.1.0" newerThanVersion:@"v1.1.0"];
            printf("languages=%lu\ngroups=%lu\npresets=%lu\ntranslations_complete=%s\nversion_compare=%s\n",
                   (unsigned long)[OGLanguage supportedLanguages].count,
                   (unsigned long)[OGPresets defaultGroups].count,
                   (unsigned long)[OGPresets all].count,
                   [[OGLanguage shared] hasCompleteTranslations] ? "yes" : "no",
                   versionComparisonWorks ? "yes" : "no");
            return [[OGLanguage shared] hasCompleteTranslations] && versionComparisonWorks ? 0 : 3;
        }
        NSUInteger index = [arguments indexOfObject:@"--diagnose"];
        if (index != NSNotFound && index + 1 < arguments.count) {
            NSString *extension = arguments[index + 1];
            NSString *normalized = [OGLaunchServices normalizedExtension:extension];
            NSString *uti = [OGLaunchServices typeIdentifierForExtension:extension];
            NSString *handler = [OGLaunchServices currentHandlerForExtension:extension];
            printf("extension=%s\nuti=%s\nhandler=%s\n",
                   normalized.UTF8String ?: "(invalid)", uti.UTF8String ?: "(none)", handler.UTF8String ?: "(none)");
            return normalized ? 0 : 2;
        }
        NSApplication *application = [NSApplication sharedApplication];
        OGAppDelegate *delegate = [[OGAppDelegate alloc] init];
        application.delegate = delegate;
        [application run];
    }
    return 0;
}
