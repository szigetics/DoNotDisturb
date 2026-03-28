//
//  file: XPCDaemonClient.h
//  project: DoNotDisturb (shared)
//  description: talk to daemon via XPC (header)
//
//  created by Patrick Wardle
//  copyright (c) 2026 Objective-See. All rights reserved.
//

@import Foundation;

#import "XPCDaemonProto.h"

@interface XPCDaemonClient : NSObject

//xpc connection to daemon
@property (atomic, strong, readwrite)NSXPCConnection* daemon;

//get preferences
// note: synchronous
-(NSDictionary*)getPreferences;

//update (save) preferences
-(void)updatePreferences:(NSDictionary*)preferences;

//quit
-(void)quit;

@end
