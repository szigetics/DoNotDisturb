//
//  file: main.h
//  project: DoNotDisturb (daemon)
//  description: main (header)
//
//  created by Patrick Wardle
//  copyright (c) 2026 Objective-See. All rights reserved.
//

#import "consts.h"
#import "utilities.h"
#import "Preferences.h"
#import "XPCListener.h"

#ifndef main_h
#define main_h

//GLOBALS

//prefs obj
Preferences* preferences = nil;

//XPC listener obj
XPCListener* xpcListener = nil;

//dispatch source for SIGTERM
dispatch_source_t dispatchSource = nil;

/* FUNCTIONS */

//check for full disk access
int fdaCheck(void);

#endif /* main_h */
