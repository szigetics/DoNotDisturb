//
//  Camera.m
//  loginItem
//
//  Created by Patrick Wardle on 9/1/18.
//  Copyright © 2026 Objective-See. All rights reserved.
//

#import "Camera.h"

@import OSLog;
@import AppKit;
@import CoreImage;
@import AVFoundation;

/* GLOBALS */

//log handle
extern os_log_t logHandle;

@implementation Camera
{
    //semaphore signaled when first frame captured
    dispatch_semaphore_t _captureSemaphore;
    
    //captured image data (JPEG)
    NSData* _capturedImage;
    
    //serial queue for video output callbacks
    dispatch_queue_t _captureQueue;
    
    //flag to ensure we only grab one frame
    BOOL _frameCaptured;
    
    //count frames to skip (let auto-exposure settle)
    NSInteger _frameCount;
}

@synthesize session;

//configure
-(BOOL)configure
{
    // already configured
    if(nil != self.session)
        return YES;

    // find default camera
    AVCaptureDevice* device = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
    if(nil == device)
    {
        os_log_error(logHandle, "failed to find camera for capture");
        return NO;
    }

    // init input from camera
    NSError* inputError = nil;
    AVCaptureDeviceInput* input = [AVCaptureDeviceInput deviceInputWithDevice:device error:&inputError];
    if(nil == input)
    {
        os_log_error(logHandle, "failed to create input from camera: %{public}@", inputError);
        return NO;
    }

    // init session
    self.session = [[AVCaptureSession alloc] init];

    // check if input can be added
    if(YES != [self.session canAddInput:input])
    {
        os_log_error(logHandle, "cannot add input to session");
        self.session = nil;
        return NO;
    }

    // add input
    [self.session addInput:input];

    // init video data output (grabs frames as they arrive)
    AVCaptureVideoDataOutput* output = [[AVCaptureVideoDataOutput alloc] init];
    output.videoSettings = @{(id)kCVPixelBufferPixelFormatTypeKey: @(kCVPixelFormatType_32BGRA)};
    output.alwaysDiscardsLateVideoFrames = YES;
    
    // create serial queue for callbacks
    _captureQueue = dispatch_queue_create("com.objective-see.camera.capture", DISPATCH_QUEUE_SERIAL);
    [output setSampleBufferDelegate:self queue:_captureQueue];

    // check if output can be added
    if(YES != [self.session canAddOutput:output])
    {
        os_log_error(logHandle, "cannot add output to session");
        self.session = nil;
        return NO;
    }

    // add output
    [self.session addOutput:output];

    return YES;
}

//capture an image from the webcam
-(NSData*)captureImage
{
    // check TCC authorization status of camera
    switch([AVCaptureDevice authorizationStatusForMediaType:AVMediaTypeVideo])
    {
        case AVAuthorizationStatusAuthorized:
            os_log_debug(logHandle, "camera access authorized");
            break;

        case AVAuthorizationStatusNotDetermined:
            os_log_error(logHandle, "camera access not determined");
            return nil;

        case AVAuthorizationStatusDenied:
            os_log_error(logHandle, "camera access denied (TCC)");
            return nil;

        case AVAuthorizationStatusRestricted:
            os_log_error(logHandle, "camera access restricted (TCC)");
            return nil;

        default:
            os_log_error(logHandle, "unknown camera authorization status");
            return nil;
    }
    
    // configure session (no-op if already done)
    if(YES != [self configure])
    {
        os_log_error(logHandle, "failed to initialize/configure camera capture session");
        return nil;
    }

    os_log_debug(logHandle, "configured camera for capture");

    // reset state
    _capturedImage = nil;
    _frameCaptured = NO;
    _frameCount = 0;
    _captureSemaphore = dispatch_semaphore_create(0);

    // start session — delegate callback fires when first frame arrives
    [self.session startRunning];

    // wait up to 10s for a frame
    long timedOut = dispatch_semaphore_wait(_captureSemaphore, dispatch_time(DISPATCH_TIME_NOW, 10 * NSEC_PER_SEC));
    
    // stop session
    [self.session stopRunning];
    
    if(timedOut) {
        os_log_error(logHandle, "ERROR: camera capture timed out (no frames received)");
        return nil;
    }

    os_log_debug(logHandle, "captured image (%lu bytes)", (unsigned long)_capturedImage.length);
    return _capturedImage;
}

#pragma mark - AVCaptureVideoDataOutputSampleBufferDelegate

-(void)captureOutput:(AVCaptureOutput*)output
didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer
      fromConnection:(AVCaptureConnection*)connection
{
    //only grab one frame
    if(_frameCaptured) return;
    
    //skip first ~15 frames so auto-exposure can settle
    if(++_frameCount < 15) return;
    _frameCaptured = YES;
    
    //get pixel buffer
    CVImageBufferRef imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);
    if(NULL == imageBuffer)
    {
        os_log_error(logHandle, "failed to get image buffer from sample");
        dispatch_semaphore_signal(_captureSemaphore);
        return;
    }
    
    //convert to CGImage then JPEG via NSBitmapImageRep
    CIImage* ciImage = [CIImage imageWithCVPixelBuffer:imageBuffer];
    CIContext* context = [CIContext context];
    CGImageRef cgImage = [context createCGImage:ciImage fromRect:ciImage.extent];
    
    if(NULL != cgImage)
    {
        NSBitmapImageRep* rep = [[NSBitmapImageRep alloc] initWithCGImage:cgImage];
        _capturedImage = [rep representationUsingType:NSBitmapImageFileTypeJPEG
                                           properties:@{NSImageCompressionFactor: @(0.8)}];
        CGImageRelease(cgImage);
    }
    
    //signal: frame captured
    dispatch_semaphore_signal(_captureSemaphore);
}

@end
