#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <notify.h>

#ifdef __cplusplus
extern "C" {
#endif

FOUNDATION_EXPORT NSString *const RFPreferenceDomain;
FOUNDATION_EXPORT NSString *const RFPreferenceNotification;

NSDictionary *RFReadPreferences(void);
void RFWritePreference(NSString *key, id value);
NSString *RFChannel(NSString *bundleID);
uint64_t RFPackReading(double fps, BOOL valid);
BOOL RFUnpackReading(uint64_t state, double *fps);
BOOL RFApplicationEnabled(NSDictionary *preferences, NSString *bundleID);

#ifdef __cplusplus
}
#endif
