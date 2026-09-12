#import <Cocoa/Cocoa.h>

@class OGLanguage;

@interface OGApplicationPicker : NSObject <NSTableViewDataSource, NSTableViewDelegate, NSWindowDelegate,
                                            NSSearchFieldDelegate>

- (instancetype)initWithLanguage:(OGLanguage *)language;
- (NSDictionary *)runWithTitle:(NSString *)title
       currentBundleIdentifier:(NSString *)bundleIdentifier;

@end
