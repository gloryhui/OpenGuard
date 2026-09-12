#import "OGPresets.h"

@implementation OGPresets

+ (NSArray<NSDictionary<NSString *,NSString *> *> *)all {
    NSMutableArray *items = [NSMutableArray array];
    for (NSDictionary *group in [self defaultGroups]) [items addObjectsFromArray:group[@"items"]];
    return items;
}

+ (NSArray<NSDictionary *> *)defaultGroups {
    return @[
        @{@"identifier": @"documents", @"titleKey": @"group_documents", @"items": @[
              @{@"extension": @"md", @"name": @"Markdown"}, @{@"extension": @"txt", @"name": @"Plain Text"},
              @{@"extension": @"log", @"name": @"Log"}, @{@"extension": @"pdf", @"name": @"PDF"},
              @{@"extension": @"csv", @"name": @"CSV"}]},
        @{@"identifier": @"data", @"titleKey": @"group_data", @"items": @[
              @{@"extension": @"json", @"name": @"JSON"}, @{@"extension": @"yaml", @"name": @"YAML"},
              @{@"extension": @"yml", @"name": @"YAML"}, @{@"extension": @"xml", @"name": @"XML"}]},
        @{@"identifier": @"web", @"titleKey": @"group_web", @"items": @[
              @{@"extension": @"html", @"name": @"HTML"}, @{@"extension": @"css", @"name": @"CSS"},
              @{@"extension": @"js", @"name": @"JavaScript"}, @{@"extension": @"ts", @"name": @"TypeScript"}]},
        @{@"identifier": @"source", @"titleKey": @"group_source", @"items": @[
              @{@"extension": @"py", @"name": @"Python"}, @{@"extension": @"java", @"name": @"Java"},
              @{@"extension": @"c", @"name": @"C Source"}, @{@"extension": @"cpp", @"name": @"C++ Source"},
              @{@"extension": @"h", @"name": @"Header"}, @{@"extension": @"swift", @"name": @"Swift"},
              @{@"extension": @"go", @"name": @"Go"}, @{@"extension": @"rs", @"name": @"Rust"}]},
        @{@"identifier": @"images", @"titleKey": @"group_images", @"items": @[
              @{@"extension": @"png", @"name": @"PNG Image"}, @{@"extension": @"jpg", @"name": @"JPEG Image"},
              @{@"extension": @"jpeg", @"name": @"JPEG Image"}, @{@"extension": @"gif", @"name": @"GIF Image"},
              @{@"extension": @"svg", @"name": @"SVG Image"}, @{@"extension": @"webp", @"name": @"WebP Image"}]},
        @{@"identifier": @"media", @"titleKey": @"group_media", @"items": @[
              @{@"extension": @"mp3", @"name": @"MP3 Audio"}, @{@"extension": @"flac", @"name": @"FLAC Audio"},
              @{@"extension": @"mp4", @"name": @"MP4 Video"}, @{@"extension": @"mov", @"name": @"QuickTime Video"}]},
        @{@"identifier": @"archives", @"titleKey": @"group_archives", @"items": @[
              @{@"extension": @"zip", @"name": @"ZIP Archive"}, @{@"extension": @"7z", @"name": @"7-Zip Archive"}]}
    ];
}

@end
