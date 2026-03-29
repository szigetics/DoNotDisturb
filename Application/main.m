//
//  file: main.m
//  project: DoNotDisturb (login item)
//  description: main; 'nuff said
//
//  created by Patrick Wardle
//  copyright (c) 2026 Objective-See. All rights reserved.
//

//TODO: change XPC client checks back to 2.0.0 for final release!


@import Cocoa;
@import OSLog;

#import "consts.h"
#import "utilities.h"

#import <sys/stat.h>

/* GLOBALS */

//log handle
os_log_t logHandle = nil;


//check for daemon
BOOL isDaemonRunning(void);

//main interface
// sanity checks, then kick off app
int main(int argc, const char * argv[])
{
    //status
    int status = 0;
    
    //init log
    logHandle = os_log_create(BUNDLE_ID, "app (helper)");
    
    //dbg msg(s)
    os_log_debug(logHandle, "started: %{public}@", [[[NSBundle mainBundle] infoDictionary] objectForKey:(id)kCFBundleNameKey]);
    os_log_debug(logHandle, "arguments: %{public}@", [[NSProcessInfo processInfo] arguments]);
    
    //launch app normally
    status = NSApplicationMain(argc, argv);
    
bail:
    
    return status;
}
