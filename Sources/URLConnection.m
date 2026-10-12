#import "PreferencesController.h"
#import "URLConnection.h"

NSString * const URLConnectionProxyValidityChangedNotification = @"URLConnectionProxyValidityChangedNotification";

// Private class extension to handle the modern NSURLSession properties safely
@interface URLConnection ()

@property (nonatomic, strong) NSURLRequest *request;
@property (nonatomic, copy) URLConnectionCallback completionHandler;
@property (nonatomic, strong) NSURLSession *session;
@property (nonatomic, strong) NSURLSessionDataTask *task;

@end

@implementation URLConnection

/**
 * @brief Creates a new instance for the specified request
 */
+ (URLConnection*) connectionForRequest:(NSURLRequest*)request
                      completionHandler:(URLConnectionCallback)cb {

    URLConnection *c = [[URLConnection alloc] init];
    c.request = request;
    c.completionHandler = cb;
    
    [c configureSessionTask];
    
    return c;
}

/**
 * @brief Configures the NSURLSession with the appropriate proxy settings
 */
- (void) configureSessionTask {
    NSURLSessionConfiguration *configuration = [NSURLSessionConfiguration defaultSessionConfiguration];
    
    switch (PREF_KEY_INT(ENABLED_PROXY)) {
        case PROXY_HTTP: {
            NSString *host = PREF_KEY_VALUE(PROXY_HTTP_HOST);
            NSInteger port = PREF_KEY_INT(PROXY_HTTP_PORT);
            
            if ([URLConnection validProxyHost:&host port:port]) {
                configuration.connectionProxyDictionary = @{
                    (id)kCFNetworkProxiesHTTPEnable:  @YES,
                    (id)kCFNetworkProxiesHTTPProxy:   host,
                    (id)kCFNetworkProxiesHTTPPort:    @(port),
                    (id)kCFNetworkProxiesHTTPSEnable: @YES,
                    (id)kCFNetworkProxiesHTTPSProxy:  host,
                    (id)kCFNetworkProxiesHTTPSPort:   @(port)
                };
            }
            break;
        }
            
        case PROXY_SOCKS: {
            NSString *host = PREF_KEY_VALUE(PROXY_SOCKS_HOST);
            NSInteger port = PREF_KEY_INT(PROXY_SOCKS_PORT);
            
            if ([URLConnection validProxyHost:&host port:port]) {
                configuration.connectionProxyDictionary = @{
                    (id)kCFNetworkProxiesSOCKSEnable: @YES,
                    (id)kCFNetworkProxiesSOCKSProxy:  host,
                    (id)kCFNetworkProxiesSOCKSPort:   @(port)
                };
            }
            break;
        }
            
        case PROXY_SYSTEM:
        default:
            configuration.connectionProxyDictionary = nil;
            break;
    }
    
    // Replaces your 10-second manual NSTimer timeout logic safely
    configuration.timeoutIntervalForRequest = 10.0;
    
    self.session = [NSURLSession sessionWithConfiguration:configuration];

    // Pandora does not retain these short-lived connection objects. Keep the
    // connection alive through its task, then explicitly break that cycle.
    URLConnection *connection = self;
    self.task = [self.session dataTaskWithRequest:self.request
                                completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            URLConnectionCallback completionHandler = connection.completionHandler;
            NSURLSession *session = connection.session;

            connection.completionHandler = nil;
            connection.task = nil;
            connection.session = nil;
            [session finishTasksAndInvalidate];

            if (completionHandler) {
                completionHandler(data, error);
            }
        });
    }];
}

/**
 * @brief Start sending this request to the server
 */
- (void) start {
    if (self.task) {
        [self.task resume];
    } else {
        NSError *error = [NSError errorWithDomain:@"URLConnectionErrorDomain"
                                             code:-1
                                         userInfo:@{NSLocalizedDescriptionKey: @"Task failed to initialize."}];
        if (self.completionHandler) {
            self.completionHandler(nil, error);
        }
    }
}

// Kept stubbed to prevent link errors if external files call it
- (void) setHermesProxy {
    // Intentionally no-op: Proxies are now handled at session configuration initialization
}

// Kept stubbed to prevent link errors if external files call it
+ (void) setHermesProxy:(CFReadStreamRef)stream {
    // Intentionally no-op: Legacy streams are no longer used
}

+ (BOOL)validProxyHost:(NSString **)host port:(NSInteger)port {
    static BOOL wasValid = YES;
    *host = [*host stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceCharacterSet];
    
    BOOL isValid = (port > 0 && port <= 65535 && *host != nil && [*host length] > 0);
    
    if (isValid != wasValid) {
        [[NSNotificationCenter defaultCenter] postNotificationName:URLConnectionProxyValidityChangedNotification
                                                            object:nil
                                                          userInfo:@{@"isValid": @(isValid)}];
        wasValid = isValid;
    }
    return isValid;
}

@end
