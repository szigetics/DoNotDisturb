//
//  file: XPCUserProtocol
//  project: DoNotDisturb (shared)
//  description: protocol for talking to the user (header)
//
//  created by Patrick Wardle
//  copyright (c) 2026 Objective-See. All rights reserved.
//

@import Foundation;

@class Event;

@protocol XPCUserProtocol

-(void)alertShow:(NSDictionary*)alert;
-(void)captureImage:(void (^)(NSData*))reply;
-(void)isScreenLocked:(void (^)(BOOL))reply;
-(void)executeAction:(NSString*)path reply:(void (^)(NSInteger))reply;

@end

