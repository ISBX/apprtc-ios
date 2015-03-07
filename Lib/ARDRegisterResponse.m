/*
 * libjingle
 * Copyright 2014, Google Inc.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions are met:
 *
 *  1. Redistributions of source code must retain the above copyright notice,
 *     this list of conditions and the following disclaimer.
 *  2. Redistributions in binary form must reproduce the above copyright notice,
 *     this list of conditions and the following disclaimer in the documentation
 *     and/or other materials provided with the distribution.
 *  3. The name of the author may not be used to endorse or promote products
 *     derived from this software without specific prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY THE AUTHOR ``AS IS'' AND ANY EXPRESS OR IMPLIED
 * WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF
 * MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO
 * EVENT SHALL THE AUTHOR BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
 * SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO,
 * PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS;
 * OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY,
 * WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR
 * OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF
 * ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

#import "ARDRegisterResponse.h"

#import "ARDSignalingMessage.h"
#import "ARDUtilities.h"
#import "RTCICEServer+JSON.h"

static NSString const *kARDRegisterResultKey = @"result";
static NSString const *kARDRegisterResultParamsKey = @"params";
static NSString const *kARDRegisterInitiatorKey = @"is_initiator";
static NSString const *kARDRegisterRoomIdKey = @"room_id";
static NSString const *kARDRegisterClientIdKey = @"client_id";
static NSString const *kARDRegisterMessagesKey = @"messages";
static NSString const *kARDRegisterWebSocketURLKey = @"wss_url";
static NSString const *kARDRegisterWebSocketRestURLKey = @"wss_post_url";

@interface ARDRegisterResponse ()

@property(nonatomic, assign) ARDRegisterResultType result;
@property(nonatomic, assign) BOOL isInitiator;
@property(nonatomic, strong) NSString *roomId;
@property(nonatomic, strong) NSString *clientId;
@property(nonatomic, strong) NSArray *messages;
@property(nonatomic, strong) NSURL *webSocketURL;
@property(nonatomic, strong) NSURL *webSocketRestURL;

@end

@implementation ARDRegisterResponse

@synthesize result = _result;
@synthesize isInitiator = _isInitiator;
@synthesize roomId = _roomId;
@synthesize clientId = _clientId;
@synthesize messages = _messages;
@synthesize webSocketURL = _webSocketURL;
@synthesize webSocketRestURL = _webSocketRestURL;

+ (ARDRegisterResponse *)responseFromJSONData:(NSData *)data {
  NSDictionary *responseJSON = [NSDictionary dictionaryWithJSONData:data];
  if (!responseJSON) {
    return nil;
  }
  ARDRegisterResponse *response = [[ARDRegisterResponse alloc] init];
  NSString *resultString = responseJSON[kARDRegisterResultKey];
  response.result = [[self class] resultTypeFromString:resultString];
  NSDictionary *params = responseJSON[kARDRegisterResultParamsKey];

  response.isInitiator = [params[kARDRegisterInitiatorKey] boolValue];
  response.roomId = params[kARDRegisterRoomIdKey];
  response.clientId = params[kARDRegisterClientIdKey];

  // Parse messages.
  NSArray *messages = params[kARDRegisterMessagesKey];
  NSMutableArray *signalingMessages =
      [NSMutableArray arrayWithCapacity:messages.count];
  for (NSString *message in messages) {
    ARDSignalingMessage *signalingMessage =
        [ARDSignalingMessage messageFromJSONString:message];
    [signalingMessages addObject:signalingMessage];
  }
  response.messages = signalingMessages;

  // Parse websocket urls.
  NSString *webSocketURLString = params[kARDRegisterWebSocketURLKey];
  response.webSocketURL = [NSURL URLWithString:webSocketURLString];
  NSString *webSocketRestURLString = params[kARDRegisterWebSocketRestURLKey];
  response.webSocketRestURL = [NSURL URLWithString:webSocketRestURLString];

  return response;
}

#pragma mark - Private

+ (ARDRegisterResultType)resultTypeFromString:(NSString *)resultString {
  ARDRegisterResultType result = kARDRegisterResultTypeUnknown;
  if ([resultString isEqualToString:@"SUCCESS"]) {
    result = kARDRegisterResultTypeSuccess;
  } else if ([resultString isEqualToString:@"FULL"]) {
    result = kARDRegisterResultTypeFull;
  }
  return result;
}

@end
