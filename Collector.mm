#import "Shared.h"
#import <Metal/Metal.h>
#import <QuartzCore/CAMetalLayer.h>
#import <objc/runtime.h>
#import <substrate.h>
#import <math.h>

// Only opt-in applications. No CADisplayLink fallback, no game/anti-cheat bypass.
static id<CAMetalDrawable> (*RFOriginalNextDrawable)(id, SEL);
static dispatch_queue_t RFQueue;
static BOOL RFEnabled;
static double RFInterval = 0.5;
static int RFToken = -1;
static CFTimeInterval RFStartTime, RFLastTime;
static NSUInteger RFPresentedCount;
static double RFDominantArea;
static CFTimeInterval RFAreaTime;
static uint64_t RFGeneration;
static NSString *RFBundle;

static void RFPublish(double fps, BOOL valid) {
    if (RFToken < 0) return;
    notify_set_state(RFToken, RFPackReading(fps, valid));
    notify_post(RFChannel(RFBundle).UTF8String);
}
static void RFReset(void) {
    RFStartTime = 0; RFLastTime = 0; RFPresentedCount = 0;
    RFDominantArea = 0; RFAreaTime = 0; RFGeneration++;
    RFPublish(0, NO);
}
static void RFReload(void) {
    NSDictionary *p = RFReadPreferences();
    dispatch_async(RFQueue, ^{
        RFEnabled = RFApplicationEnabled(p, RFBundle);
        RFInterval = fmin(2, fmax(0.25, [p[@"interval"] doubleValue]));
        RFReset();
    });
}
static id<CAMetalDrawable> RFNextDrawable(CAMetalLayer *layer, SEL cmd) {
    id<CAMetalDrawable> drawable = RFOriginalNextDrawable(layer, cmd);
    if (!drawable || ![drawable respondsToSelector:@selector(addPresentedHandler:)]) return drawable;
    // Registration happens on the render thread, state mutation on one serial queue.
    // Largest active drawable stream is a heuristic; multi-layer apps need validation.
    CGSize size = layer.drawableSize;
    double area = size.width * size.height;
    dispatch_sync(RFQueue, ^{
        if (!RFEnabled) return;
        double now = CACurrentMediaTime();
        if (area < RFDominantArea && now-RFAreaTime < 2) return;
        if (area > RFDominantArea || now-RFAreaTime >= 2) {
            if (area != RFDominantArea) { RFStartTime=0; RFLastTime=0; RFPresentedCount=0; RFGeneration++; }
            RFDominantArea = area;
        }
        RFAreaTime = now;
        uint64_t generation = RFGeneration;
        [drawable addPresentedHandler:^(id<MTLDrawable> presented) {
            double timestamp = presented.presentedTime;
            dispatch_async(RFQueue, ^{
                if (!RFEnabled || generation != RFGeneration || timestamp <= 0 || !isfinite(timestamp)) return;
                // Duplicate timestamps across equal-sized layers are suppressed.
                if (timestamp <= RFLastTime) return;
                RFLastTime = timestamp;
                if (RFStartTime == 0) { RFStartTime=timestamp; return; }
                RFPresentedCount++;
                double elapsed = timestamp-RFStartTime;
                if (elapsed >= RFInterval) {
                    RFPublish(RFPresentedCount/elapsed, YES);
                    RFPresentedCount=0; RFStartTime=timestamp;
                }
            });
        }];
    });
    return drawable;
}
__attribute__((constructor)) static void RFCollectorInitialize(void) {
    RFBundle = NSBundle.mainBundle.bundleIdentifier;
    if ([RFBundle isEqual:@"com.apple.springboard"] || RFBundle.length == 0) return;
    if (!RFApplicationEnabled(RFReadPreferences(), RFBundle)) return;
    RFQueue = dispatch_queue_create("com.minis.renderfps.collector", DISPATCH_QUEUE_SERIAL);
    notify_register_check(RFChannel(RFBundle).UTF8String, &RFToken);
    RFReload();
    static int preferencesToken;
    notify_register_dispatch(RFPreferenceNotification.UTF8String, &preferencesToken, dispatch_get_main_queue(), ^(int t) { RFReload(); });
    [[NSNotificationCenter defaultCenter] addObserverForName:UIApplicationDidEnterBackgroundNotification object:nil queue:NSOperationQueue.mainQueue usingBlock:^(NSNotification *note) {
        dispatch_async(RFQueue, ^{ RFEnabled=NO; RFReset(); });
    }];
    [[NSNotificationCenter defaultCenter] addObserverForName:UIApplicationDidBecomeActiveNotification object:nil queue:NSOperationQueue.mainQueue usingBlock:^(NSNotification *note) { RFReload(); }];
    MSHookMessageEx(CAMetalLayer.class, @selector(nextDrawable), (IMP)RFNextDrawable, (IMP *)&RFOriginalNextDrawable);
}
