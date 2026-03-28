//
//  Camera.h
//  loginItem
//
//  Created by Patrick Wardle on 9/1/18.
//  Copyright © 2026 Objective-See. All rights reserved.
//

#import <AVFoundation/AVFoundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface Camera : NSObject <AVCaptureVideoDataOutputSampleBufferDelegate>

@property (nonatomic, strong, nullable) AVCaptureSession* session;

-(BOOL)configure;
-(nullable NSData*)captureImage;

@end

NS_ASSUME_NONNULL_END
