//
//  Monitor.m
//  DoNotDisturb
//
//  Created by Patrick Wardle on 9/25/14.
//  Copyright (c) 2026 Objective-See. All rights reserved.
//

#import "Consts.h"
#import "Process.h"
#import "Monitor.h"
#import "Utilities.h"
#import "Preferences.h"

#import <libproc.h>
#import <sys/proc.h>

#import <IOKit/IOKitLib.h>
#import <IOKit/pwr_mgt/IOPM.h>
#import <SystemConfiguration/SystemConfiguration.h>


/* GLOBALS */

//log handle
extern os_log_t logHandle;

//glboal prefs obj
extern Preferences* preferences;

//endpoint security client
es_client_t* esClient = nil;

//last state
// sometimes multiple notifications are delivered!?
LidState lastLidState;

//callback for power/lid events
static void pmDomainChange(void *refcon, io_service_t service, uint32_t messageType, void *messageArgument)
{
    // recover the lid object
    Monitor* monitor = (__bridge Monitor *)refcon;
    
    //lid state
    uint32_t lidState = stateUnavailable;
    
    //sleep bit
    uint32_t sleepState = stateUnavailable;
    
    //timestamp
    NSDate* timestamp = nil;
    
    //init timestamp
    timestamp = [NSDate date];
    
    //ignore any messages that aren't related to lid state
    if(kIOPMMessageClamshellStateChange != messageType) {
        goto bail;
    }
    
    //dbg msg
    os_log_debug(logHandle, "got 'kIOPMMessageClamshellStateChange' message");
    
    //are we disabled?
    if([preferences.preferences[PREF_IS_DISABLED] boolValue])
    {
        os_log_debug(logHandle, "user disabled DND, so ignoring lid event");
        goto bail;
    }
    
    // ignore if external display is active (covers clamshell + docked scenarios)
    if( (YES == [monitor isExternalDisplayActive]) &&
        (NO  == [monitor.xpcUserClient isScreenLocked]) )
    {
        os_log_info(logHandle, "external display active + screen unlocked, ignoring event");
        goto bail;
    }
    
    //get state
    lidState = ((uintptr_t)messageArgument & kClamshellStateBit);
    
    //get sleep state
    sleepState = !!(((uintptr_t)messageArgument & kClamshellSleepBit));
    
    //dbg msg
    os_log_debug(logHandle, "lid state: %{public}@ (sleep bit: %d)", (lidState) ? @"closed" : @"open", sleepState);
    
    //(new) open?
    // OS sometimes delivers 2x events, so ignore same same
    if( (stateOpen == lidState) &&
        (stateOpen != lastLidState) )
    {
        //ignore if lid isn't really open
        // on reboot, OS may deliver 'open' message if external monitors are connected
        if(stateOpen != getLidState())
        {
            //bail
            goto bail;
        }
        
        //update 'prev' state
        lastLidState = stateOpen;
        
        //dbg msg
        // log to file
        os_log_info(logHandle, "[NEW EVENT] lid state: open (sleep state: %d)", sleepState);
        
        //touch id mode?
        // wait up to 5 seconds, and ignore event if user auth'd via biometrics
        if(YES == [preferences.preferences[PREF_TOUCH_ID_MODE] boolValue])
        {
            //dbg msg
            os_log_debug(logHandle, "'touch ID' mode enabled, waiting for biometric auth event");
            
            //wait for touch ID
            if(YES == [monitor waitForTouchID:5.0])
            {
                os_log_info(logHandle, "user authenticated via touch ID, ignoring event");
                goto bail;
            }
        }
        
        //process event
        // report to user, execute actions, etc.
        [monitor processEvent:timestamp];
    }
    
    //(new) close?
    // OS sometimes delivers 2x events, so ignore same same
    else if( (stateClosed == lidState) &&
             (stateClosed != lastLidState) )
    {
        //update 'prev' state
        lastLidState = stateClosed;
        
        //dbg msg
        os_log_info(logHandle, "[NEW EVENT] lid state: closed (sleep state: %d)", sleepState);
    }
    
bail:
    
    return;
}


@implementation Monitor

//init function
-(id)init {
    
    //init super
    self = [super init];
    if(nil != self) {
        
        //init to current state
        lastLidState = getLidState();
        
        //init user xpc client
        self.xpcUserClient = [[XPCUserClient alloc] init];
        
        //init telegram obj
        // only used it user enables/configures
        self.telegram = [[Telegram alloc] init];

    }

    return self;
}

//register for lid notifications
-(BOOL)start
{
    //return var
    BOOL registered = NO;
    
    //status var
    kern_return_t status = kIOReturnError;
    
    //root domain for power management
    io_service_t powerManagementRD = MACH_PORT_NULL;
    
    //already running? stop first to avoid leaking resources
    if(running) {
        [self stop];
    }
    
    //dbg msg
    os_log_debug(logHandle, "registering for lid notifications");
    
    //make sure state is ok
    if(stateUnavailable == getLidState())
    {
        //err msg
        os_log_error(logHandle, "failed to get lid state, so aborting lid notifications registration");
        
        //error
        goto bail;
    }

    //create queue
    dispatchQ = dispatch_queue_create(NULL, DISPATCH_QUEUE_SERIAL);
    if(NULL == dispatchQ)
    {
        //err msg
        os_log_error(logHandle, "failed to create dispatch queue for lid notifications");
        
        //error
        goto bail;
    }
    
    //set target
    dispatch_set_target_queue(dispatchQ, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0));
    
    //create notification port
    notificationPort = IONotificationPortCreate(kIOMasterPortDefault);
    if(NULL == notificationPort)
    {
        //err msg
        os_log_error(logHandle, "failed to create notification port for lid notifications");
        
        //error
        goto bail;
    }
    
    //set dispatch queue
    IONotificationPortSetDispatchQueue(notificationPort, dispatchQ);
    
    //get matching service for power management root domain
    powerManagementRD = IOServiceGetMatchingService(kIOMasterPortDefault, IOServiceMatching("IOPMrootDomain"));
    if(0 == powerManagementRD)
    {
        //err msg
        os_log_error(logHandle, "failed to get power management root domain for lid notifications");
        
        //error
        goto bail;
    }
    
    //add interest notification
    status = IOServiceAddInterestNotification(notificationPort, powerManagementRD, kIOGeneralInterest,
                                     pmDomainChange, (__bridge void *)self, &notification);
    if(KERN_SUCCESS != status)
    {
        //err msg
        os_log_error(logHandle, "failed to get add interest notifcation for lid notifications (error: 0x:%x)", status);
        
        //error
        goto bail;
    }
    
    
    //happy
    registered = YES;
    running = YES;

bail:

    //release
    if(MACH_PORT_NULL != powerManagementRD)
    {
        //release
        IOObjectRelease(powerManagementRD);
        
        //unset
        powerManagementRD = MACH_PORT_NULL;
    }
    
    return registered;
}


//unregister for notifications
-(void)stop
{
    //dbg msg
    os_log_debug(logHandle, "unregistering lid notifications");
    
    //not running?
    if(!running) return;
    
    //mark stopped
    running = NO;
    
    //have a dispatch queue?
    // serialize teardown with in-flight callbacks
    if(NULL != dispatchQ)
    {
        dispatch_queue_t q = dispatchQ;
        dispatch_sync(q, ^{
            [self teardownIOKit];
        });
        dispatchQ = NULL;
    }
    else
    {
        //no queue, just clean up directly
        [self teardownIOKit];
    }
    
    return;
}

//teardown IOKit resources
// must be called on dispatchQ (or when dispatchQ is NULL)
-(void)teardownIOKit
{
    //release notification
    if(0 != notification)
    {
        IOObjectRelease(notification);
        notification = 0;
        
        os_log_debug(logHandle, "released service interest notification");
    }
    
    //destroy notification port
    if(NULL != notificationPort)
    {
        IONotificationPortSetDispatchQueue(notificationPort, NULL);
        IONotificationPortDestroy(notificationPort);
        notificationPort = NULL;
        
        os_log_debug(logHandle, "destroyed notification port");
    }
}


// Returns YES if any external (non-built-in) display is active
-(BOOL)isExternalDisplayActive
{
    uint32_t displayCount = 0;

    // first call: get count
    CGGetActiveDisplayList(0, NULL, &displayCount);
    if(displayCount == 0) return NO;

    // second call: get display IDs
    CGDirectDisplayID displays[displayCount];
    CGGetActiveDisplayList(displayCount, displays, &displayCount);

    for(uint32_t i = 0; i < displayCount; i++)
    {
        // built-in display (MacBook screen) returns YES
        // external monitor returns NO
        if(NO == CGDisplayIsBuiltin(displays[i]))
        {
            return YES;
        }
    }

    return NO;
}

//wait for a touch ID auth event
-(BOOL)waitForTouchID:(NSTimeInterval)timeout
{
    __block BOOL touchIDSeen     = NO;
    dispatch_semaphore_t sem     = dispatch_semaphore_create(0);
    es_client_t *client          = NULL;

    //init ES client
    if(ES_NEW_CLIENT_RESULT_SUCCESS != es_new_client(&client, ^(es_client_t *c,
                                                                 const es_message_t *msg) {
        //only care about auth events
        if(msg->event_type != ES_EVENT_TYPE_NOTIFY_AUTHENTICATION) return;

        //only care about Touch ID successes
        if(msg->event.authentication->type    != ES_AUTHENTICATION_TYPE_TOUCHID) return;
        if(msg->event.authentication->success != YES) return;

        //got one — signal and bail
        touchIDSeen = YES;
        dispatch_semaphore_signal(sem);

    })) {
        //failed
        os_log_error(logHandle, "waitForTouchID: es_new_client failed");
        return NO;
    }

    //subscribe
    es_event_type_t events[] = { ES_EVENT_TYPE_NOTIFY_AUTHENTICATION };
    if(ES_RETURN_SUCCESS != es_subscribe(client, events, 1))
    {
        //failed
        os_log_error(logHandle, "waitForTouchID: es_subscribe failed");
        
        //cleanup
        es_delete_client(client);
        return NO;
    }

    //wait — returns early if semaphore is signalled
    dispatch_time_t deadline = dispatch_time(DISPATCH_TIME_NOW,
                                             (int64_t)(timeout * NSEC_PER_SEC));
    dispatch_semaphore_wait(sem, deadline);

    //always clean up
    es_unsubscribe_all(client);
    es_delete_client(client);

    return touchIDSeen;
}

//proces lid open event
// report to user, execute cmd, send alert to server, etc
-(void)processEvent:(NSDate*)timestamp {
    
    //alert
    NSDictionary* alert = @{ALERT_TIMESTAMP:timestamp};
    
    //persistently log
    os_log(logHandle, "⚠️ DoNotDisturb Alert: Lid Opened");
    
    //send *local* alert to user?
    if(![preferences.preferences[PREF_PASSIVE_MODE] boolValue]) {
        
        //deliver (local) alert
        if(![self.xpcUserClient deliverAlert:alert]) {
            os_log_debug(logHandle, "failed to deliver alert to user (no client?)");
        }
        else {
            os_log_debug(logHandle, "delivered (local) alert to user");
        }
    }
    else {
        os_log_debug(logHandle, "in passive mode, so not delivering (local) alert");
    }
    
    //send *remote* alert via Telegram?
    if(preferences.preferences[PREF_CHAT_ID]){
        
        NSString *botToken = preferences.preferences[PREF_BOT_TOKEN];
        NSString *chatID   = preferences.preferences[PREF_CHAT_ID];

        NSData* image = nil;

        //include image?
        if([preferences.preferences[PREF_ALERT_IMAGE_MODE] boolValue]) {
            
            image = [self.xpcUserClient captureImage];
            if(!image.length) {
                os_log_debug(logHandle, "failed to capture image");
            }
            else {
                os_log_debug(logHandle, "captured image");
            }
        }
        else {
            os_log_debug(logHandle, "in 'non-image mode', so no image captured");
        }

        //build caption
        NSString *caption = [NSString stringWithFormat:@"⚠️ DoNotDisturb Alert: Lid opened\n%@", timestamp];

        //send alert + optional image to Telegram
        [self.telegram sendAlertWithBotID:botToken
                                    chatID:chatID
                                   caption:caption
                                     image:image
                                completion:nil];
    }
    else {
        os_log_debug(logHandle, "remote alerts (via Telegram) not configured, so won't deliver remote alert");
    }
    
    //execute cmd?
    if([preferences.preferences[PREF_EXECUTE_ACTION] boolValue])
    {
        NSString* action = preferences.preferences[PREF_EXECUTE_PATH];
        if(action.length) {
    
            os_log(logHandle, "executing: %{public}@", action);
            
            //execute action via login item
            NSInteger result = [self.xpcUserClient executeAction:action];
            if(result != 0) {
                os_log_error(logHandle, "ERROR: failed with execute %{public}@ (error: %ld)", action, (unsigned long)result);
            }
            else {
                os_log_debug(logHandle, "executed %{public}@", action);
            }
        }
    }
    
    return;
}

@end
