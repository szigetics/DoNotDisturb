//
//  Telegram.h
//  Application
//
//  Created by Patrick Wardle on 3/22/26.
//  Copyright © 2026 Objective-See. All rights reserved.
//


#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface Telegram : NSObject

//cancel any in-flight polling
-(void)cancelPolling;

- (void)validateBotID:(NSString *)botID
           completion:(void (^)(NSString * _Nullable botName,
                                NSString * _Nullable botUsername,
                                NSError  * _Nullable error))completion;

- (void)getChatIDWithBotID:(NSString *)botID
                   timeout:(NSInteger)timeout
                completion:(void (^)(NSString * _Nullable chatID,
                                     NSError  * _Nullable error))completion;

- (void)sendTestAlertWithBotID:(NSString *)botID
                        chatID:(NSString *)chatID
                    completion:(void (^)(NSError * _Nullable error))completion;

-(void)sendAlertWithBotID:(NSString *)botID
                   chatID:(NSString *)chatID
                  caption:(NSString *)caption
                    image:(NSData * _Nullable)imageData
               completion:(void (^ _Nullable)(NSError * _Nullable error))completion;

@end

NS_ASSUME_NONNULL_END
