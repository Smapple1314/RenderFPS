#import <Preferences/PSListController.h>
#import <Preferences/PSSpecifier.h>
#import "../Shared.h"
@interface RFSettingsController : PSListController <UIColorPickerViewControllerDelegate>
@end
@implementation RFSettingsController
- (void)chooseTextColor {
    NSDictionary *p = RFReadPreferences();
    UIColorPickerViewController *picker = [UIColorPickerViewController new];
    picker.title = @"自定义文字颜色";
    picker.supportsAlpha = YES;
    picker.selectedColor = [UIColor colorWithRed:[p[@"red"] doubleValue] green:[p[@"green"] doubleValue] blue:[p[@"blue"] doubleValue] alpha:[p[@"alpha"] doubleValue]];
    picker.delegate = self;
    [self presentViewController:picker animated:YES completion:nil];
}
- (void)saveColor:(UIColor *)color {
    UIColor *resolved = [color resolvedColorWithTraitCollection:self.traitCollection];
    CGFloat r=0,g=0,b=0,a=1,w=0;
    if (![resolved getRed:&r green:&g blue:&b alpha:&a]) {
        if (![resolved getWhite:&w alpha:&a]) return;
        r=g=b=w;
    }
    // One notification after all channels avoids partial-color updates.
    NSDictionary *values = @{@"red":@(r), @"green":@(g), @"blue":@(b), @"alpha":@(a)};
    for (NSString *key in values) CFPreferencesSetAppValue((__bridge CFStringRef)key, (__bridge CFPropertyListRef)values[key], (__bridge CFStringRef)RFPreferenceDomain);
    CFPreferencesAppSynchronize((__bridge CFStringRef)RFPreferenceDomain);
    notify_post(RFPreferenceNotification.UTF8String);
}
- (void)colorPickerViewControllerDidSelectColor:(UIColorPickerViewController *)picker { [self saveColor:picker.selectedColor]; }
- (void)colorPickerViewControllerDidFinish:(UIColorPickerViewController *)picker { [self saveColor:picker.selectedColor]; }
- (NSArray *)specifiers {
    if (!_specifiers) _specifiers = [self loadSpecifiersFromPlistName:@"Root" target:self];
    return _specifiers;
}
- (id)readPreferenceValue:(PSSpecifier *)specifier {
    id value=RFReadPreferences()[[specifier propertyForKey:@"key"]];
    return value ?: [specifier propertyForKey:@"default"];
}
- (void)setPreferenceValue:(id)value specifier:(PSSpecifier *)specifier {
    RFWritePreference([specifier propertyForKey:@"key"],value);
}
@end
