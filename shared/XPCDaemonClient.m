//
//  file: XPCDaemonClient.m
//  project: DoNotDisturb (shared)
//  description: talk to daemon via XPC (header)
//
//  created by Patrick Wardle
//  copyright (c) 2026 Objective-See. All rights reserved.
//

@import OSLog;

#import "consts.h"
#import "XPCUser.h"
#import "utilities.h"
#import "AppDelegate.h"
#import "XPCUserProto.h"
#import "XPCDaemonClient.h"

/* GLOBALS */

//log handle
extern os_log_t logHandle;

//alert (windows)
extern NSMutableDictionary* alerts;

@implementation XPCDaemonClient

@synthesize daemon;

//init
// create XPC connection & set remote obj interface
-(id)init
{
    //super
    self = [super init];
    if(nil != self)
    {
        //alloc/init
        daemon = [[NSXPCConnection alloc] initWithMachServiceName:DAEMON_MACH_SERVICE options:0];
        
        //set remote object interface
        self.daemon.remoteObjectInterface = [NSXPCInterface interfaceWithProtocol:@protocol(XPCDaemonProtocol)];
        
        //whitelist acceptable classses
        [self.daemon.remoteObjectInterface setClasses:[NSSet setWithObjects:[NSArray class], [NSDictionary class], [NSString class], [NSNumber class], [NSDate class], [NSData class], [NSNull class], nil]
                                          forSelector:@selector(updatePreferences:reply:)
                                        argumentIndex:0
                                              ofReply:NO];
        
        //set exported object interface (protocol)
        self.daemon.exportedInterface = [NSXPCInterface interfaceWithProtocol:@protocol(XPCUserProtocol)];
        
        //set exported object
        // this will allow daemon to invoke user methods!
        self.daemon.exportedObject = [[XPCUser alloc] init];
    
        //resume
        [self.daemon resume];
    }
    
    return self;
}

//get preferences
// note: synchronous, will block until daemon responds
-(NSDictionary*)getPreferences
{
    //preferences
    __block NSDictionary* preferences = nil;
    
    //dbg msg
    os_log_debug(logHandle, "invoking daemon XPC method, '%s'", __PRETTY_FUNCTION__);
    
    //request preferences
    [[self.daemon synchronousRemoteObjectProxyWithErrorHandler:^(NSError * proxyError)
    {
        //err msg
        os_log_error(logHandle, "ERROR: failed to execute daemon XPC method '%s' (error: %{public}@)", __PRETTY_FUNCTION__, proxyError);
        
     }] getPreferences:^(NSDictionary* preferencesFromDaemon)
     {
         //dbg msg
         os_log_debug(logHandle, "got preferences: %{public}@", preferencesFromDaemon);
         
         //save
         preferences = preferencesFromDaemon;
         
     }];
    
    return preferences;
}

//update (save) preferences
-(NSDictionary*)updatePreferences:(NSDictionary*)updatedPreferences
{
    //preferences
    __block NSDictionary* preferences = nil;
    
    //dbg msg
    os_log_debug(logHandle, "invoking daemon XPC method, '%s'", __PRETTY_FUNCTION__);
    
    //update prefs
    [[self.daemon synchronousRemoteObjectProxyWithErrorHandler:^(NSError * proxyError)
    {
        //err msg
        os_log_error(logHandle, "ERROR: failed to execute daemon XPC method '%s' (error: %{public}@)", __PRETTY_FUNCTION__, proxyError);
          
    }] updatePreferences:updatedPreferences reply:^(NSDictionary* preferencesFromDaemon)
     {
         //dbg msg
         os_log_debug(logHandle, "got preferences: %{public}@", preferencesFromDaemon);
         
         //save
         preferences = preferencesFromDaemon;
         
     }];
    
    return preferences;

}

//quit
-(void)quit
{
    //dbg msg
    os_log_debug(logHandle, "invoking daemon XPC method, '%s'", __PRETTY_FUNCTION__);
    
    //update prefs
    [[self.daemon remoteObjectProxyWithErrorHandler:^(NSError * proxyError)
    {
        //err msg
        os_log_error(logHandle, "ERROR: failed to execute daemon XPC method '%s' (error: %{public}@)", __PRETTY_FUNCTION__, proxyError);
          
    }] quit];
    
    return;
}

@end
