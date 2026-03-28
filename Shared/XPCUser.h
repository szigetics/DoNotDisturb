//
//  file: XPCUser.h
//  project: DoNotDisturb (login item)
//  description: user XPC methods (header)
//
//  created by Patrick Wardle
//  copyright (c) 2026 Objective-See. All rights reserved.
//

@import Foundation;
#import "XPCUserProto.h"

@interface XPCUser : NSObject <XPCUserProtocol, NSUserNotificationCenterDelegate>

@property(nonatomic, assign) BOOL screenLocked;

@end
