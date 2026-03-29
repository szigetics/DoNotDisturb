//
//  file: XPCDaemon.m
//  project: DoNotDisturb (launch daemon)
//  description: interface for XPC methods, invoked by user
//
//  created by Patrick Wardle
//  copyright (c) 2026 Objective-See. All rights reserved.
//

#import "consts.h"
#import "Monitor.h"
#import "XPCDaemon.h"
#import "utilities.h"
#import "Preferences.h"

/* GLOBALS */

//global monitor obj
extern Monitor* monitor;

//log handle
extern os_log_t logHandle;

//global prefs obj
extern Preferences* preferences;

@implementation XPCDaemon

//load preferences and send them back to client
-(void)getPreferences:(void (^)(NSDictionary* preferences))reply {
    
    os_log_debug(logHandle, "XPC request: '%s'", __PRETTY_FUNCTION__);
    
    //reply
    reply(preferences.preferences);
    
}

//update preferences
-(void)updatePreferences:(NSDictionary *)updates reply:(void (^)(NSDictionary* preferences))reply {
    
    os_log_debug(logHandle, "XPC request: '%s' (%{public}@)", __PRETTY_FUNCTION__, updates);
    
    //update
    if(YES != [preferences update:updates]) {
        os_log_error(logHandle, "ERROR: failed to updates to preferences");
    }
    
    reply(preferences.preferences);
}

//quit
-(void)quit {
    
    os_log_debug(logHandle, "XPC request: '%s'", __PRETTY_FUNCTION__);

    //stop monitor
    [monitor stop];
    
    os_log_debug(logHandle, "monitor stopped ...now exiting");
    
    //bye
    exit(0);
}

@end
