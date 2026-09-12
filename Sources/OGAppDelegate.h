#import <Cocoa/Cocoa.h>
#import "OGUpdateChecker.h"

@interface OGAppDelegate : NSObject <NSApplicationDelegate, NSOutlineViewDataSource, NSOutlineViewDelegate,
                                     NSMenuDelegate, NSTextFieldDelegate, OGUpdateCheckerDelegate>
@end
