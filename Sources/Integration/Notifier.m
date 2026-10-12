/**
 * @file Notifier.m
 * @brief Native macOS notification integration for Hermes.
 */

#import "Notifier.h"

#import "Pandora/Song.h"
#import "PlaybackController.h"
#import "PreferencesController.h"

static NSString * const NotifierCategoryLiked = @"HERMES_PLAYBACK_LIKED";
static NSString * const NotifierCategoryUnliked = @"HERMES_PLAYBACK_UNLIKED";
static NSString * const NotifierActionNext = @"next";
static NSString * const NotifierActionLike = @"like";
static NSString * const NotifierActionDislike = @"dislike";

@implementation Notifier

- (instancetype)init {
  self = [super init];
  if (self) {
    UNUserNotificationCenter *center =
        [UNUserNotificationCenter currentNotificationCenter];
    center.delegate = self;

    UNNotificationAction *next =
        [UNNotificationAction actionWithIdentifier:NotifierActionNext
                                             title:@"Skip"
                                           options:UNNotificationActionOptionNone];
    UNNotificationAction *like =
        [UNNotificationAction actionWithIdentifier:NotifierActionLike
                                             title:@"Like"
                                           options:UNNotificationActionOptionNone];
    UNNotificationAction *removeLike =
        [UNNotificationAction actionWithIdentifier:NotifierActionLike
                                             title:@"Remove Like"
                                           options:UNNotificationActionOptionNone];
    UNNotificationAction *dislike =
        [UNNotificationAction actionWithIdentifier:NotifierActionDislike
                                             title:@"Dislike"
                                           options:UNNotificationActionOptionNone];

    UNNotificationCategory *liked =
        [UNNotificationCategory categoryWithIdentifier:NotifierCategoryLiked
                                               actions:@[next, removeLike, dislike]
                                     intentIdentifiers:@[]
                                               options:UNNotificationCategoryOptionNone];
    UNNotificationCategory *unliked =
        [UNNotificationCategory categoryWithIdentifier:NotifierCategoryUnliked
                                               actions:@[next, like, dislike]
                                     intentIdentifiers:@[]
                                               options:UNNotificationCategoryOptionNone];
    [center setNotificationCategories:[NSSet setWithObjects:liked, unliked, nil]];
  }
  return self;
}

- (void)notify:(Song *)song withImage:(NSData *)image isNew:(BOOL)isNew {
  UNUserNotificationCenter *center =
      [UNUserNotificationCenter currentNotificationCenter];

  // Keep only the current track in Notification Center.
  [center removeAllDeliveredNotifications];

  if (!PREF_KEY_BOOL(PLEASE_GROWL) ||
      (isNew && !PREF_KEY_BOOL(PLEASE_GROWL_NEW)) ||
      (!isNew && !PREF_KEY_BOOL(PLEASE_GROWL_PLAY))) {
    return;
  }

  BOOL liked = song.nrating.intValue == 1;
  UNMutableNotificationContent *content =
      [[UNMutableNotificationContent alloc] init];
  content.title = liked
      ? [NSString stringWithFormat:@"👍 %@", song.title]
      : song.title;
  content.body = [NSString stringWithFormat:@"%@\n%@", song.artist, song.album];
  content.categoryIdentifier = liked
      ? NotifierCategoryLiked
      : NotifierCategoryUnliked;

  UNNotificationRequest *request =
      [UNNotificationRequest requestWithIdentifier:@"Hermes"
                                           content:content
                                           trigger:nil];

  [center requestAuthorizationWithOptions:UNAuthorizationOptionAlert
                        completionHandler:^(BOOL granted, NSError *error) {
    if (!granted || error != nil) {
      return;
    }
    [center addNotificationRequest:request withCompletionHandler:nil];
  }];
  NSLogd(@"Playing \"%@\" by %@ from the albume \"%@\"",
         song.title, song.artist, song.album);
}

#pragma mark - UNUserNotificationCenterDelegate

- (void)userNotificationCenter:(UNUserNotificationCenter *)center
       willPresentNotification:(UNNotification *)notification
         withCompletionHandler:(void (^)(UNNotificationPresentationOptions))completionHandler {
  completionHandler(UNNotificationPresentationOptionBanner);
}

- (void)userNotificationCenter:(UNUserNotificationCenter *)center
didReceiveNotificationResponse:(UNNotificationResponse *)response
         withCompletionHandler:(void (^)(void))completionHandler {
  NSString *action = response.actionIdentifier;

  dispatch_async(dispatch_get_main_queue(), ^{
    PlaybackController *playback = [HMSAppDelegate playback];
    if ([action isEqualToString:NotifierActionNext]) {
      [playback next:self];
    } else if ([action isEqualToString:NotifierActionLike]) {
      [playback like:self];
    } else if ([action isEqualToString:NotifierActionDislike]) {
      [playback dislike:self];
    } else if ([action isEqualToString:UNNotificationDefaultActionIdentifier]) {
      [[HMSAppDelegate window] orderFront:nil];
      [NSApp activateIgnoringOtherApps:YES];
    }

    [center removeAllDeliveredNotifications];
    completionHandler();
  });
}

@end
