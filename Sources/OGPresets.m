#import "OGPresets.h"

@implementation OGPresets

+ (NSArray<NSDictionary<NSString *,NSString *> *> *)all {
    return @[
        @{@"extension": @"md", @"name": @"Markdown"},
        @{@"extension": @"txt", @"name": @"Plain Text"},
        @{@"extension": @"log", @"name": @"Log"},
        @{@"extension": @"json", @"name": @"JSON"},
        @{@"extension": @"yaml", @"name": @"YAML"},
        @{@"extension": @"yml", @"name": @"YAML"},
        @{@"extension": @"xml", @"name": @"XML"},
        @{@"extension": @"csv", @"name": @"CSV"},
        @{@"extension": @"html", @"name": @"HTML"},
        @{@"extension": @"css", @"name": @"CSS"},
        @{@"extension": @"js", @"name": @"JavaScript"},
        @{@"extension": @"ts", @"name": @"TypeScript"},
        @{@"extension": @"py", @"name": @"Python"},
        @{@"extension": @"java", @"name": @"Java"},
        @{@"extension": @"c", @"name": @"C Source"},
        @{@"extension": @"cpp", @"name": @"C++ Source"},
        @{@"extension": @"h", @"name": @"Header"},
        @{@"extension": @"swift", @"name": @"Swift"},
        @{@"extension": @"go", @"name": @"Go"},
        @{@"extension": @"rs", @"name": @"Rust"},
        @{@"extension": @"pdf", @"name": @"PDF"},
        @{@"extension": @"png", @"name": @"PNG Image"},
        @{@"extension": @"jpg", @"name": @"JPEG Image"},
        @{@"extension": @"jpeg", @"name": @"JPEG Image"},
        @{@"extension": @"gif", @"name": @"GIF Image"},
        @{@"extension": @"svg", @"name": @"SVG Image"},
        @{@"extension": @"webp", @"name": @"WebP Image"},
        @{@"extension": @"mp3", @"name": @"MP3 Audio"},
        @{@"extension": @"flac", @"name": @"FLAC Audio"},
        @{@"extension": @"mp4", @"name": @"MP4 Video"},
        @{@"extension": @"mov", @"name": @"QuickTime Video"},
        @{@"extension": @"zip", @"name": @"ZIP Archive"},
        @{@"extension": @"7z", @"name": @"7-Zip Archive"}
    ];
}

@end

