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

//init a handler for SIGTERM
// can perform actions such as disabling firewall and closing logging
void register4Shutdown(void);

//daemon should only be unloaded if box is shutting down
// so handle things de-init logging, etc
void goodbye(void);

#endif /* main_h */
