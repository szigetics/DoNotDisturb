//
//  Preferences.m
//  Daemon
//
//  Created by Patrick Wardle on 2/22/18.
//  Copyright © 2026 Objective-See. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "consts.h"
#import "Monitor.h"
#import "utilities.h"
#import "Preferences.h"

static NSString * const kKeychainService  = @"com.objective-see.donotdisturb.telegram";

/* GLOBALS */

//monitor obj
extern Monitor* monitor;

//log handle
extern os_log_t logHandle;

@implementation Preferences

@synthesize preferences;

//init
// loads prefs
-(id)init
{
    //super
    self = [super init];
    if(nil != self)
    {
        //load
        if(YES != [self load])
        {
            //err msg
            os_log_error(logHandle, "ERROR: failed to loads preferences from %{public}@", PREFS_FILE);
            
            //unset
            self = nil;
            
            //bail
            goto bail;
        }
    }
    
bail:
    
    return self;
}

//load prefs from disk + keychain
-(BOOL)load {
    
    //load plist (everything except credentials)
    preferences = [NSMutableDictionary dictionaryWithContentsOfFile:
                   [INSTALL_DIRECTORY stringByAppendingPathComponent:PREFS_FILE]];
    if(!self.preferences) {
        return NO;
    }
    
    //load bot/chat IDs from keychain and merge into prefs dict
    NSString* botToken  = [self readFromKeychain:PREF_BOT_TOKEN];
    if(botToken.length) {
        self.preferences[PREF_BOT_TOKEN] = botToken;
    }
    
    NSString* botName  = [self readFromKeychain:PREF_BOT_USERNAME];
    if(botName.length) {
        self.preferences[PREF_BOT_USERNAME] = botName;
    }
    
    NSString *chatID = [self readFromKeychain:PREF_CHAT_ID];
    if(chatID.length) {
        self.preferences[PREF_CHAT_ID] = chatID;
    }
    
    //dbg msg
    os_log_debug(logHandle, "loaded preferences: %{public}@", self.preferences);
    
    return YES;
}

//save prefs to disk + keychain
-(BOOL)save
{
    //save bot token to keychain (if set)
    NSString* botToken = self.preferences[PREF_BOT_TOKEN];
    if(botToken.length) {
        if(![self saveToKeychain:botToken forKey:PREF_BOT_TOKEN]) {
            os_log_error(logHandle, "ERROR: failed to save bot token to keychain");
        }
    }
    
    //save bot user name to keychain (if set)
    NSString* botUserName = self.preferences[PREF_BOT_USERNAME];
    if(botUserName.length) {
        if(![self saveToKeychain:botUserName forKey:PREF_BOT_USERNAME]) {
            os_log_error(logHandle, "ERROR: failed to save bot user name to keychain");
        }
    }

    //save chat id to keychain (if set)
    NSString* chatID = self.preferences[PREF_CHAT_ID];
    if(chatID.length) {
        if(![self saveToKeychain:chatID forKey:PREF_CHAT_ID]) {
            os_log_error(logHandle, "ERROR: failed to save chat ID to keychain");
        }
    }
    
    //sanitize prefs (no telegram info)
    NSMutableDictionary* sanitizedPrefs = [self.preferences mutableCopy];
    [sanitizedPrefs removeObjectForKey:PREF_BOT_TOKEN];
    [sanitizedPrefs removeObjectForKey:PREF_BOT_USERNAME];
    [sanitizedPrefs removeObjectForKey:PREF_CHAT_ID];
    
    //save (sanitized) prefs
    return [sanitizedPrefs writeToFile:[INSTALL_DIRECTORY stringByAppendingPathComponent:PREFS_FILE]
                       atomically:YES];
}

//update prefs
// handles logic for specific prefs & then saves
-(BOOL)update:(NSDictionary*)updates {
    
    //dbg msg
    os_log_debug(logHandle, "updating preferences (%{public}@)", updates);
    
    //user setting state?
    if(nil != updates[PREF_IS_DISABLED])
    {
        //dbg msg
        os_log_debug(logHandle, "client toggling DoNotDisturb state: %{public}@", updates[PREF_IS_DISABLED]);
        
        //disable?
        if([updates[PREF_IS_DISABLED] boolValue]) {
            
            //log msg
            os_log(logHandle, "disabling DoNotDisturb");
            
            //stop
            [monitor stop];
        }
        
        //enable?
        else {
            
            //log
            os_log(logHandle, "enabling DoNotDisturb");
            
            //start
            [monitor start];
        }
    }
    
    //process updates: handle NSNull removals first, then add real values
    for(NSString *key in updates) {
        if(updates[key] == [NSNull null]) {
            //remove from prefs and keychain
            [self.preferences removeObjectForKey:key];
            deleteFromKeychain(key);
        } else {
            self.preferences[key] = updates[key];
        }
    }
    
    //save
    if(![self save]) {
        os_log_error(logHandle, "ERROR: failed to save preferences");
        return NO;
    }
    
    return YES;
}

//read item from keychain
-(NSString *)readFromKeychain:(NSString *)key {
    
    NSDictionary *query = @{
        (__bridge id)kSecClass:        (__bridge id)kSecClassGenericPassword,
        (__bridge id)kSecAttrService:  kKeychainService,
        (__bridge id)kSecAttrAccount:  key,
        (__bridge id)kSecReturnData:   @YES,
        (__bridge id)kSecMatchLimit:   (__bridge id)kSecMatchLimitOne,
    };

    CFTypeRef result = NULL;
    OSStatus status = SecItemCopyMatching((__bridge CFDictionaryRef)query, &result);

    if (status == errSecSuccess && result) {
        NSData *data = (__bridge_transfer NSData *)result;
        return [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    }
    return nil;
}

//save item to keychain
-(BOOL)saveToKeychain:(NSString *)value forKey:(NSString *)key {

    NSData *data = [value dataUsingEncoding:NSUTF8StringEncoding];

    NSDictionary *query = @{
        (__bridge id)kSecClass:       (__bridge id)kSecClassGenericPassword,
        (__bridge id)kSecAttrService: kKeychainService,
        (__bridge id)kSecAttrAccount: key,
    };
    NSDictionary *update = @{
        (__bridge id)kSecValueData:     data,
        (__bridge id)kSecAttrAccessible: (__bridge id)kSecAttrAccessibleAfterFirstUnlock,
    };

    OSStatus status = SecItemUpdate((__bridge CFDictionaryRef)query,
                                    (__bridge CFDictionaryRef)update);
    if (status == errSecItemNotFound) {
        NSMutableDictionary *add = [query mutableCopy];
        add[(__bridge id)kSecValueData]     = data;
        add[(__bridge id)kSecAttrAccessible] = (__bridge id)kSecAttrAccessibleAfterFirstUnlock;
        status = SecItemAdd((__bridge CFDictionaryRef)add, NULL);
    }

    return status == errSecSuccess;
}

@end
