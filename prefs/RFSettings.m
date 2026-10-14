#import <Preferences/PSListController.h>
#import <Preferences/PSSpecifier.h>
#import "../Shared.h"

@interface RFSettingsController : PSListController
@end

@implementation RFSettingsController

- (NSArray *)specifiers {
    if (!_specifiers) {
        _specifiers = [self loadSpecifiersFromPlistName:@"Root"
                                              target:self];
    }
    return _specifiers;
}

- (id)readPreferenceValue:(PSSpecifier *)specifier {
    NSString *key = [specifier propertyForKey:@"key"];
    id value = RFReadPreferences()[key];
    return value ?: [specifier propertyForKey:@"default"];
}

- (void)setPreferenceValue:(id)value
                specifier:(PSSpecifier *)specifier {
    NSString *key = [specifier propertyForKey:@"key"];
    RFWritePreference(key, value);
}

@end
