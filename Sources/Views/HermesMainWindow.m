//
//  HermesMainWindow.m
//  Hermes
//
//  Created by Nicholas Riley on 9/10/16.
//
//

#import "HermesMainWindow.h"

@implementation HermesMainWindow

- (void)sendEvent:(NSEvent *)theEvent {
  if ([theEvent type] == NSEventTypeKeyDown) {

    // don't ever let space bar get through to the field editor so it can be used for play/pause
    if ([[theEvent characters] isEqualToString:@" "] && ([theEvent modifierFlags] & NSEventModifierFlagDeviceIndependentFlagsMask) == 0) {
      [[NSApp mainMenu] performKeyEquivalent:theEvent];
      return;
    }
  }
  [super sendEvent:theEvent];
}

@end

@implementation HermesPanel

- (BOOL)canBecomeKeyWindow {
  return YES;
}

- (void)sendEvent:(NSEvent *)event {
  if (event.type == NSEventTypeLeftMouseDown && self.parentWindow != nil) {
    NSPoint contentPoint = [self.contentView convertPoint:event.locationInWindow
                                                 fromView:nil];
    if ([self.contentView hitTest:contentPoint] == self.contentView) {
      draggingParentWindow = YES;
      dragStartScreenLocation = NSEvent.mouseLocation;
      parentStartOrigin = self.parentWindow.frame.origin;
      return;
    }
  } else if (event.type == NSEventTypeLeftMouseDragged &&
             draggingParentWindow) {
    NSPoint currentLocation = NSEvent.mouseLocation;
    NSPoint origin = NSMakePoint(
        parentStartOrigin.x + currentLocation.x - dragStartScreenLocation.x,
        parentStartOrigin.y + currentLocation.y - dragStartScreenLocation.y);
    [self.parentWindow setFrameOrigin:origin];
    return;
  } else if (event.type == NSEventTypeLeftMouseUp && draggingParentWindow) {
    draggingParentWindow = NO;
    return;
  }

  [super sendEvent:event];
}



@end
