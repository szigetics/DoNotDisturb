//
//  file: XPCDaemonProtocol.h
//  project: DoNotDisturb (shared)
//  description: methods exported by the daemon
//
//  created by Patrick Wardle
//  copyright (c) 2026 Objective-See. All rights reserved.
//

@import Foundation;

@class Event;

@protocol XPCDaemonProtocol

//get preferences
-(void)getPreferences:(void (^)(NSDictionary*))reply;

//update preferences
-(void)updatePreferences:(NSDictionary*)preferences;

//quit (user asked!)
-(void)quit;

@end
