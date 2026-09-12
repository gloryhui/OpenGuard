#import "OGLaunchAgent.h"

static NSString * const OGAgentLabel = @"com.gloryhuis.OpenGuard.agent";

@implementation OGLaunchAgent

+ (NSString *)plistPath {
    return [NSHomeDirectory() stringByAppendingPathComponent:
            @"Library/LaunchAgents/com.gloryhuis.OpenGuard.agent.plist"];
}

+ (BOOL)isEnabled {
    return [[NSFileManager defaultManager] fileExistsAtPath:[self plistPath]];
}

+ (BOOL)setEnabled:(BOOL)enabled error:(NSError **)error {
    NSString *path = [self plistPath];
    NSFileManager *manager = [NSFileManager defaultManager];
    if (!enabled) {
        if (![manager fileExistsAtPath:path]) return YES;
        return [manager removeItemAtPath:path error:error];
    }

    NSString *executable = [[NSBundle mainBundle] executablePath];
    if (!executable) return NO;
    NSString *directory = [path stringByDeletingLastPathComponent];
    if (![manager createDirectoryAtPath:directory withIntermediateDirectories:YES attributes:nil error:error]) {
        return NO;
    }
    NSDictionary *plist = @{ @"Label": OGAgentLabel,
                             @"ProgramArguments": @[executable, @"--agent"],
                             @"RunAtLoad": @YES,
                             @"ProcessType": @"Interactive" };
    return [plist writeToFile:path atomically:YES];
}

@end

