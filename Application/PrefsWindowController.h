//
//  file: PrefsWindowController.h
//  project: DoNotDisturb (main app)
//  description: preferences window controller (header)
//
//  created by Patrick Wardle
//  copyright (c) 2026 Objective-See. All rights reserved.
//

@import Cocoa;

#import "Telegram.h"
#import "XPCDaemonClient.h"
#import "UpdateWindowController.h"

/* CONSTS */

//toolbar tabs
#define TOOLBAR_MODES 0
#define TOOLBAR_ALERTS 1
#define TOOLBAR_ACTIONS 2
#define TOOLBAR_UPDATES 3

//to select, need string ID
#define TOOLBAR_MODES_ID @"mode"
#define TOOLBAR_ALERTS_ID @"alerts"
#define TOOLBAR_ACTIONS_ID @"actions"
#define TOOLBAR_UPDATES_ID @"updates"

@interface PrefsWindowController : NSWindowController <NSWindowDelegate, NSTextFieldDelegate>

/* PROPERTIES */

//preferences
@property(nonatomic, retain)NSDictionary* preferences;

//toolbar
@property (weak) IBOutlet NSToolbar *toolbar;

//added view
@property (nonatomic) BOOL viewWasAdded;

//modes view
@property (strong) IBOutlet NSView *modesView;

/* ALERTS */

//alerts prefs view
@property (weak) IBOutlet NSView *alertsView;

//telegram
@property(nonatomic, retain)Telegram* telegram;

@property (weak) IBOutlet NSTextField *telegramBotToken;
@property (weak) IBOutlet NSImageView *telegramQRCode;

@property (weak) IBOutlet NSStackView *telegramStackView;

@property (weak) IBOutlet NSTextField *stepTwo;
@property (weak) IBOutlet NSTextField *stepTwoDetails;


@property (weak) IBOutlet NSTextField *telegramStatus;
@property (weak) IBOutlet NSProgressIndicator *telegramActivityIndicator;


/* ACTIONS */
@property (strong) IBOutlet NSView *actionsView;
@property (weak) IBOutlet NSTextField *executePath;

/* UPDATES */

//update view
@property (weak) IBOutlet NSView *updateView;

//update button
@property (weak) IBOutlet NSButton *updateButton;

//update indicator (spinner)
@property (weak) IBOutlet NSProgressIndicator *updateIndicator;

//update label
@property (weak) IBOutlet NSTextField *updateLabel;

//update window controller
@property(nonatomic, retain)UpdateWindowController* updateWindowController;

/* METHODS */

//toolbar button handler
-(IBAction)toolbarButtonHandler:(id)sender;

//show toolbar view for specified tag
-(void)showToolbarView:(NSInteger)tag;

//button handler for all preference buttons
-(IBAction)togglePreference:(id)sender;

@end
