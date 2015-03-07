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

#import "ARDWebSocketChannel.h"

#import "ARDUtilities.h"
#import "SRWebSocket.h"

// TODO(tkchin): move these to a configuration object.
static NSString const *kARDWSSMessageErrorKey = @"error";
static NSString const *kARDWSSMessagePayloadKey = @"msg";

@interface ARDWebSocketChannel () <SRWebSocketDelegate>
@end

@implementation ARDWebSocketChannel {
  NSURL *_url;
  NSURL *_restURL;
  SRWebSocket *_socket;
}

@synthesize delegate = _delegate;
@synthesize state = _state;
@synthesize roomId = _roomId;
@synthesize clientId = _clientId;

- (instancetype)initWithURL:(NSURL *)url
                    restURL:(NSURL *)restURL
                   delegate:(id<ARDWebSocketChannelDelegate>)delegate {
  if (self = [super init]) {
    _url = url;
    _restURL = restURL;
    _delegate = delegate;
    _socket = [[SRWebSocket alloc] initWithURL:url];
    _socket.delegate = self;
    NSLog(@"Opening WebSocket.");
    [_socket open];
  }
  return self;
}

- (void)dealloc {
  [self disconnect];
}

- (void)setState:(ARDWebSocketChannelState)state {
  if (_state == state) {
    return;
  }
  _state = state;
  [_delegate channel:self didChangeState:_state];
}

- (void)registerForRoomId:(NSString *)roomId
                 clientId:(NSString *)clientId {
  NSParameterAssert(roomId.length);
  NSParameterAssert(clientId.length);
  _roomId = roomId;
  _clientId = clientId;
  if (_state == kARDWebSocketChannelStateOpen) {
    [self registerWithCollider];
  }
}

- (void)sendData:(NSData *)data {
  NSParameterAssert(_clientId.length);
  NSParameterAssert(_roomId.length);
  if (_state == kARDWebSocketChannelStateRegistered) {
    NSString *payload =
        [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    NSDictionary *message = @{
      @"cmd": @"send",
      @"msg": payload,
    };
    NSData *messageJSONObject =
        [NSJSONSerialization dataWithJSONObject:message
                                        options:NSJSONWritingPrettyPrinted
                                          error:nil];
    NSString *messageString =
        [[NSString alloc] initWithData:messageJSONObject
                              encoding:NSUTF8StringEncoding];
    NSLog(@"C->WSS: %@", messageString);
    [_socket send:messageString];
  } else {
    NSString *dataString =
        [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    NSLog(@"C->WSS POST: %@", dataString);
    NSString *urlString =
        [NSString stringWithFormat:@"%@/%@/%@",
            [_restURL absoluteString], _roomId, _clientId];
    NSURL *url = [NSURL URLWithString:urlString];
    [NSURLConnection sendAsyncPostToURL:url
                               withData:data
                      completionHandler:nil];
  }
}

- (void)disconnect {
  if (_state == kARDWebSocketChannelStateClosed ||
      _state == kARDWebSocketChannelStateError) {
    return;
  }
  [_socket close];
  NSLog(@"C->WSS DELETE rid:%@ cid:%@", _roomId, _clientId);
  NSString *urlString =
      [NSString stringWithFormat:@"%@/%@/%@",
          [_restURL absoluteString], _roomId, _clientId];
  NSURL *url = [NSURL URLWithString:urlString];
  NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
  request.HTTPMethod = @"DELETE";
  request.HTTPBody = nil;
  [NSURLConnection sendAsyncRequest:request completionHandler:nil];
}

#pragma mark - SRWebSocketDelegate

- (void)webSocketDidOpen:(SRWebSocket *)webSocket {
  NSLog(@"WebSocket connection opened.");
  self.state = kARDWebSocketChannelStateOpen;
  if (_roomId.length && _clientId.length) {
    [self registerWithCollider];
  }
}

- (void)webSocket:(SRWebSocket *)webSocket didReceiveMessage:(id)message {
  NSString *messageString = message;
  NSData *messageData = [messageString dataUsingEncoding:NSUTF8StringEncoding];
  id jsonObject = [NSJSONSerialization JSONObjectWithData:messageData
                                                  options:0
                                                    error:nil];
  if (![jsonObject isKindOfClass:[NSDictionary class]]) {
    NSLog(@"Unexpected message: %@", jsonObject);
    return;
  }
  NSDictionary *wssMessage = jsonObject;
  NSString *errorString = wssMessage[kARDWSSMessageErrorKey];
  if (errorString.length) {
    NSLog(@"WSS error: %@", errorString);
    return;
  }
  NSString *payload = wssMessage[kARDWSSMessagePayloadKey];
  ARDSignalingMessage *signalingMessage =
      [ARDSignalingMessage messageFromJSONString:payload];
  NSLog(@"WSS->C: %@", payload);
  [_delegate channel:self didReceiveMessage:signalingMessage];
}

- (void)webSocket:(SRWebSocket *)webSocket didFailWithError:(NSError *)error {
  NSLog(@"WebSocket error: %@", error);
  self.state = kARDWebSocketChannelStateError;
}

- (void)webSocket:(SRWebSocket *)webSocket
    didCloseWithCode:(NSInteger)code
              reason:(NSString *)reason
            wasClean:(BOOL)wasClean {
  NSLog(@"WebSocket closed with code: %ld reason:%@ wasClean:%d",
      (long)code, reason, wasClean);
  NSParameterAssert(_state != kARDWebSocketChannelStateError);
  self.state = kARDWebSocketChannelStateClosed;
}

#pragma mark - Private

- (void)registerWithCollider {
  if (_state == kARDWebSocketChannelStateRegistered) {
    return;
  }
  NSParameterAssert(_roomId.length);
  NSParameterAssert(_clientId.length);
  NSDictionary *registerMessage = @{
    @"cmd": @"register",
    @"roomid" : _roomId,
    @"clientid" : _clientId,
  };
  NSData *message =
      [NSJSONSerialization dataWithJSONObject:registerMessage
                                      options:NSJSONWritingPrettyPrinted
                                        error:nil];
  NSString *messageString =
      [[NSString alloc] initWithData:message encoding:NSUTF8StringEncoding];
  NSLog(@"Registering on WSS for rid:%@ cid:%@", _roomId, _clientId);
  // Registration can fail if server rejects it. For example, if the room is
  // full.
  [_socket send:messageString];
  self.state = kARDWebSocketChannelStateRegistered;
}

@end
