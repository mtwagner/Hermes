//
//  NSString+UUID.m
//  LastFMAPI
//
//  Created by Nicolas Haunold on 4/26/09.
//  Copyright 2009 Tapolicious Software. All rights reserved.
//

// Thanks to Sam Steele / c99koder for -[NSString md5sum];

#import "NSString+FMEngine.h"
#import <CommonCrypto/CommonDigest.h>

@implementation NSString (FMEngineAdditions)

+ (NSString *)stringWithNewUUID {
    CFUUIDRef uuidObj = CFUUIDCreate(nil);

    NSString *newUUID = (__bridge_transfer NSString*)CFUUIDCreateString(nil, uuidObj);
    CFRelease(uuidObj);
    return newUUID;
}

- (NSString*) urlEncoded {
  NSMutableCharacterSet *allowed =
      [[NSCharacterSet URLQueryAllowedCharacterSet] mutableCopy];
  [allowed removeCharactersInString:@"!*'();:@&=+$,/?%#[]"];
  return [self stringByAddingPercentEncodingWithAllowedCharacters:allowed];
}

- (NSString *)md5sum {
  unsigned char digest[CC_MD5_DIGEST_LENGTH], i;
  // Last.fm requires MD5 for its API signatures, so changing the algorithm
  // would break authentication even though CommonCrypto marks MD5 deprecated.
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
  CC_MD5([self UTF8String],
         (CC_LONG)[self lengthOfBytesUsingEncoding:NSUTF8StringEncoding],
         digest);
#pragma clang diagnostic pop
  NSMutableString *ms = [NSMutableString string];
  for (i=0;i<CC_MD5_DIGEST_LENGTH;i++) {
    [ms appendFormat: @"%02x", (int)(digest[i])];
  }
  return [ms copy];
}

@end
