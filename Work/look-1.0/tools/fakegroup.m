#import <Cocoa/Cocoa.h>
#import <objc/runtime.h>
// 1) Points every App Group container at a scratchpad folder, so the local build never touches
//    ~/Library/Group Containers (macOS guards it with an "access data from other apps" dialog).
// 2) A tiny command file ($PARAGON_CMD_FILE): "list" writes the app's windows to <file>.out,
//    "front" orders the titled windows front, "url <link>" hands a link to the app in-process
//    (so no amspara:// link ever goes through the system, which would start the real app).
static NSURL *fakeContainer(id self, SEL _cmd, NSString *group) {
    const char *base = getenv("PARAGON_FAKE_GROUPS");
    if (!base) return nil;
    NSString *path = [[NSString stringWithUTF8String:base] stringByAppendingPathComponent:group ?: @"nil"];
    [[NSFileManager defaultManager] createDirectoryAtPath:path withIntermediateDirectories:YES attributes:nil error:nil];
    return [NSURL fileURLWithPath:path isDirectory:YES];
}
static void poll(void) {
    const char *c = getenv("PARAGON_CMD_FILE");
    if (!c) return;
    NSString *file = [NSString stringWithUTF8String:c];
    NSString *cmd = [NSString stringWithContentsOfFile:file encoding:NSUTF8StringEncoding error:nil];
    if (!cmd) return;
    [[NSFileManager defaultManager] removeItemAtPath:file error:nil];
    cmd = [cmd stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    NSMutableString *out = [NSMutableString string];
    if ([cmd isEqualToString:@"list"] || [cmd isEqualToString:@"front"]) {
        for (NSWindow *w in NSApp.windows) {
            [out appendFormat:@"%@ title='%@' visible=%d frame=%@ mask=%lu num=%ld\n", NSStringFromClass([w class]), w.title, w.isVisible, NSStringFromRect(w.frame), (unsigned long)w.styleMask, (long)w.windowNumber];
            if ([cmd isEqualToString:@"front"] && (w.styleMask & NSWindowStyleMaskTitled) && ![w isKindOfClass:[NSPanel class]]) {
                [w makeKeyAndOrderFront:nil];
            }
        }
    } else if ([cmd isEqualToString:@"reopen"]) {
        id delegate = NSApp.delegate;
        if ([delegate respondsToSelector:@selector(applicationShouldHandleReopen:hasVisibleWindows:)]) {
            BOOL r = [delegate applicationShouldHandleReopen:NSApp hasVisibleWindows:NO];
            [out appendFormat:@"reopen returned %d\n", r];
        } else { [out appendString:@"no reopen on delegate\n"]; }
        if ([delegate respondsToSelector:@selector(applicationOpenUntitledFile:)]) {
            BOOL r = [delegate applicationOpenUntitledFile:NSApp];
            [out appendFormat:@"untitled returned %d\n", r];
        } else { [out appendString:@"no untitled on delegate\n"]; }
    } else if ([cmd hasPrefix:@"url "]) {
        NSURL *url = [NSURL URLWithString:[cmd substringFromIndex:4]];
        id delegate = NSApp.delegate;
        if (url && [delegate respondsToSelector:@selector(application:openURLs:)]) {
            [delegate application:NSApp openURLs:@[url]];
            [out appendFormat:@"opened %@\n", url];
        } else {
            [out appendString:@"no openURLs on delegate\n"];
        }
    }
    [out writeToFile:[file stringByAppendingString:@".out"] atomically:YES encoding:NSUTF8StringEncoding error:nil];
}
__attribute__((constructor)) static void install(void) {
    Method m = class_getInstanceMethod([NSFileManager class], @selector(containerURLForSecurityApplicationGroupIdentifier:));
    if (m) method_setImplementation(m, (IMP)fakeContainer);
    // The app reads showCalendarEvents as a Bool; a "-showCalendarEvents 0" launch argument is a
    // string and is ignored, so the Time Blocks screen would ask for Calendar access. Register a
    // real NO underneath (the registration domain survives the test vault's settings wipe).
    [[NSUserDefaults standardUserDefaults] registerDefaults:@{@"showCalendarEvents": @NO}];
    dispatch_async(dispatch_get_main_queue(), ^{
        if (getenv("PARAGON_DARK")) NSApp.appearance = [NSAppearance appearanceNamed:NSAppearanceNameDarkAqua];
        [NSTimer scheduledTimerWithTimeInterval:1.0 repeats:YES block:^(NSTimer *t) { poll(); }];
    });
}
