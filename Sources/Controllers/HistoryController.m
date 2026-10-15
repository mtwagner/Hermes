//
//  HistoryController.m
//  Hermes
//
//  Created by Alex Crichton on 10/9/11.
//

#import "HistoryController.h"
#import "FileReader.h"
#import "FMEngine/NSString+FMEngine.h"
#import "PlaybackController.h"
#import "PreferencesController.h"
#import "URLConnection.h"
#import "Notifications.h"

#define HISTORY_LIMIT 20

static const CGFloat PANEL_BORDER_WIDTH = 3.0;

@implementation HistoryController

@synthesize songs, controller;

- (void)updateCollectionItemWidth {
  CGFloat width = NSWidth(collection.enclosingScrollView.contentView.bounds);
  if (width <= 0.0) return;

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
  NSSize itemSize = NSMakeSize(width, 41.0);
  [collection setMinItemSize:itemSize];
  [collection setMaxItemSize:itemSize];
#pragma clang diagnostic pop
}

- (void) awakeFromNib {
  [super awakeFromNib];
  historyPanel.styleMask = NSWindowStyleMaskBorderless;
  historyPanel.movableByWindowBackground = NO;
  historyPanel.hasShadow = YES;
  historyPanel.contentView.wantsLayer = YES;
  historyPanel.contentView.layer.borderWidth = PANEL_BORDER_WIDTH;
  historyPanel.contentView.layer.borderColor = NSColor.separatorColor.CGColor;
  historyPanel.contentView.layer.cornerRadius = 0.0;
  historyPanel.delegate = self;
}

- (void) loadSavedSongs {
  NSLogd(@"loading saved songs");
  NSString *historySaveStatePath = [HMSAppDelegate stateDirectory:@"history.savestate"];
  if (historySaveStatePath == nil) return;

  reader = [FileReader readerForFile:historySaveStatePath completionHandler:^(NSData *data, NSError *err) {
    if (err) return;
    assert(data != nil);

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    // Keep reading existing history files until Song adopts NSSecureCoding.
    NSArray *s = [NSKeyedUnarchiver unarchiveObjectWithData:data];
#pragma clang diagnostic pop
    for (Song *song in s) {
      if ([self->songs indexOfObject:song] == NSNotFound)
        [self->controller addObject:song];
    }

    self->reader = nil;
  }];
  [reader start];
}

- (void) insertObject:(Song *)s inSongsAtIndex:(NSUInteger)index {
  [songs insertObject:s atIndex:index];
}

- (void) removeObjectFromSongsAtIndex:(NSUInteger)index {
  [songs removeObjectAtIndex:index];
}

- (void) addSong:(Song *)song {
  if (songs == nil) {
    [self loadSavedSongs];
    songs = [NSMutableArray array];
  }
  [self insertObject:song inSongsAtIndex:0];

  [[NSDistributedNotificationCenter defaultCenter]
    postNotificationName:HistoryControllerDidPlaySongDistributedNotification
                  object:@"hermes"
                userInfo:[song toDictionary]
                deliverImmediately: YES];

  while ([songs count] > HISTORY_LIMIT) {
    [self removeObjectFromSongsAtIndex:HISTORY_LIMIT];
  }
}

- (BOOL) saveSongs {
  NSString *path = [HMSAppDelegate stateDirectory:@"history.savestate"];
  if (path == nil) {
    return NO;
  }

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
  // Preserve compatibility with existing history files for now.
  BOOL saved = [NSKeyedArchiver archiveRootObject:songs toFile:path];
#pragma clang diagnostic pop
  return saved;
}

- (Song*) selectedItem {
  NSUInteger selection = [controller selectionIndex];
  if (selection == NSNotFound) {
    return nil;
  }
  return songs[selection];
}

- (Pandora*) pandora {
  return [HMSAppDelegate pandora];
}

- (void) setEnabledState:(BOOL)enabled allowRating:(BOOL)ratingEnabled {
  [pandoraSong setEnabled:enabled];
  [pandoraArtist setEnabled:enabled];
  [pandoraAlbum setEnabled:enabled];
  [lyrics setEnabled:enabled];
  [like setEnabled:ratingEnabled];
  [dislike setEnabled:ratingEnabled];
}

- (void) updateUI {
  Song *song = [self selectedItem];
  int rating = 0;
  if (song && [[song station] shared]) {
    [self setEnabledState:YES allowRating:NO];
  }
  else if (song) {
    [self setEnabledState:YES allowRating:YES];
    rating = [[song nrating] intValue];
  }
  else {
    [self setEnabledState:NO allowRating:NO];
  }

  if (rating == -1) {
    [like setState:NSControlStateValueOff];
    [dislike setState:NSControlStateValueOn];
  }
  else if (rating == 0) {
    [like setState:NSControlStateValueOff];
    [dislike setState:NSControlStateValueOff];
  }
  else if (rating == 1) {
    [like setState:NSControlStateValueOn];
    [dislike setState:NSControlStateValueOff];
  }
}

- (IBAction) dislikeSelected:(id)sender {
  Song* song = [self selectedItem];
  if (!song) return;
  [[HMSAppDelegate playback] rate:song as:NO];
}

- (IBAction) likeSelected:(id)sender {
  Song* song = [self selectedItem];
  if (!song) return;
  [[HMSAppDelegate playback] rate:song as:YES];
}

- (IBAction)gotoSong:(id)sender {
  Song* s = [self selectedItem];
  if (s == nil) return;
  NSURL *url = [NSURL URLWithString:[s titleUrl]];
  [[NSWorkspace sharedWorkspace] openURL:url];
}

- (IBAction)gotoArtist:(id)sender {
  Song* s = [self selectedItem];
  if (s == nil) return;
  NSURL *url = [NSURL URLWithString:[s artistUrl]];
  [[NSWorkspace sharedWorkspace] openURL:url];
}

- (IBAction)gotoAlbum:(id)sender {
  Song* s = [self selectedItem];
  if (s == nil) return;
  NSURL *url = [NSURL URLWithString:[s albumUrl]];
  [[NSWorkspace sharedWorkspace] openURL:url];
}

- (void)windowDidResize:(NSNotification *)notification {
  if (notification.object != historyPanel) return;
  [self updateCollectionItemWidth];
  NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
  [defaults setInteger:historyPanel.contentView.frame.size.width
                forKey:HIST_DRAWER_WIDTH];
}

- (void)windowWillClose:(NSNotification *)notification {
  if (notification.object != historyPanel) return;
  PREF_KEY_SET_INT(OPEN_DRAWER, DRAWER_NONE_HIST);
}

- (void) showDrawer {
  NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
  NSInteger savedWidth = [defaults integerForKey:HIST_DRAWER_WIDTH];
  if (savedWidth > 0) {
    NSSize contentSize = historyPanel.contentView.frame.size;
    contentSize.width = savedWidth;
    [historyPanel setContentSize:contentSize];
  }
  [self updateCollectionItemWidth];

  NSWindow *mainWindow = [HMSAppDelegate window];
  NSRect mainFrame = mainWindow.frame;
  NSRect panelFrame = historyPanel.frame;
  panelFrame.size.height = NSHeight(mainFrame) * 0.8;
  [historyPanel setFrame:panelFrame display:YES];
  panelFrame = historyPanel.frame;
  NSRect visibleFrame = (mainWindow.screen ?: NSScreen.mainScreen).visibleFrame;
  CGFloat panelX = NSMaxX(mainFrame) - PANEL_BORDER_WIDTH;
  if (panelX + NSWidth(panelFrame) > NSMaxX(visibleFrame)) {
    panelX = NSMinX(mainFrame) - NSWidth(panelFrame) + PANEL_BORDER_WIDTH;
  }
  CGFloat panelY = NSMidY(mainFrame) - NSHeight(panelFrame) / 2.0;
  panelY = MAX(NSMinY(visibleFrame),
               MIN(panelY, NSMaxY(visibleFrame) - NSHeight(panelFrame)));
  [historyPanel setFrameOrigin:NSMakePoint(panelX, panelY)];

  if (historyPanel.parentWindow != mainWindow) {
    [historyPanel.parentWindow removeChildWindow:historyPanel];
    [mainWindow addChildWindow:historyPanel ordered:NSWindowBelow];
  }
  [historyPanel makeKeyAndOrderFront:nil];
  [self focus];
}

- (void) hideDrawer {
  [historyPanel.parentWindow removeChildWindow:historyPanel];
  [historyPanel close];
}

- (void) focus {
  [historyPanel makeFirstResponder:collection];
}

- (IBAction) showLyrics:(id)sender {
  Song* s = [self selectedItem];
  if (s == nil) return;
  NSString *surl =
    [NSString
      stringWithFormat:@"http://lyrics.wikia.com/api.php?action=lyrics&artist=%@&song=%@&fmt=realjson",
      [[s artist] urlEncoded], [[s title] urlEncoded]];
  NSURL *url = [NSURL URLWithString:surl];
  NSURLRequest *req = [NSURLRequest requestWithURL:url];
  NSLogd(@"Fetch: %@", surl);
  URLConnection *conn = [URLConnection connectionForRequest:req
                                          completionHandler:^(NSData *d, NSError *err) {
    if (err == nil) {
      NSDictionary *object = [NSJSONSerialization JSONObjectWithData:d options:0 error:&err];
      if (err == nil) {
        NSString *url = object[@"url"];
        [self->spinner setHidden:YES];
        [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:url]];
        return;
      }
    }
    NSAlert *alert = [NSAlert alertWithError:err];
    alert.messageText = @"Couldn't open lyrics";
    alert.informativeText = [err localizedDescription];
    [alert beginSheetModalForWindow:[HMSAppDelegate window] completionHandler:nil];
  }];

  [conn setHermesProxy];
  [conn start];
  [spinner setHidden:NO];
}

@end
