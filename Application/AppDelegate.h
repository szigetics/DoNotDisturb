//
//  file: AppDelegate.h
//  project: DoNotDisturb (login item)
//  description: app delegate for login item (header)
//
//  created by Patrick Wardle
//  copyright (c) 2026 Objective-See. All rights reserved.
//

@import Cocoa;

#import "StatusBarItem.h"
#import "XPCDaemonClient.h"
#import "AboutWindowController.h"
#import "PrefsWindowController.h"
#import "UpdateWindowController.h"

@interface AppDelegate : NSObject <NSApplicationDelegate>


/* PROPERTIES */

//screen lock state
@property(nonatomic, assign) BOOL screenLocked;

//status bar menu
@property(strong) IBOutlet NSMenu* statusMenu;

//status bar menu controller
@property(nonatomic, retain)StatusBarItem* statusBarItemController;

//about window controller
@property(nonatomic, retain)AboutWindowController* aboutWindowController;

//preferences window controller
@property(nonatomic, retain)PrefsWindowController* prefsWindowController;

//update window controller
@property(nonatomic, retain)UpdateWindowController* updateWindowController;

/* METHODS */

//set app foreground/background
// determined by the app's window count
-(void)setActivationPolicy;

//'preferences' menu item handler
// alloc and show preferences window
-(void)showPreferences:(NSInteger)tag;

//toggle (status) bar icon
-(void)toggleIcon:(NSDictionary*)preferences;

//quit
-(IBAction)quit:(id)sender;

@end

