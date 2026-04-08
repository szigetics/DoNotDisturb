//
//  file: XPCUser.m
//  project: DoNotDisturb (login item)
//  description: user XPC methods
//
//  created by Patrick Wardle
//  copyright (c) 2026 Objective-See. All rights reserved.
//

@import OSLog;

#import "consts.h"
#import "Camera.h"
#import "XPCUser.h"
#import "utilities.h"
#import "AppDelegate.h"

/* GLOBALS */

//log handle
extern os_log_t logHandle;

//alert (windows)
extern NSMutableDictionary* alerts;

@implementation XPCUser

//show an alert window
-(void)alertShow:(NSDictionary*)alert
{
    //notification
    NSUserNotification* notification = nil;
    
    //dbg msg
    os_log_debug(logHandle, "XPC request from daemon: alert show");
    
    //alloc notification
    notification = [[NSUserNotification alloc] init];
    
    //set other button title
    notification.otherButtonTitle = @"Dismiss";
    
    //remove action button
    notification.hasActionButton = NO;
    
    //set title
    notification.title = @"⚠️ DoNotDisturb Alert";
    
    //set subtitle
    notification.subtitle = [NSString stringWithFormat:@"Lid opened at %@", alert[ALERT_TIMESTAMP]];
    
    //set delegate to self
    NSUserNotificationCenter.defaultUserNotificationCenter.delegate =self;
    
    //show alert on main thread
    dispatch_async(dispatch_get_main_queue(), ^{
        
        //deliver notification
        [NSUserNotificationCenter.defaultUserNotificationCenter deliverNotification:notification];
        
    });
    
    return;
}

//return screen locked status
-(void)isScreenLocked:(void (^)(BOOL locked))reply{
    
    //must access NSApp.delegate on main thread
    dispatch_async(dispatch_get_main_queue(), ^{
        
        //send back
        reply(((AppDelegate*)NSApp.delegate).screenLocked);
    });
}

//XPC method
// capture an image from the webcam
-(void)captureImage:(void (^)(NSData *))reply {
    
    NSData* image = nil;
    Camera* camera = nil;
    
    os_log_debug(logHandle, "XPC request from daemon: capture picture");
    
    //init camera
    camera = [[Camera alloc] init];
    
    //grab image
    image = [camera captureImage];

    //send back
    reply(image);
    
    return;
}

//exec (user specified) action
// run via /bin/sh -c so commands, scripts, and binaries all work
-(void)executeAction:(NSString*)action reply:(void (^)(NSInteger))reply
{
    int result = -1;
    
    os_log_debug(logHandle, "executing %{public}@", action);
    
    //exec via shell
    NSDictionary *results = execTask(@"/bin/sh", @[@"-c", action], YES, NO);
    
    os_log_debug(logHandle, "executed %{public}@, results: %{public}@", action, results);
    
    if(nil != results[EXIT_CODE]) {
        result = [results[EXIT_CODE] intValue];
    }
    
    reply(result);
}
    
@end
