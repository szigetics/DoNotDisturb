//
//  Monitor.h
//  DoNotDisturb
//
//  Created by Patrick Wardle on 9/25/14.
//  Copyright (c) 2026 Objective-See. All rights reserved.
//

@import Foundation;

#import "XPCUserProto.h"
#import "XPCUserClient.h"

#import "Process.h"
#import "Telegram.h"
#import "utilities.h"
#import <bsm/libbsm.h>
#import <EndpointSecurity/EndpointSecurity.h>


@import OSLog;

@interface Monitor : NSObject
{
    //lid state
    LidState lidState;
    
    //dispatch queue
    dispatch_queue_t dispatchQ;
    
    //notification port
    IONotificationPortRef notificationPort;
    
    //notification object
    io_object_t notification;

}

/* PROPERTIES */

@property(nonatomic, retain)Telegram* telegram;
@property(nonatomic, retain)XPCUserClient* xpcUserClient;


/* METHODS */

-(void)stop;
-(BOOL)start;
-(BOOL)isExternalDisplayActive;
-(BOOL)waitForTouchID:(NSTimeInterval)timeout;
-(void)processEvent:(NSDate*)timestamp user:(NSString*)user;

@end
