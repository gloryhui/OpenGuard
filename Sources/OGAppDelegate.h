#import <Cocoa/Cocoa.h>
#import "OGUpdateChecker.h"

@interface OGAppDelegate : NSObject <NSApplicationDelegate, NSOutlineViewDataSource, NSOutlineViewDelegate,
                                     OGUpdateCheckerDelegate>
@end
