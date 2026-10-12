#import <Foundation/Foundation.h>

// Retain the exact block typedef from your original code
typedef void(^URLConnectionCallback)(NSData*, NSError*);

extern NSString * const URLConnectionProxyValidityChangedNotification;

@interface URLConnection : NSObject {
    // We keep these legacy ivars defined so the binary/compiler interface
    // remains a strict drop-in match, but they will go unused under the hood.
    CFReadStreamRef stream;
    URLConnectionCallback cb;
    NSMutableData *bytes;
    NSTimer *timeout;
    int events;
}

// Public class methods matching your exact signatures
+ (URLConnection*) connectionForRequest:(NSURLRequest*)request
                      completionHandler:(URLConnectionCallback) cb;

+ (void) setHermesProxy:(CFReadStreamRef) stream;
+ (BOOL) validProxyHost:(NSString **)host port:(NSInteger)port;

// Public instance methods matching your exact signatures
- (void) start;
- (void) setHermesProxy;

@end
