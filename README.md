# AppRTC - iOS implementation of the Google WebRTC Demo

## About
This Xcode project is a wrapper for the Google's WebRTC Demo. It organizes the WebRTC components into a cocoa pod that can be easily deployed into any Xcode project. The precompiled libWebRTC static library bundled with the pod works with 64-bit apps, unlike prior versions of WebRTC projects where only the 32-bit version was available. Currently, the project is designed to run on iOS Devices (iOS Simulator is not supported).

Included in this Xcode project is a native Storyboard based Room Locator and Video Chat View Controllers:

## Features
* 64-bit support
* pre-compiled libWebRTC.a (saves you hours of compiling)
* Cocoa Pod 
* Supports the most recent https://apprtc.appspot.com (March 2015)
* We also have a fork of the [Google AppRTC Web Server](https://github.com/ISBX/apprtc-server) that maintains full compatibility with this project

## Notes
The following resources were useful in helping get this project to where it is today:
* [How to get started with WebRTC and iOS without wasting 10 hours of your life](http://ninjanetic.com/how-to-get-started-with-webrtc-and-ios-without-wasting-10-hours-of-your-life/)
* [hiroeorz's AppRTCDemo Project](https://github.com/hiroeorz/AppRTCDemo)

## Running the AppRTC App on your iOS Device
To run the app on your iPhone or Ipad you can fork this repository and open the `AppRTC.xcworkspace` in Xcode and compile onto your iOS Device to check it out. By default the server address is set to https://apprtc.appspot.com.

## Using the AppRTC Pod in your App
If you'd like to incorporate WebRTC Video Chat into your own application, you can install the AppRTC pod:
```
pod install AppRTC
```
#### Initialize SSL Peer Connection
WebRTC can communicate securely over SSL. You'll need to modify your `AppDelegate.m` class with the following:
1. Import the RTCPeerConnectionFactory.h
```
#import "RTCPeerConnectionFactory.h"
```
2. Add the following to your `application:didFinishLaunchingWithOptions:` method:
```objective-c
    [RTCPeerConnectionFactory initializeSSL];
```
3. Add the following to your `applicationWillTerminate:` method:
```objective-c
    [RTCPeerConnectionFactory deinitializeSSL];
```

#### Add Video Chat
To add video chat to your app you will need 2 views:
* Local Video View - Where the video is rendered from your device camera
* Remote Video View - where the video is rendered for the remote camera

To do this, perform the followng:

[TBD]

## Contributing
[TBD]

## Known Issues
The following are known issues that are being worked and should be released shortly:
* Audio Mute needs to be implemented
* Video Mute needs to be implemented
* Does now allow rejoining a room (reports back room is full error)
* Video is not correctly oriented in Landscape
