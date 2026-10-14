#import "Shared.h"
#import <time.h>
#import <math.h>
NSString *const RFPreferenceDomain = @"com.minis.renderfps";
NSString *const RFPreferenceNotification = @"com.minis.renderfps/preferences.changed";
NSDictionary *RFReadPreferences(void) {
    NSMutableDictionary *defaults = [@{@"enabled":@YES, @"fontSize":@12, @"bold":@NO, @"red":@1, @"green":@1, @"blue":@1, @"alpha":@1, @"invert":@NO, @"x":@0.9, @"y":@0.04, @"locked":@YES, @"interval":@0.5, @"applications":@""} mutableCopy];
    CFPreferencesAppSynchronize((__bridge CFStringRef)RFPreferenceDomain);
    for (NSString *key in defaults.allKeys) {
        id value = CFBridgingRelease(CFPreferencesCopyAppValue((__bridge CFStringRef)key, (__bridge CFStringRef)RFPreferenceDomain));
        if (value) defaults[key] = value;
    }
    return defaults;
}
void RFWritePreference(NSString *key, id value) {
    CFPreferencesSetAppValue((__bridge CFStringRef)key, (__bridge CFPropertyListRef)value, (__bridge CFStringRef)RFPreferenceDomain);
    CFPreferencesAppSynchronize((__bridge CFStringRef)RFPreferenceDomain);
    notify_post(RFPreferenceNotification.UTF8String);
}
NSString *RFChannel(NSString *bundleID) {
    return [@"com.minis.renderfps/reading/" stringByAppendingString:bundleID ?: @"unknown"];
}
// State contains rounded tenths-FPS plus monotonic freshness timestamp (seconds).
// Darwin notify is local IPC, not authenticated; never treat readings as security data.
static uint32_t RFClock(void) {
    struct timespec ts; clock_gettime(CLOCK_MONOTONIC, &ts); return (uint32_t)ts.tv_sec;
}
uint64_t RFPackReading(double fps, BOOL valid) {
    uint32_t reading = valid && isfinite(fps) ? (uint32_t)llround(fmin(1000,fmax(0,fps))*10)+1 : 0;
    return ((uint64_t)RFClock()<<32) | reading;
}
BOOL RFUnpackReading(uint64_t state, double *fps) {
    uint32_t age = RFClock() - (uint32_t)(state>>32), value = (uint32_t)state;
    if (age > 3 || value == 0 || value > 10001) return NO;
    *fps = (value-1)/10.0; return YES;
}
BOOL RFApplicationEnabled(NSDictionary *p, NSString *bundleID) {
    if (![p[@"enabled"] boolValue] || bundleID.length == 0) return NO;
    NSString *list = [p[@"applications"] isKindOfClass:NSString.class] ? p[@"applications"] : @"";
    for (NSString *item in [list componentsSeparatedByString:@","]) {
        if ([[item stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet] isEqual:bundleID]) return YES;
    }
    return NO;
}
