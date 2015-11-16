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

#import "ARDAppClient.h"

#import <AVFoundation/AVFoundation.h>

#import "ARDMessageResponse.h"
#import "ARDRegisterResponse.h"
#import "ARDSignalingMessage.h"
#import "ARDUtilities.h"
#import "ARDWebSocketChannel.h"
#import "RTCICECandidate+JSON.h"
#import "RTCICEServer+JSON.h"
#import "RTCMediaConstraints.h"
#import "RTCMediaStream.h"
#import "RTCPair.h"
#import "RTCPeerConnection.h"
#import "RTCPeerConnectionDelegate.h"
#import "RTCPeerConnectionFactory.h"
#import "RTCSessionDescription+JSON.h"
#import "RTCSessionDescriptionDelegate.h"
#import "RTCVideoCapturer.h"
#import "RTCVideoTrack.h"


// TODO(tkchin): move these to a configuration object.
static NSString *kARDRoomServerHostUrl =
@"https://apprtc.appspot.com";
static NSString *kARDRoomServerRegisterFormat =
@"%@/join/%@";
static NSString *kARDRoomServerMessageFormat =
@"%@/message/%@/%@";
static NSString *kARDRoomServerByeFormat =
@"%@/leave/%@/%@";

static NSString *kARDDefaultSTUNServerUrl =
@"stun:stun.l.google.com:19302";
// TODO(tkchin): figure out a better username for CEOD statistics.
static NSString *kARDTurnRequestUrl =
@"https://computeengineondemand.appspot.com"
@"/turn?username=iapprtc&key=4080218913";

static NSString *kARDAppClientErrorDomain = @"ARDAppClient";
static NSInteger kARDAppClientErrorUnknown = -1;
static NSInteger kARDAppClientErrorRoomFull = -2;
static NSInteger kARDAppClientErrorCreateSDP = -3;
static NSInteger kARDAppClientErrorSetSDP = -4;
static NSInteger kARDAppClientErrorNetwork = -5;
static NSInteger kARDAppClientErrorInvalidClient = -6;
static NSInteger kARDAppClientErrorInvalidRoom = -7;

@interface ARDAppClient () <ARDWebSocketChannelDelegate,
RTCPeerConnectionDelegate, RTCSessionDescriptionDelegate>
@property(nonatomic, strong) ARDWebSocketChannel *channel;
@property(nonatomic, strong) RTCPeerConnection *peerConnection;
@property(nonatomic, strong) RTCPeerConnectionFactory *factory;
@property(nonatomic, strong) NSMutableArray *messageQueue;

@property(nonatomic, assign) BOOL isTurnComplete;
@property(nonatomic, assign) BOOL hasReceivedSdp;
@property(nonatomic, readonly) BOOL isRegisteredWithRoomServer;

@property(nonatomic, strong) NSString *roomId;
@property(nonatomic, strong) NSString *clientId;
@property(nonatomic, assign) BOOL isInitiator;
@property(nonatomic, strong) NSMutableArray *iceServers;
@property(nonatomic, strong) NSURL *webSocketURL;
@property(nonatomic, strong) NSURL *webSocketRestURL;
@property(nonatomic, strong) RTCAudioTrack *defaultAudioTrack;
@property(nonatomic, strong) RTCVideoTrack *defaultVideoTrack;

@end

@implementation ARDAppClient

@synthesize delegate = _delegate;
@synthesize state = _state;
@synthesize serverHostUrl = _serverHostUrl;
@synthesize channel = _channel;
@synthesize peerConnection = _peerConnection;
@synthesize factory = _factory;
@synthesize messageQueue = _messageQueue;
@synthesize isTurnComplete = _isTurnComplete;
@synthesize hasReceivedSdp  = _hasReceivedSdp;
@synthesize roomId = _roomId;
@synthesize clientId = _clientId;
@synthesize isInitiator = _isInitiator;
@synthesize iceServers = _iceServers;
@synthesize webSocketURL = _websocketURL;
@synthesize webSocketRestURL = _websocketRestURL;

- (instancetype)initWithDelegate:(id<ARDAppClientDelegate>)delegate {
    if (self = [super init]) {
        _delegate = delegate;
        _factory = [[RTCPeerConnectionFactory alloc] init];
        _messageQueue = [NSMutableArray array];
        _iceServers = [NSMutableArray arrayWithObject:[self defaultSTUNServer]];
        _serverHostUrl = kARDRoomServerHostUrl;
        
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(orientationChanged:)
                                                     name:@"UIDeviceOrientationDidChangeNotification"
                                                   object:nil];
        
        
        //AVCaptureSessionRuntimeErrorNotification
        //          [[NSNotificationCenter defaultCenter] addObserver:self
        //                                                   selector:@selector(handleErrorNotificationVideoCapture:)
        //                                                       name:AVCaptureSessionRuntimeErrorNotification
        //                                                     object:nil];
        
        
        //        [[NSNotificationCenter defaultCenter] addObserver:self
        //                                                 selector:@selector(handleCaptureSessionEnded:)
        //                                                     name:AVCaptureSessionInterruptionEndedNotification
        //                                                   object:nil];
        
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(handleCaptureSessionStopRunning:)
                                                     name:
         AVCaptureSessionDidStopRunningNotification
                                                   object:nil];
        
        //        [[NSNotificationCenter defaultCenter] addObserver:self
        //                                                 selector:@selector(handleCaptureSessionStartRunning:)
        //                                                     name:         AVCaptureSessionDidStartRunningNotification
        //                                                   object:nil];
        
    }
    return self;
}

- (void)dealloc {
    [ [NSNotificationCenter defaultCenter] removeObserver:self name:@"UIDeviceOrientationDidChangeNotification" object:nil ];
    [ [NSNotificationCenter defaultCenter] removeObserver:self name:AVCaptureSessionDidStopRunningNotification object:nil ];
    [self disconnect];
}

- (void)handleErrorNotificationVideoCapture:(NSNotification *)notification {
    NSDictionary *userInfo = notification.userInfo;
    NSError* error = userInfo[AVCaptureSessionErrorKey];
    NSLog(@"\n handle video error method: %@", error);
    if (error.code == -11819) {
        [self orientationChanged:nil];
    }
    
}

//- (void)handleCaptureSessionStartRunning:(NSNotification *)notification
//{
//
//}

- (void)handleCaptureSessionStopRunning:(NSNotification *)notification
{
    dispatch_async(dispatch_get_main_queue(), ^{
        RTCMediaStream* localStream = [self createLocalMediaStream];
        [_peerConnection addStream:localStream];
    });
}

//- (void)handleCaptureSessionEnded:(NSNotification *)notification
//{
//
//}

- (void)orientationChanged:(NSNotification *)notification {
    
    UIDeviceOrientation orientation = [[UIDevice currentDevice] orientation];
    if (UIDeviceOrientationIsLandscape(orientation) || UIDeviceOrientationIsPortrait(orientation)) {
        //Remove current video track
        RTCMediaStream *localStream = _peerConnection.localStreams[0];
        
        RTCVideoTrack* formerVideoTrack = localStream.videoTracks[0];
        [ localStream removeVideoTrack:formerVideoTrack ];
        [_peerConnection removeStream:localStream];
        [_delegate didRemoveLocalVideoTrack:formerVideoTrack];
    }
}

- (void)setState:(ARDAppClientState)state {
    if (_state == state) {
        return;
    }
    _state = state;
    [_delegate appClient:self didChangeState:_state];
}

- (void)connectToRoomWithId:(NSString *)roomId
                    options:(NSDictionary *)options {
    NSParameterAssert(roomId.length);
    NSParameterAssert(_state == kARDAppClientStateDisconnected);
    self.state = kARDAppClientStateConnecting;
    
    // Request TURN.
    __weak ARDAppClient *weakSelf = self;
    NSURL *turnRequestURL = [NSURL URLWithString:kARDTurnRequestUrl];
    [self requestTURNServersWithURL:turnRequestURL
                  completionHandler:^(NSArray *turnServers) {
                      ARDAppClient *strongSelf = weakSelf;
                      [strongSelf.iceServers addObjectsFromArray:turnServers];
                      strongSelf.isTurnComplete = YES;
                      [strongSelf startSignalingIfReady];
                  }];
    
    // Register with room server.
    [self registerWithRoomServerForRoomId:roomId
                        completionHandler:^(ARDRegisterResponse *response) {
                            ARDAppClient *strongSelf = weakSelf;
                            if (!response || response.result != kARDRegisterResultTypeSuccess) {
                                NSLog(@"Failed to register with room server. Result:%d",
                                      (int)response.result);
                                [strongSelf disconnect];
                                NSDictionary *userInfo = @{
                                                           NSLocalizedDescriptionKey: @"Room is full.",
                                                           };
                                NSError *error =
                                [[NSError alloc] initWithDomain:kARDAppClientErrorDomain
                                                           code:kARDAppClientErrorRoomFull
                                                       userInfo:userInfo];
                                [strongSelf.delegate appClient:strongSelf didError:error];
                                return;
                            }
                            NSLog(@"Registered with room server.");
                            strongSelf.roomId = response.roomId;
                            strongSelf.clientId = response.clientId;
                            strongSelf.isInitiator = response.isInitiator;
                            for (ARDSignalingMessage *message in response.messages) {
                                if (message.type == kARDSignalingMessageTypeOffer ||
                                    message.type == kARDSignalingMessageTypeAnswer) {
                                    strongSelf.hasReceivedSdp = YES;
                                    [strongSelf.messageQueue insertObject:message atIndex:0];
                                } else {
                                    [strongSelf.messageQueue addObject:message];
                                }
                            }
                            strongSelf.webSocketURL = response.webSocketURL;
                            strongSelf.webSocketRestURL = response.webSocketRestURL;
                            [strongSelf registerWithColliderIfReady];
                            [strongSelf startSignalingIfReady];
                        }];
}

- (void)disconnect {
    if (_state == kARDAppClientStateDisconnected) {
        return;
    }
    if ( self.isRegisteredWithRoomServer ) {
        [self unregisterWithRoomServer];
    }
    if (_channel) {
        if (_channel.state == kARDWebSocketChannelStateRegistered) {
            // Tell the other client we're hanging up.
            ARDByeMessage *byeMessage = [[ARDByeMessage alloc] init];
            NSData *byeData = [byeMessage JSONData];
            [_channel sendData:byeData];
        }
        // Disconnect from collider.
        _channel = nil;
    }
    _clientId = nil;
    _roomId = nil;
    _isInitiator = NO;
    _hasReceivedSdp = NO;
    _messageQueue = [NSMutableArray array];
    _peerConnection = nil;
    self.state = kARDAppClientStateDisconnected;
}

#pragma mark - ARDWebSocketChannelDelegate

- (void)channel:(ARDWebSocketChannel *)channel
didReceiveMessage:(ARDSignalingMessage *)message {
    switch (message.type) {
        case kARDSignalingMessageTypeOffer:
        case kARDSignalingMessageTypeAnswer:
            _hasReceivedSdp = YES;
            [_messageQueue insertObject:message atIndex:0];
            break;
        case kARDSignalingMessageTypeCandidate:
            [_messageQueue addObject:message];
            break;
        case kARDSignalingMessageTypeBye:
            [self processSignalingMessage:message];
            return;
    }
    [self drainMessageQueueIfReady];
}

- (void)channel:(ARDWebSocketChannel *)channel
 didChangeState:(ARDWebSocketChannelState)state {
    switch (state) {
        case kARDWebSocketChannelStateOpen:
            break;
        case kARDWebSocketChannelStateRegistered:
            break;
        case kARDWebSocketChannelStateClosed:
        case kARDWebSocketChannelStateError:
            // TODO(tkchin): reconnection scenarios. Right now we just disconnect
            // completely if the websocket connection fails.
            [self disconnect];
            break;
    }
}

#pragma mark - RTCPeerConnectionDelegate

- (void)peerConnection:(RTCPeerConnection *)peerConnection
 signalingStateChanged:(RTCSignalingState)stateChanged {
    
    switch (stateChanged) {
        case RTCSignalingStable:
            NSLog(@"Signaling state changed: RTCSignalingStable");
            break;
        case RTCSignalingHaveLocalOffer:
            NSLog(@"Signaling state changed: RTCSignalingHaveLocalOffer");
            break;
        case RTCSignalingHaveRemoteOffer:
            NSLog(@"Signaling state changed: RTCSignalingHaveRemoteOffer");
            break;
        case RTCSignalingHaveLocalPrAnswer:
            NSLog(@"Signaling state changed: RTCSignalingHaveLocalPrAnswer");
            break;
        case RTCSignalingHaveRemotePrAnswer:
            NSLog(@"Signaling state changed: RTCSignalingHaveRemotePrAnswer");
            break;
        default:
            NSLog(@"Signaling state changed: %d", stateChanged);
            break;
    }
}

- (void)peerConnection:(RTCPeerConnection *)peerConnection           addedStream:(RTCMediaStream *)stream {
    dispatch_async(dispatch_get_main_queue(), ^{
        NSLog(@"Received %lu video tracks and %lu audio tracks",
              (unsigned long)stream.videoTracks.count,
              (unsigned long)stream.audioTracks.count);
        if (stream.videoTracks.count) {
            RTCVideoTrack *videoTrack = stream.videoTracks[0];
            [_delegate appClient:self didReceiveRemoteVideoTrack:videoTrack];
        }
    });
}

- (void)peerConnection:(RTCPeerConnection *)peerConnection
         removedStream:(RTCMediaStream *)stream {
    NSLog(@"Stream was removed.");
}

- (void)peerConnectionOnRenegotiationNeeded:(RTCPeerConnection *)peerConnection {
    NSLog(@"WARNING: Renegotiation needed but unimplemented.");
    
}

- (void)peerConnection:(RTCPeerConnection *)peerConnection
  iceConnectionChanged:(RTCICEConnectionState)newState {
    switch (newState) {
        case RTCICEConnectionNew:
            NSLog(@"ICE state changed: RTCICEConnectionNew");
            break;
        case RTCICEConnectionChecking:
            NSLog(@"ICE state changed: RTCICEConnectionChecking");
            break;
        case RTCICEConnectionConnected:
            NSLog(@"ICE state changed: RTCICEConnectionConnected");
            break;
        case RTCICEConnectionCompleted:
            NSLog(@"ICE state changed: RTCICEConnectionCompleted");
            break;
        case RTCICEConnectionFailed:
            NSLog(@"ICE state changed: RTCICEConnectionFailed");
            break;
            
        default:
            NSLog(@"ICE state changed: %d", newState);
            break;
    }
}

- (void)peerConnection:(RTCPeerConnection *)peerConnection
   iceGatheringChanged:(RTCICEGatheringState)newState {
    switch (newState) {
        case RTCICEGatheringGathering:
            NSLog(@"ICE gathering state changed: RTCICEGatheringGathering");
            break;
        case RTCICEGatheringComplete:
            NSLog(@"ICE gathering state changed: RTCICEGatheringComplete");
            break;
        default:
            NSLog(@"ICE gathering state changed: %d", newState);
            break;
    }
}

- (void)peerConnection:(RTCPeerConnection *)peerConnection
       gotICECandidate:(RTCICECandidate *)candidate {
    dispatch_async(dispatch_get_main_queue(), ^{
        ARDICECandidateMessage *message = [[ARDICECandidateMessage alloc] initWithCandidate:candidate];
        [self sendSignalingMessage:message];
    });
}

- (void)peerConnection:(RTCPeerConnection*)peerConnection
    didOpenDataChannel:(RTCDataChannel*)dataChannel {
}

#pragma mark - RTCSessionDescriptionDelegate

- (void)peerConnection:(RTCPeerConnection *)peerConnection
didCreateSessionDescription:(RTCSessionDescription *)sdp
                 error:(NSError *)error {
    dispatch_async(dispatch_get_main_queue(), ^{
        if (error) {
            NSLog(@"Failed to create session description. Error: %@", error);
            [self disconnect];
            NSDictionary *userInfo = @{
                                       NSLocalizedDescriptionKey: @"Failed to create session description.",
                                       };
            NSError *sdpError =
            [[NSError alloc] initWithDomain:kARDAppClientErrorDomain
                                       code:kARDAppClientErrorCreateSDP
                                   userInfo:userInfo];
            [_delegate appClient:self didError:sdpError];
            return;
        }
        [_peerConnection setLocalDescriptionWithDelegate:self
                                      sessionDescription:sdp];
        ARDSessionDescriptionMessage *message =
        [[ARDSessionDescriptionMessage alloc] initWithDescription:sdp];
        [self sendSignalingMessage:message];
    });
}

- (void)peerConnection:(RTCPeerConnection *)peerConnection
didSetSessionDescriptionWithError:(NSError *)error {
    dispatch_async(dispatch_get_main_queue(), ^{
        if (error) {
            NSLog(@"Failed to set session description. Error: %@", error);
            [self disconnect];
            NSDictionary *userInfo = @{
                                       NSLocalizedDescriptionKey: @"Failed to set session description.",
                                       };
            NSError *sdpError =
            [[NSError alloc] initWithDomain:kARDAppClientErrorDomain
                                       code:kARDAppClientErrorSetSDP
                                   userInfo:userInfo];
            [_delegate appClient:self didError:sdpError];
            return;
        }
        // If we're answering and we've just set the remote offer we need to create
        // an answer and set the local description.
        if (!_isInitiator && !_peerConnection.localDescription) {
            RTCMediaConstraints *constraints = [self defaultAnswerConstraints];
            [_peerConnection createAnswerWithDelegate:self
                                          constraints:constraints];
            
        }
    });
}

#pragma mark - Private

- (BOOL)isRegisteredWithRoomServer {
    return _clientId.length;
}

- (void)startSignalingIfReady {
    if (!_isTurnComplete || !self.isRegisteredWithRoomServer) {
        return;
    }
    self.state = kARDAppClientStateConnected;
    
    // Create peer connection.
    RTCMediaConstraints *constraints = [self defaultPeerConnectionConstraints];
    _peerConnection = [_factory peerConnectionWithICEServers:_iceServers
                                                 constraints:constraints
                                                    delegate:self];
    RTCMediaStream *localStream = [self createLocalMediaStream];
    [_peerConnection addStream:localStream];
    if (_isInitiator) {
        [self sendOffer];
    } else {
        [self waitForAnswer];
    }
}

- (void)sendOffer {
    [_peerConnection createOfferWithDelegate:self
                                 constraints:[self defaultOfferConstraints]];
}

- (void)waitForAnswer {
    [self drainMessageQueueIfReady];
}

- (void)drainMessageQueueIfReady {
    if (!_peerConnection || !_hasReceivedSdp) {
        return;
    }
    for (ARDSignalingMessage *message in _messageQueue) {
        [self processSignalingMessage:message];
    }
    [_messageQueue removeAllObjects];
}

- (void)processSignalingMessage:(ARDSignalingMessage *)message {
    NSParameterAssert(_peerConnection ||
                      message.type == kARDSignalingMessageTypeBye);
    switch (message.type) {
        case kARDSignalingMessageTypeOffer:
        case kARDSignalingMessageTypeAnswer: {
            ARDSessionDescriptionMessage *sdpMessage =
            (ARDSessionDescriptionMessage *)message;
            RTCSessionDescription *description = sdpMessage.sessionDescription;
            [_peerConnection setRemoteDescriptionWithDelegate:self
                                           sessionDescription:description];
            break;
        }
        case kARDSignalingMessageTypeCandidate: {
            ARDICECandidateMessage *candidateMessage =
            (ARDICECandidateMessage *)message;
            [_peerConnection addICECandidate:candidateMessage.candidate];
            break;
        }
        case kARDSignalingMessageTypeBye:
            // Other client disconnected.
            // TODO(tkchin): support waiting in room for next client. For now just
            // disconnect.
            [self disconnect];
            break;
    }
}

- (void)sendSignalingMessage:(ARDSignalingMessage *)message {
    if (_isInitiator) {
        [self sendSignalingMessageToRoomServer:message completionHandler:nil];
    } else {
        [self sendSignalingMessageToCollider:message];
    }
}

- (RTCVideoTrack *)createLocalVideoTrack {
    // The iOS simulator doesn't provide any sort of camera capture
    // support or emulation (http://goo.gl/rHAnC1) so don't bother
    // trying to open a local stream.
    // TODO(tkchin): local video capture for OSX. See
    // https://code.google.com/p/webrtc/issues/detail?id=3417.
    
    RTCVideoTrack *localVideoTrack = nil;
#if !TARGET_IPHONE_SIMULATOR && TARGET_OS_IPHONE
    
    NSString *cameraID = nil;
    for (AVCaptureDevice *captureDevice in
         [AVCaptureDevice devicesWithMediaType:AVMediaTypeVideo]) {
        if (captureDevice.position == AVCaptureDevicePositionFront) {
            cameraID = [captureDevice localizedName];
            break;
        }
    }
    NSAssert(cameraID, @"Unable to get the front camera id");
    
    RTCVideoCapturer *capturer = [RTCVideoCapturer capturerWithDeviceName:cameraID];
    RTCMediaConstraints *mediaConstraints = [self defaultMediaStreamConstraints];
    RTCVideoSource *videoSource = [_factory videoSourceWithCapturer:capturer constraints:mediaConstraints];
    localVideoTrack = [_factory videoTrackWithID:@"ARDAMSv0" source:videoSource];
#endif
    return localVideoTrack;
}

- (RTCMediaStream *)createLocalMediaStream {
    RTCMediaStream* localStream = [_factory mediaStreamWithLabel:@"ARDAMS"];
    
    RTCVideoTrack *localVideoTrack = [self createLocalVideoTrack];
    if (localVideoTrack) {
        [localStream addVideoTrack:localVideoTrack];
        [_delegate appClient:self didReceiveLocalVideoTrack:localVideoTrack];
    }
    
    [localStream addAudioTrack:[_factory audioTrackWithID:@"ARDAMSa0"]];
    return localStream;
}

- (void)requestTURNServersWithURL:(NSURL *)requestURL
                completionHandler:(void (^)(NSArray *turnServers))completionHandler {
    NSParameterAssert([requestURL absoluteString].length);
    NSMutableURLRequest *request =
    [NSMutableURLRequest requestWithURL:requestURL];
    // We need to set origin because TURN provider whitelists requests based on
    // origin.
    [request addValue:@"Mozilla/5.0" forHTTPHeaderField:@"user-agent"];
    [request addValue:self.serverHostUrl forHTTPHeaderField:@"origin"];
    [NSURLConnection sendAsyncRequest:request
                    completionHandler:^(NSURLResponse *response,
                                        NSData *data,
                                        NSError *error) {
                        NSArray *turnServers = [NSArray array];
                        if (error) {
                            NSLog(@"Unable to get TURN server.");
                            completionHandler(turnServers);
                            return;
                        }
                        NSDictionary *dict = [NSDictionary dictionaryWithJSONData:data];
                        turnServers = [RTCICEServer serversFromCEODJSONDictionary:dict];
                        completionHandler(turnServers);
                    }];
}

#pragma mark - Room server methods

- (void)registerWithRoomServerForRoomId:(NSString *)roomId
                      completionHandler:(void (^)(ARDRegisterResponse *))completionHandler {
    NSString *urlString =
    [NSString stringWithFormat:kARDRoomServerRegisterFormat, self.serverHostUrl, roomId];
    NSURL *roomURL = [NSURL URLWithString:urlString];
    NSLog(@"Registering with room server.");
    __weak ARDAppClient *weakSelf = self;
    [NSURLConnection sendAsyncPostToURL:roomURL
                               withData:nil
                      completionHandler:^(BOOL succeeded, NSData *data) {
                          ARDAppClient *strongSelf = weakSelf;
                          if (!succeeded) {
                              NSError *error = [self roomServerNetworkError];
                              [strongSelf.delegate appClient:strongSelf didError:error];
                              completionHandler(nil);
                              return;
                          }
                          ARDRegisterResponse *response =
                          [ARDRegisterResponse responseFromJSONData:data];
                          completionHandler(response);
                      }];
}

- (void)sendSignalingMessageToRoomServer:(ARDSignalingMessage *)message
                       completionHandler:(void (^)(ARDMessageResponse *))completionHandler {
    NSData *data = [message JSONData];
    NSString *urlString =
    [NSString stringWithFormat:
     kARDRoomServerMessageFormat, self.serverHostUrl, _roomId, _clientId];
    NSURL *url = [NSURL URLWithString:urlString];
    NSLog(@"C->RS POST: %@", message);
    __weak ARDAppClient *weakSelf = self;
    [NSURLConnection sendAsyncPostToURL:url
                               withData:data
                      completionHandler:^(BOOL succeeded, NSData *data) {
                          ARDAppClient *strongSelf = weakSelf;
                          if (!succeeded) {
                              NSError *error = [self roomServerNetworkError];
                              [strongSelf.delegate appClient:strongSelf didError:error];
                              return;
                          }
                          ARDMessageResponse *response =
                          [ARDMessageResponse responseFromJSONData:data];
                          NSError *error = nil;
                          switch (response.result) {
                              case kARDMessageResultTypeSuccess:
                                  break;
                              case kARDMessageResultTypeUnknown:
                                  error =
                                  [[NSError alloc] initWithDomain:kARDAppClientErrorDomain
                                                             code:kARDAppClientErrorUnknown
                                                         userInfo:@{
                                                                    NSLocalizedDescriptionKey: @"Unknown error.",
                                                                    }];
                              case kARDMessageResultTypeInvalidClient:
                                  error =
                                  [[NSError alloc] initWithDomain:kARDAppClientErrorDomain
                                                             code:kARDAppClientErrorInvalidClient
                                                         userInfo:@{
                                                                    NSLocalizedDescriptionKey: @"Invalid client.",
                                                                    }];
                                  break;
                              case kARDMessageResultTypeInvalidRoom:
                                  error =
                                  [[NSError alloc] initWithDomain:kARDAppClientErrorDomain
                                                             code:kARDAppClientErrorInvalidRoom
                                                         userInfo:@{
                                                                    NSLocalizedDescriptionKey: @"Invalid room.",
                                                                    }];
                                  break;
                          };
                          if (error) {
                              [strongSelf.delegate appClient:strongSelf didError:error];
                          }
                          if (completionHandler) {
                              completionHandler(response);
                          }
                      }];
}

- (void)unregisterWithRoomServer {
    NSString *urlString =
    [NSString stringWithFormat:kARDRoomServerByeFormat, self.serverHostUrl, _roomId, _clientId];
    NSURL *url = [NSURL URLWithString:urlString];
    NSLog(@"C->RS: BYE");
    //Make sure to do a POST
    [NSURLConnection sendAsyncPostToURL:url withData:nil completionHandler:^(BOOL succeeded, NSData *data) {
        if (succeeded) {
            NSLog(@"Unregistered from room server.");
        } else {
            NSLog(@"Failed to unregister from room server.");
        }
    }];
}

- (NSError *)roomServerNetworkError {
    NSError *error =
    [[NSError alloc] initWithDomain:kARDAppClientErrorDomain
                               code:kARDAppClientErrorNetwork
                           userInfo:@{
                                      NSLocalizedDescriptionKey: @"Room server network error",
                                      }];
    return error;
}

#pragma mark - Collider methods

- (void)registerWithColliderIfReady {
    if (!self.isRegisteredWithRoomServer) {
        return;
    }
    // Open WebSocket connection.
    _channel =
    [[ARDWebSocketChannel alloc] initWithURL:_websocketURL
                                     restURL:_websocketRestURL
                                    delegate:self];
    [_channel registerForRoomId:_roomId clientId:_clientId];
}

- (void)sendSignalingMessageToCollider:(ARDSignalingMessage *)message {
    NSData *data = [message JSONData];
    [_channel sendData:data];
}

#pragma mark - Defaults

- (RTCMediaConstraints *)defaultMediaStreamConstraints {
    //
    RTCPair *localVideoMaxWidth = [[RTCPair alloc] initWithKey:@"maxWidth" value:@"320"];
    
    RTCPair *localVideoMinWidth = [[RTCPair alloc] initWithKey:@"minWidth" value:@"320"];
    
    RTCPair *localVideoMaxHeight = [[RTCPair alloc] initWithKey:@"maxHeight" value:@"240"];
    
    RTCPair *localVideoMinHeight = [[RTCPair alloc] initWithKey:@"minHeight" value:@"240"];
    
    //    RTCPair *localVideoMaxFrameRate = [[RTCPair alloc] initWithKey:@"maxFrameRate" value:@"30"];
    //
    //    RTCPair *localVideoMinFrameRate = [[RTCPair alloc] initWithKey:@"minFrameRate" value:@"5"];
    //
    //    RTCPair *localVideoGoogLeakyBucket = [[RTCPair alloc] initWithKey:@"googLeakyBucket" value:@"true"];
    
    RTCMediaConstraints *videoSourceConstraints = [[RTCMediaConstraints alloc] initWithMandatoryConstraints:@[localVideoMaxHeight, localVideoMaxWidth, localVideoMinHeight, localVideoMinWidth, /*localVideoMinFrameRate, localVideoMaxFrameRate, localVideoGoogLeakyBucket*/] optionalConstraints:nil];
    
    //
    //  RTCMediaConstraints* constraints =
    //      [[RTCMediaConstraints alloc]
    //          initWithMandatoryConstraints:nil
    //                   optionalConstraints:nil];
    return videoSourceConstraints;
}

- (RTCMediaConstraints *)defaultAnswerConstraints {
    return [self defaultOfferConstraints];
}

- (RTCMediaConstraints *)defaultOfferConstraints {
    NSArray *mandatoryConstraints = @[
                                      [[RTCPair alloc] initWithKey:@"OfferToReceiveAudio" value:@"true"],
                                      [[RTCPair alloc] initWithKey:@"OfferToReceiveVideo" value:@"true"]
                                      ];
    RTCMediaConstraints* constraints =
    [[RTCMediaConstraints alloc]
     initWithMandatoryConstraints:mandatoryConstraints
     optionalConstraints:nil];
    return constraints;
}

- (RTCMediaConstraints *)defaultPeerConnectionConstraints {
    NSArray *optionalConstraints = @[
                                     [[RTCPair alloc] initWithKey:@"DtlsSrtpKeyAgreement" value:@"true"]
                                     ];
    RTCMediaConstraints* constraints =
    [[RTCMediaConstraints alloc]
     initWithMandatoryConstraints:nil
     optionalConstraints:optionalConstraints];
    return constraints;
}

- (RTCICEServer *)defaultSTUNServer {
    NSURL *defaultSTUNServerURL = [NSURL URLWithString:kARDDefaultSTUNServerUrl];
    return [[RTCICEServer alloc] initWithURI:defaultSTUNServerURL
                                    username:@""
                                    password:@""];
}

#pragma mark - Audio in mute/unmute
- (void)muteAudioIn{
    NSLog(@"audio in muted");
    RTCMediaStream *localStream = _peerConnection.localStreams[0];
    self.defaultAudioTrack = localStream.audioTracks[0];
    [localStream removeAudioTrack:localStream.audioTracks[0]];
    [_peerConnection removeStream:localStream];
    [_peerConnection addStream:localStream];
}
- (void)unmuteAudioIn{
    NSLog(@"audio in muted");
    RTCMediaStream* localStream = _peerConnection.localStreams[0];
    [localStream addAudioTrack:self.defaultAudioTrack];
    [_peerConnection removeStream:localStream];
    [_peerConnection addStream:localStream];
}

#pragma mark - Video mute/unmute
- (void)muteVideoIn{
    NSLog(@"audio-in muted");
    RTCMediaStream *localStream = _peerConnection.localStreams[0];
    self.defaultVideoTrack = localStream.videoTracks[0];
    [localStream removeVideoTrack:localStream.videoTracks[0]];
    [_peerConnection removeStream:localStream];
    [_peerConnection addStream:localStream];
}
- (void)unmuteVideoIn{
    NSLog(@"video-in muted");
    RTCMediaStream* localStream = _peerConnection.localStreams[0];
    [localStream addVideoTrack:self.defaultVideoTrack];
    [_peerConnection removeStream:localStream];
    [_peerConnection addStream:localStream];
}

#pragma mark - swap camera
- (RTCVideoTrack *)createLocalVideoTrackBackCamera {
    RTCVideoTrack *localVideoTrack = nil;
#if !TARGET_IPHONE_SIMULATOR && TARGET_OS_IPHONE
    //AVCaptureDevicePositionFront
    NSString *cameraID = nil;
    for (AVCaptureDevice *captureDevice in
         [AVCaptureDevice devicesWithMediaType:AVMediaTypeVideo]) {
        if (captureDevice.position == AVCaptureDevicePositionBack) {
            cameraID = [captureDevice localizedName];
            break;
        }
    }
    NSAssert(cameraID, @"Unable to get the back camera id");
    
    RTCVideoCapturer *capturer = [RTCVideoCapturer capturerWithDeviceName:cameraID];
    RTCMediaConstraints *mediaConstraints = [self defaultMediaStreamConstraints];
    RTCVideoSource *videoSource = [_factory videoSourceWithCapturer:capturer constraints:mediaConstraints];
    localVideoTrack = [_factory videoTrackWithID:@"ARDAMSv0" source:videoSource];
#endif
    return localVideoTrack;
}
- (void)swapCameraToFront{
    RTCMediaStream *localStream = _peerConnection.localStreams[0];
    [localStream removeVideoTrack:localStream.videoTracks[0]];
    
    RTCVideoTrack *localVideoTrack = [self createLocalVideoTrack];

    if (localVideoTrack) {
        [localStream addVideoTrack:localVideoTrack];
        [_delegate appClient:self didReceiveLocalVideoTrack:localVideoTrack];
    }
    [_peerConnection removeStream:localStream];
    [_peerConnection addStream:localStream];
}
- (void)swapCameraToBack{
    RTCMediaStream *localStream = _peerConnection.localStreams[0];
    [localStream removeVideoTrack:localStream.videoTracks[0]];
    
    RTCVideoTrack *localVideoTrack = [self createLocalVideoTrackBackCamera];
    
    if (localVideoTrack) {
        [localStream addVideoTrack:localVideoTrack];
        [_delegate appClient:self didReceiveLocalVideoTrack:localVideoTrack];
    }
    [_peerConnection removeStream:localStream];
    [_peerConnection addStream:localStream];
}
@end
