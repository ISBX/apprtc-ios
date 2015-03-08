# AppRTC - iOS implementation of the Google WebRTC Demo

## About
This Xcode project is a wrapper for the Google's WebRTC Demo. It organizes the WebRTC components into a cocoa pod that can be easily deployed into any Xcode project. The precompiled libWebRTC static library bundled with the pod works with 64-bit apps, unlike prior versions of WebRTC projects where only the 32-bit version was available. Currently, the project is designed to run on iOS Devices (iOS Simulator is not supported).

Included in this Xcode project is a native Storyboard based Room Locator and Video Chat View Controllers:

## Features
* 64-bit support
* pre-compiled libWebRTC.a (saves you hours of compiling)
* Cocoa Pod 
* Supports the most recent https://apprtc.appspot.com/ (March 2015)
* We also have a fork of the [Google AppRTC Web Server](https://github.com/ISBX/apprtc-server) that maintains full compatibility with this project

## Notes
The following resources were useful in helping get this project to where it is today:
* [How to get started with WebRTC and iOS without wasting 10 hours of your life](http://ninjanetic.com/how-to-get-started-with-webrtc-and-ios-without-wasting-10-hours-of-your-life/)
* [hiroeorz's AppRTCDemo Project](https://github.com/hiroeorz/AppRTCDemo)

## Installation
