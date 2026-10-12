//
//  HermesMainWindow.h
//  Hermes
//
//  Created by Nicholas Riley on 9/10/16.
//
//

#import <Cocoa/Cocoa.h>

@interface HermesMainWindow : NSWindow

@end

@interface HermesPanel : NSPanel {
  BOOL draggingParentWindow;
  NSPoint dragStartScreenLocation;
  NSPoint parentStartOrigin;
}

@end
