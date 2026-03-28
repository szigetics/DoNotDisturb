//
//  file: XPCUserClient.m
//  project: DoNotDisturb (launch daemon)
//  description: talk to the user, via XPC
//
//  created by Patrick Wardle
//  copyright (c) 2026 Objective-See. All rights reserved.
//

@import OSLog;

#import "consts.h"
#import "XPCListener.h"
#import "XPCUserClient.h"

/* GLOBALS */

//log handle
extern os_log_t logHandle;

//xpc connection
extern XPCListener* xpcListener;

@implementation XPCUserClient

//deliver alert to user
-(BOOL)deliverAlert:(NSDictionary*)alert
{
    //flag
    __block BOOL xpcError = NO;
    
    //dbg msg
    os_log_debug(logHandle, "invoking user XPC method: 'alertShow'");
    
    //sanity check
    // no client connection?
    if(!xpcListener.client)
    {
        //dbg msg
        os_log_debug(logHandle, "no client is connected, alert will not be delivered");
        
        //set error
        xpcError = YES;
        
        //bail
        goto bail;
    }

    //send to user (client) to display
    [[xpcListener.client synchronousRemoteObjectProxyWithErrorHandler:^(NSError * proxyError)
    {
        //set error
        xpcError = YES;
        
        //err msg
        os_log_error(logHandle, "ERROR: failed to invoke USER XPC method: 'alertShow' (error: %{public}@)", proxyError);

    }] alertShow:alert];
    
bail:

    return !xpcError;
}

//ask (login item) if screen is locked
-(NSInteger)isScreenLocked {
    
    __block NSInteger result = -1;
    
    //sync wait
    dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);
    
    os_log_debug(logHandle, "invoking user XPC method: 'isScreenLocked'");
    
    //sanity check
    if(!xpcListener.client) {
        os_log_debug(logHandle, "no client is connected...");
        return result;
    }

    //make XPC call
    [[xpcListener.client synchronousRemoteObjectProxyWithErrorHandler:^(NSError *proxyError)
    {
        os_log_error(logHandle, "ERROR: failed to invoke USER XPC method: 'isScreenLocked' (error: %{public}@)", proxyError);
        dispatch_semaphore_signal(semaphore);

    }] isScreenLocked:^(BOOL locked)
    {
        os_log_debug(logHandle, "USER XPC method 'isScreenLocked' returned: %lu", (unsigned long)locked);
        result = locked;
        dispatch_semaphore_signal(semaphore);
    }];
    
    //wait for reply
    dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER);

    return result;
}

//ask (login item) to capture image
-(NSData*)captureImage {
    
    __block NSData* result = nil;
    
    //sync wait
    dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);
    
    os_log_debug(logHandle, "invoking user XPC method: 'captureImage'");
    
    //sanity check
    if(!xpcListener.client) {
        os_log_debug(logHandle, "no client is connected...");
        return result;
    }
    
    //make XPC call
    [[xpcListener.client synchronousRemoteObjectProxyWithErrorHandler:^(NSError *proxyError)
    {
        os_log_error(logHandle, "ERROR: failed to invoke USER XPC method: 'captureImage' (error: %{public}@)", proxyError);
        dispatch_semaphore_signal(semaphore);
        
    }] captureImage:^(NSData *image)
    {
        os_log_debug(logHandle, "USER XPC method 'captureImage' returned image: %lu bytes", (unsigned long)image.length);
        
        result = image;
        dispatch_semaphore_signal(semaphore);
    }];
    
    //wait for reply
    dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER);
    
    return result;
}

//ask (login item) to execute action
-(NSInteger)executeAction:(NSString*)path {
    
    __block NSInteger result = -1;
    
    //sync wait
    dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);
    
    os_log_debug(logHandle, "invoking user XPC method: 'executeAction'");
    
    //sanity check
    if(!xpcListener.client) {
        os_log_debug(logHandle, "no client is connected...");
        return result;
    }

    //make XPC call
    [[xpcListener.client synchronousRemoteObjectProxyWithErrorHandler:^(NSError *proxyError)
    {
        os_log_error(logHandle, "ERROR: failed to invoke USER XPC method: 'executeAction' (error: %{public}@)", proxyError);
        dispatch_semaphore_signal(semaphore);

    }] executeAction:path reply:^(NSInteger response)
    {
        os_log_debug(logHandle, "USER XPC method 'executeAction' returned: %ld", (unsigned long)response);
        result = response;
        dispatch_semaphore_signal(semaphore);
    }];
    
    //wait for reply
    dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER);

    return result;
}

@end
