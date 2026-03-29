//
//  Telegram.m
//  Application
//
//  Created by Patrick Wardle on 3/22/26.
//  Copyright © 2026 Objective-See. All rights reserved.
//

@import OSLog;
static NSString * const kTelegramAPIBase   = @"https://api.telegram.org/bot";

#import "Telegram.h"

//log handle
extern os_log_t logHandle;

@implementation Telegram

//init
-(id)init
{
    //super
    self = [super init];
    if(nil != self)
    {
        
    }
    
    return self;
}

//make sure bot ID is ok
- (void)validateBotID:(NSString *)botID
           completion:(void (^)(NSString * _Nullable botName,
                                NSString * _Nullable botUsername,
                                NSError  * _Nullable error))completion {

    NSURL *url = [NSURL URLWithString:
        [NSString stringWithFormat:@"%@%@/getMe", kTelegramAPIBase, botID]];

    NSURLSession *session = [NSURLSession sharedSession];
    [[session dataTaskWithURL:url
           completionHandler:^(NSData *data, NSURLResponse *resp, NSError *err) {

        dispatch_async(dispatch_get_main_queue(), ^{

            if(err) {
                completion(nil, nil, err);
                return;
            }

            NSDictionary *json = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
            if(![json isKindOfClass:[NSDictionary class]] || ![json[@"ok"] boolValue]) {
                completion(nil, nil, [NSError errorWithDomain:@"TelegramError"
                                                    code:401
                                                userInfo:@{NSLocalizedDescriptionKey: @"Invalid Token"}]);
                return;
            }

            completion(json[@"result"][@"first_name"] ?: @"Your bot",
                       json[@"result"][@"username"],
                       nil);
        });

    }] resume];
}

//get chat iD
-(void)getChatIDWithBotID:(NSString *)botID
                  timeout:(NSInteger)timeout
               completion:(void (^)(NSString * _Nullable chatID,
                                    NSError  * _Nullable error))completion {

    NSString *urlStr = [NSString stringWithFormat:
        @"%@%@/getUpdates?timeout=%ld", kTelegramAPIBase, botID, (long)timeout];

    //create session with timeout matched to this request
    NSURLSessionConfiguration *config = [NSURLSessionConfiguration defaultSessionConfiguration];
    config.timeoutIntervalForRequest = timeout + 30.0;
    NSURLSession *session = [NSURLSession sessionWithConfiguration:config];

    __weak typeof(self) weak = self;
    [[session dataTaskWithURL:[NSURL URLWithString:urlStr]
      completionHandler:^(NSData *data, NSURLResponse *resp, NSError *err) {

        dispatch_async(dispatch_get_main_queue(), ^{

            if(err) {
                if(err.code == NSURLErrorCancelled) return;
                completion(nil, err);
                return;
            }

            NSDictionary *json = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
            if(![json isKindOfClass:[NSDictionary class]]) {
                completion(nil, [NSError errorWithDomain:@"TelegramError"
                                                   code:400
                                               userInfo:@{NSLocalizedDescriptionKey: @"Invalid response"}]);
                return;
            }
            NSArray *updates = json[@"result"];

            for(NSDictionary *update in updates) {
                id chatID = update[@"message"][@"chat"][@"id"];
                if(chatID) {
                    completion([NSString stringWithFormat:@"%@", chatID], nil);
                    return;
                }
            }

            //nothing found — return nil
            completion(nil, nil);
        });

    }] resume];
}

-(void)sendTestAlertWithBotID:(NSString *)botID
                       chatID:(NSString *)chatID
                   completion:(void (^)(NSError * _Nullable error))completion {

    [self sendAlertWithBotID:botID
                      chatID:chatID
                     caption:@"✅ DoNotDisturb is connected.\nYou'll receive an alert here when your MacBook lid is opened."
                       image:nil
                  completion:completion];
}


-(void)sendAlertWithBotID:(NSString *)botID
                   chatID:(NSString *)chatID
                  caption:(NSString *)caption
                    image:(NSData * _Nullable)imageData
               completion:(void (^ _Nullable)(NSError * _Nullable error))completion {

    NSURLSession *session = NSURLSession.sharedSession;

    //no image? just sendMessage
    if(!imageData) {

        NSURL *url = [NSURL URLWithString:
            [NSString stringWithFormat:@"%@%@/sendMessage", kTelegramAPIBase, botID]];

        NSDictionary *body = @{ @"chat_id": chatID, @"text": caption };

        NSMutableURLRequest *req = [NSMutableURLRequest requestWithURL:url];
        req.HTTPMethod = @"POST";
        req.HTTPBody   = [NSJSONSerialization dataWithJSONObject:body options:0 error:nil];
        [req setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];

        [[session dataTaskWithRequest:req
                    completionHandler:^(NSData *data, NSURLResponse *resp, NSError *err) {

            dispatch_async(dispatch_get_main_queue(), ^{
                if(err) { if(completion) completion(err); return; }

                NSDictionary *json = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
                if(![json isKindOfClass:[NSDictionary class]] || ![json[@"ok"] boolValue]) {
                    if(completion) completion([NSError errorWithDomain:@"TelegramError"
                                                                  code:400
                                                              userInfo:@{NSLocalizedDescriptionKey: json[@"description"] ?: @"Unknown error"}]);
                    return;
                }
                if(completion) completion(nil);
            });

        }] resume];

        return;
    }

    //have image — sendPhoto via multipart
    NSURL *url = [NSURL URLWithString:
        [NSString stringWithFormat:@"%@%@/sendPhoto", kTelegramAPIBase, botID]];

    NSString *boundary = @"TelegramBoundary";

    NSMutableData *body = [NSMutableData data];
    void (^appendField)(NSString *, NSString *) = ^(NSString *name, NSString *value) {
        [body appendData:[[NSString stringWithFormat:
            @"--%@\r\nContent-Disposition: form-data; name=\"%@\"\r\n\r\n%@\r\n",
            boundary, name, value] dataUsingEncoding:NSUTF8StringEncoding]];
    };

    appendField(@"chat_id", chatID);
    appendField(@"caption", caption);

    [body appendData:[[NSString stringWithFormat:
        @"--%@\r\nContent-Disposition: form-data; name=\"photo\"; filename=\"alert.jpg\"\r\nContent-Type: image/jpeg\r\n\r\n",
        boundary] dataUsingEncoding:NSUTF8StringEncoding]];
    [body appendData:imageData];
    [body appendData:[[NSString stringWithFormat:@"\r\n--%@--\r\n", boundary]
                      dataUsingEncoding:NSUTF8StringEncoding]];

    NSMutableURLRequest *req = [NSMutableURLRequest requestWithURL:url];
    req.HTTPMethod = @"POST";
    req.HTTPBody   = body;
    [req setValue:[NSString stringWithFormat:@"multipart/form-data; boundary=%@", boundary]
       forHTTPHeaderField:@"Content-Type"];

    [[session dataTaskWithRequest:req
                completionHandler:^(NSData *data, NSURLResponse *resp, NSError *err) {

        dispatch_async(dispatch_get_main_queue(), ^{
            if(err) { if(completion) completion(err); return; }

            NSDictionary *json = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
            if(![json isKindOfClass:[NSDictionary class]] || ![json[@"ok"] boolValue]) {
                if(completion) completion([NSError errorWithDomain:@"TelegramError"
                                                              code:400
                                                          userInfo:@{NSLocalizedDescriptionKey: json[@"description"] ?: @"Unknown error"}]);
                return;
            }
            if(completion) completion(nil);
        });

    }] resume];
}


@end
