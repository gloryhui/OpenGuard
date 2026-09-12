#import "OGLaunchServices.h"
#import <AppKit/AppKit.h>
#import <CoreServices/CoreServices.h>

static NSString * const OGLaunchServicesErrorDomain = @"com.gloryhuis.OpenGuard.LaunchServices";

@implementation OGLaunchServices

+ (NSString *)normalizedExtension:(NSString *)extension {
    NSString *value = [[extension stringByTrimmingCharactersInSet:
                        [NSCharacterSet whitespaceAndNewlineCharacterSet]] lowercaseString];
    while ([value hasPrefix:@"."]) {
        value = [value substringFromIndex:1];
    }
    if (value.length == 0 || [value rangeOfCharacterFromSet:
                              [[NSCharacterSet alphanumericCharacterSet] invertedSet]].location != NSNotFound) {
        return nil;
    }
    return value;
}

+ (NSString *)typeIdentifierForExtension:(NSString *)extension {
    NSString *normalized = [self normalizedExtension:extension];
    if (!normalized) return nil;
    CFStringRef uti = UTTypeCreatePreferredIdentifierForTag(kUTTagClassFilenameExtension,
                                                             (__bridge CFStringRef)normalized,
                                                             NULL);
    return CFBridgingRelease(uti);
}

+ (NSString *)currentHandlerForExtension:(NSString *)extension {
    NSString *uti = [self typeIdentifierForExtension:extension];
    if (!uti) return nil;
    CFStringRef handler = LSCopyDefaultRoleHandlerForContentType((__bridge CFStringRef)uti,
                                                                 kLSRolesAll);
    return CFBridgingRelease(handler);
}

+ (BOOL)setHandler:(NSString *)bundleIdentifier
      forExtension:(NSString *)extension
             error:(NSError **)error {
    NSString *uti = [self typeIdentifierForExtension:extension];
    if (!uti) {
        if (error) {
            *error = [NSError errorWithDomain:OGLaunchServicesErrorDomain code:-1
                                     userInfo:@{NSLocalizedDescriptionKey: @"Invalid filename extension."}];
        }
        return NO;
    }
    OSStatus status = LSSetDefaultRoleHandlerForContentType((__bridge CFStringRef)uti,
                                                             kLSRolesAll,
                                                             (__bridge CFStringRef)bundleIdentifier);
    if (status != noErr) {
        if (error) {
            *error = [NSError errorWithDomain:OGLaunchServicesErrorDomain code:status
                                     userInfo:@{NSLocalizedDescriptionKey:
                                                    [NSString stringWithFormat:@"Launch Services returned %d.", (int)status]}];
        }
        return NO;
    }
    return YES;
}

+ (NSString *)applicationNameForBundleIdentifier:(NSString *)bundleIdentifier {
    NSString *path = [[NSWorkspace sharedWorkspace] absolutePathForAppBundleWithIdentifier:bundleIdentifier];
    if (!path) return bundleIdentifier;
    NSBundle *bundle = [NSBundle bundleWithPath:path];
    return [bundle objectForInfoDictionaryKey:@"CFBundleDisplayName"]
        ?: [bundle objectForInfoDictionaryKey:@"CFBundleName"]
        ?: [[path lastPathComponent] stringByDeletingPathExtension];
}

@end

