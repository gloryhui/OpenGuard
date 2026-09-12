#import "OGUpdateChecker.h"

static const NSTimeInterval OGUpdateCheckInterval = 60.0 * 60.0;
static NSString * const OGLatestReleaseAPI = @"https://api.github.com/repos/gloryhui/OpenGuard/releases/latest";

@interface OGUpdateChecker ()
@property (nonatomic, copy) NSString *currentVersion;
@property (nonatomic, weak) id<OGUpdateCheckerDelegate> delegate;
@property (nonatomic) NSTimer *timer;
@property (nonatomic, copy, nullable) NSString *notifiedVersion;
@property (nonatomic, copy, nullable) void (^manualCompletion)(NSString * _Nullable,
                                                                   NSURL * _Nullable,
                                                                   NSError * _Nullable);
@property (nonatomic) BOOL checking;
@end

@implementation OGUpdateChecker

- (instancetype)initWithCurrentVersion:(NSString *)currentVersion
                               delegate:(id<OGUpdateCheckerDelegate>)delegate {
    self = [super init];
    if (!self) return nil;
    _currentVersion = [currentVersion copy];
    _delegate = delegate;
    return self;
}

- (void)start {
    [self stop];
    [self checkNow];
    self.timer = [NSTimer timerWithTimeInterval:OGUpdateCheckInterval
                                         target:self
                                       selector:@selector(timerFired:)
                                       userInfo:nil
                                        repeats:YES];
    self.timer.tolerance = 60.0;
    [[NSRunLoop mainRunLoop] addTimer:self.timer forMode:NSRunLoopCommonModes];
}

- (void)stop {
    [self.timer invalidate];
    self.timer = nil;
}

- (void)timerFired:(NSTimer *)timer {
    [self checkNow];
}

- (void)checkNow {
    [self beginCheckWithManualCompletion:nil];
}

- (void)checkNowWithCompletion:(void (^)(NSString * _Nullable,
                                         NSURL * _Nullable,
                                         NSError * _Nullable))completion {
    [self beginCheckWithManualCompletion:completion];
}

- (void)beginCheckWithManualCompletion:(void (^ _Nullable)(NSString * _Nullable,
                                                            NSURL * _Nullable,
                                                            NSError * _Nullable))completion {
    @synchronized (self) {
        if (completion) self.manualCompletion = completion;
        if (self.checking) return;
        self.checking = YES;
    }

    NSURL *URL = [NSURL URLWithString:OGLatestReleaseAPI];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:URL
                                                           cachePolicy:NSURLRequestReloadIgnoringLocalCacheData
                                                       timeoutInterval:15.0];
    [request setValue:@"application/vnd.github+json" forHTTPHeaderField:@"Accept"];
    [request setValue:@"OpenGuard" forHTTPHeaderField:@"User-Agent"];
    [request setValue:@"2022-11-28" forHTTPHeaderField:@"X-GitHub-Api-Version"];

    __weak typeof(self) weakSelf = self;
    NSURLSessionDataTask *task = [[NSURLSession sharedSession]
        dataTaskWithRequest:request
          completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        __strong typeof(weakSelf) self = weakSelf;
        if (!self) return;

        NSHTTPURLResponse *HTTPResponse = [response isKindOfClass:[NSHTTPURLResponse class]]
            ? (NSHTTPURLResponse *)response : nil;
        if (error || HTTPResponse.statusCode != 200 || data.length == 0) {
            if (error) NSLog(@"Update check skipped: %@", error.localizedDescription);
            NSError *resultError = error ?: [NSError errorWithDomain:@"com.gloryhuis.OpenGuard.Update"
                                                                 code:HTTPResponse.statusCode ?: -1
                                                             userInfo:nil];
            [self finishCheckWithVersion:nil releaseURL:nil error:resultError];
            return;
        }

        NSError *JSONError = nil;
        id object = [NSJSONSerialization JSONObjectWithData:data options:0 error:&JSONError];
        if (![object isKindOfClass:[NSDictionary class]]) {
            NSLog(@"Update check returned invalid metadata: %@", JSONError.localizedDescription ?: @"unknown response");
            NSError *resultError = JSONError ?: [NSError errorWithDomain:@"com.gloryhuis.OpenGuard.Update"
                                                                     code:-2 userInfo:nil];
            [self finishCheckWithVersion:nil releaseURL:nil error:resultError];
            return;
        }

        NSDictionary *release = (NSDictionary *)object;
        NSString *tag = [release[@"tag_name"] isKindOfClass:[NSString class]] ? release[@"tag_name"] : nil;
        NSString *URLString = [release[@"html_url"] isKindOfClass:[NSString class]] ? release[@"html_url"] : nil;
        BOOL draft = [release[@"draft"] boolValue];
        BOOL prerelease = [release[@"prerelease"] boolValue];
        NSURL *releaseURL = URLString.length ? [NSURL URLWithString:URLString] : nil;
        NSString *newVersion = tag.length && releaseURL && !draft && !prerelease &&
            [OGUpdateChecker isVersion:tag newerThanVersion:self.currentVersion] ? tag : nil;
        [self finishCheckWithVersion:newVersion releaseURL:releaseURL error:nil];
    }];
    [task resume];
}

- (void)finishCheckWithVersion:(NSString *)version
                    releaseURL:(NSURL *)releaseURL
                         error:(NSError *)error {
    __block void (^manualCompletion)(NSString *, NSURL *, NSError *);
    @synchronized (self) {
        self.checking = NO;
        manualCompletion = self.manualCompletion;
        self.manualCompletion = nil;
    }
    dispatch_async(dispatch_get_main_queue(), ^{
        if (manualCompletion) {
            manualCompletion(version, releaseURL, error);
            return;
        }
        if (!version.length || [self.notifiedVersion isEqualToString:version]) return;
        self.notifiedVersion = version;
        [self.delegate updateChecker:self didFindNewVersion:version releaseURL:releaseURL];
    });
}

+ (NSString *)normalizedVersion:(NSString *)version {
    NSString *normalized = [version stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if ([normalized hasPrefix:@"v"] || [normalized hasPrefix:@"V"]) {
        normalized = [normalized substringFromIndex:1];
    }
    return normalized;
}

+ (BOOL)isVersion:(NSString *)candidate newerThanVersion:(NSString *)currentVersion {
    NSString *candidateVersion = [self normalizedVersion:candidate];
    NSString *installedVersion = [self normalizedVersion:currentVersion];
    if (!candidateVersion.length || !installedVersion.length) return NO;
    return [candidateVersion compare:installedVersion options:NSNumericSearch] == NSOrderedDescending;
}

@end
