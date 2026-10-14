#import "Shared.h"
#import <objc/message.h>
#import <math.h>

static UIWindow *RFWindow;
static NSDictionary *RFPrefs;
static int RFReadingToken=-1;
static NSString *RFCurrentBundle;

static id RFCall(id object, NSString *name) {
    SEL sel=NSSelectorFromString(name);
    return [object respondsToSelector:sel] ? ((id(*)(id,SEL))objc_msgSend)(object,sel) : nil;
}
static BOOL RFLocked(void) {
    id manager=RFCall(NSClassFromString(@"SBLockScreenManager"), @"sharedInstance");
    for (NSString *name in @[@"isUILocked", @"isLocked"]) {
        SEL s=NSSelectorFromString(name);
        if ([manager respondsToSelector:s]) return ((BOOL(*)(id,SEL))objc_msgSend)(manager,s);
    }
    return YES;
}
@interface RFWindowClass : UIWindow
@end
@implementation RFWindowClass
- (UIView *)hitTest:(CGPoint)p withEvent:(UIEvent *)event {
    UIView *v=[super hitTest:p withEvent:event];
    return v==self || v==self.rootViewController.view ? nil : v;
}
@end
@interface RFOverlay : UIViewController
@property(nonatomic,strong) UILabel *label;
@property(nonatomic,strong) NSTimer *timer;
@property(nonatomic,assign) CGPoint dragOrigin;
- (void)refresh;
- (void)position;
@end
@implementation RFOverlay
- (void)loadView {
    self.view=[[UIView alloc] initWithFrame:UIScreen.mainScreen.bounds];
    self.view.backgroundColor=UIColor.clearColor;
    self.label=[UILabel new]; self.label.text=@"FPS --";
    self.label.textAlignment=NSTextAlignmentCenter;
    self.label.userInteractionEnabled=YES;
    self.label.accessibilityLabel=@"应用 Metal 呈现帧率；长按打开设置，双击锁定位置";
    [self.view addSubview:self.label];
    UITapGestureRecognizer *tap=[[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(toggleLock)];
    tap.numberOfTapsRequired=2; [self.label addGestureRecognizer:tap];
    UILongPressGestureRecognizer *hold=[[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(settings:)];
    hold.minimumPressDuration=0.6; [self.label addGestureRecognizer:hold];
    UIPanGestureRecognizer *pan=[[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(drag:)];
    [pan requireGestureRecognizerToFail:hold]; [self.label addGestureRecognizer:pan];
    self.timer=[NSTimer timerWithTimeInterval:0.5 target:self selector:@selector(refresh) userInfo:nil repeats:YES];
    [NSRunLoop.mainRunLoop addTimer:self.timer forMode:NSRunLoopCommonModes];
    [self refresh];
}
- (void)viewDidLayoutSubviews { [super viewDidLayoutSubviews]; [self position]; }
- (BOOL)shouldAutorotate { return YES; }
- (UIInterfaceOrientationMask)supportedInterfaceOrientations { return UIInterfaceOrientationMaskAll; }
- (CGRect)region {
    UIEdgeInsets i=self.view.safeAreaInsets;
    return UIEdgeInsetsInsetRect(self.view.bounds, UIEdgeInsetsMake(4,i.left+4,i.bottom+4,i.right+4));
}
- (void)position {
    CGRect region=[self region];
    CGSize text=[@"FPS 120" sizeWithAttributes:@{NSFontAttributeName:self.label.font ?: [UIFont systemFontOfSize:12]}];
    CGSize size=CGSizeMake(ceil(text.width)+8,ceil(text.height)+8);
    double x=fmin(1,fmax(0,[RFPrefs[@"x"] doubleValue])), y=fmin(1,fmax(0,[RFPrefs[@"y"] doubleValue]));
    self.label.frame=CGRectMake(region.origin.x+MAX(0,region.size.width-size.width)*x,region.origin.y+MAX(0,region.size.height-size.height)*y,size.width,size.height);
}
- (void)refresh {
    BOOL hide=![RFPrefs[@"enabled"] boolValue] || RFLocked();
    RFWindow.hidden=hide;
    if (hide) return;
    CGFloat size=fmin(28,fmax(8,[RFPrefs[@"fontSize"] doubleValue]));
    self.label.font=[UIFont monospacedDigitSystemFontOfSize:size weight:[RFPrefs[@"bold"] boolValue] ? UIFontWeightBold : UIFontWeightRegular];
    self.label.textColor=[UIColor colorWithRed:fmin(1,fmax(0,[RFPrefs[@"red"] doubleValue])) green:fmin(1,fmax(0,[RFPrefs[@"green"] doubleValue])) blue:fmin(1,fmax(0,[RFPrefs[@"blue"] doubleValue])) alpha:1];
    id application=RFCall(UIApplication.sharedApplication,@"_accessibilityFrontMostApplication");
    NSString *bundle=RFCall(application,@"bundleIdentifier");
    if (![bundle isKindOfClass:NSString.class]) bundle=nil;
    if (![RFCurrentBundle isEqual:bundle]) {
        if (RFReadingToken>=0) notify_cancel(RFReadingToken);
        RFReadingToken=-1; RFCurrentBundle=[bundle copy];
        if (bundle.length) notify_register_check(RFChannel(bundle).UTF8String,&RFReadingToken);
    }
    uint64_t state=0; double fps=0;
    BOOL valid=RFApplicationEnabled(RFPrefs,bundle) && RFReadingToken>=0 && notify_get_state(RFReadingToken,&state)==NOTIFY_STATUS_OK && RFUnpackReading(state,&fps);
    self.label.text=valid ? [NSString stringWithFormat:@"FPS %.0f",fps] : @"FPS --";
    [self position];
}
- (void)toggleLock {
    RFWritePreference(@"locked",@(![RFPrefs[@"locked"] boolValue]));
    RFPrefs=RFReadPreferences();
    self.label.alpha=0.4; [UIView animateWithDuration:0.25 animations:^{ self.label.alpha=1; }];
}
- (void)settings:(UILongPressGestureRecognizer *)g {
    if (g.state!=UIGestureRecognizerStateBegan) return;
    NSURL *url=[NSURL URLWithString:@"App-prefs:root=RenderFPS"];
    [UIApplication.sharedApplication openURL:url options:@{} completionHandler:nil];
}
- (void)drag:(UIPanGestureRecognizer *)g {
    if ([RFPrefs[@"locked"] boolValue]) return;
    if (g.state==UIGestureRecognizerStateBegan) self.dragOrigin=self.label.frame.origin;
    CGPoint d=[g translationInView:self.view]; CGRect r=[self region];
    double x=fmin(1,fmax(0,(self.dragOrigin.x+d.x-r.origin.x)/MAX(1,r.size.width-self.label.bounds.size.width)));
    double y=fmin(1,fmax(0,(self.dragOrigin.y+d.y-r.origin.y)/MAX(1,r.size.height-self.label.bounds.size.height)));
    NSMutableDictionary *p=[RFPrefs mutableCopy]; p[@"x"]=@(x); p[@"y"]=@(y); RFPrefs=p; [self position];
    if (g.state==UIGestureRecognizerStateEnded || g.state==UIGestureRecognizerStateCancelled) {
        RFWritePreference(@"x",@(x)); RFWritePreference(@"y",@(y));
    }
}
@end
static void RFStartOverlay(void) {
    if (RFWindow) return;
    UIWindowScene *scene=nil;
    for (UIScene *s in UIApplication.sharedApplication.connectedScenes) {
        if ([s isKindOfClass:UIWindowScene.class]) { scene=(UIWindowScene *)s; if (s.activationState==UISceneActivationStateForegroundActive) break; }
    }
    if (!scene) return;
    RFPrefs=RFReadPreferences();
    RFWindow=[[RFWindowClass alloc] initWithWindowScene:scene];
    RFWindow.frame=scene.coordinateSpace.bounds; RFWindow.backgroundColor=UIColor.clearColor;
    RFWindow.windowLevel=UIWindowLevelAlert+100; RFWindow.rootViewController=[RFOverlay new];
    (void)RFWindow.rootViewController.view;
}
%ctor {
    if ([NSBundle.mainBundle.bundleIdentifier isEqual:@"com.apple.springboard"]) {
        dispatch_async(dispatch_get_main_queue(), ^{
            static int preferencesToken;
            notify_register_dispatch(RFPreferenceNotification.UTF8String,&preferencesToken,dispatch_get_main_queue(),^(int token){ RFPrefs=RFReadPreferences(); });
            [[NSNotificationCenter defaultCenter] addObserverForName:UISceneDidActivateNotification object:nil queue:NSOperationQueue.mainQueue usingBlock:^(NSNotification *n){ RFStartOverlay(); }];
            for (int i=1;i<=5;i++) dispatch_after(dispatch_time(DISPATCH_TIME_NOW,(int64_t)i*2*NSEC_PER_SEC),dispatch_get_main_queue(),^{ RFStartOverlay(); });
        });
    }
}
