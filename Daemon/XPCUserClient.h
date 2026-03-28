//
//  file: XPCUserClient.h
//  project: DoNotDisturb (launch daemon)
//  description: talk to the user, via XPC (header)
//
//  created by Patrick Wardle
//  copyright (c) 2026 Objective-See. All rights reserved.
//

@import Foundation;

#import "XPCUserProto.h"
@interface XPCUserClient : NSObject
{
    
}

/* PROPERTIES */


/* METHODS */

//deliver event (as alert) to user
// note: this is synchronous, so errors can be detected
-(BOOL)deliverAlert:(NSDictionary*)alert;

//ask (login item) if screen is locked
-(NSInteger)isScreenLocked;

//ask (login item) to capture image off webcam
-(NSData*)captureImage;

//ask (login item) to execute action
-(NSInteger)executeAction:(NSString*)path;

@end
