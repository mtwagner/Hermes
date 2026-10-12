//
//  Notifier.h
//  Hermes
//

#import <UserNotifications/UserNotifications.h>

@class Song;

#define NOTIFIER [HMSAppDelegate notifier]

@interface Notifier : NSObject <UNUserNotificationCenterDelegate>

- (void)notify:(Song *)song withImage:(NSData *)image isNew:(BOOL)isNew;

@end
