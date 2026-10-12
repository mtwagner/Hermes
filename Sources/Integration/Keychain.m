//
//  Keychain.h
//  Hermes
//
//  Created by Alex Crichton on 11/19/11.
//

#import "Keychain.h"
#import <Security/Security.h>

static NSString * const KeychainServiceName = @"Hermes";

static NSDictionary *KeychainQuery(NSString *username) {
  return @{
    (__bridge id)kSecClass: (__bridge id)kSecClassGenericPassword,
    (__bridge id)kSecAttrService: KeychainServiceName,
    (__bridge id)kSecAttrAccount: username
  };
}

BOOL KeychainSetItem(NSString *username, NSString *password) {
  if (username == nil || password == nil) {
    return NO;
  }

  NSData *passwordData = [password dataUsingEncoding:NSUTF8StringEncoding];
  NSDictionary *query = KeychainQuery(username);
  NSDictionary *attributes = @{
    (__bridge id)kSecValueData: passwordData
  };
  OSStatus result = SecItemUpdate((__bridge CFDictionaryRef)query,
                                  (__bridge CFDictionaryRef)attributes);

  if (result == errSecItemNotFound) {
    NSMutableDictionary *item = [query mutableCopy];
    item[(__bridge id)kSecValueData] = passwordData;
    result = SecItemAdd((__bridge CFDictionaryRef)item, NULL);
  }

  return result == errSecSuccess;
}

NSString *KeychainGetPassword(NSString *username) {
  if (username == nil) {
    return nil;
  }

  NSMutableDictionary *query = [KeychainQuery(username) mutableCopy];
  query[(__bridge id)kSecReturnData] = @YES;
  query[(__bridge id)kSecMatchLimit] = (__bridge id)kSecMatchLimitOne;

  CFTypeRef result = NULL;
  OSStatus status = SecItemCopyMatching((__bridge CFDictionaryRef)query,
                                        &result);
  if (status != errSecSuccess) {
    return nil;
  }

  NSData *passwordData = CFBridgingRelease(result);
  return [[NSString alloc] initWithData:passwordData
                               encoding:NSUTF8StringEncoding];
}
