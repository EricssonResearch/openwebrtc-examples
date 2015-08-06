# NativeDemo for iOS
Fully native (Objective-C and C) app that connects to [http://demo.openwebrtc.org](http://demo.openwebrtc.org). The client on the other side can either use a WebRTC-enabled browser, such as Chrome or Firefox, or another instance of the app installed on second device.

## Installation

The app uses the `OpenWebRTC` and `OpenWebRTC-SDK` CocoaPods from [https://github.com/EricssonResearch/openwebrtc-ios-sdk](https://github.com/EricssonResearch/openwebrtc-ios-sdk). Since `OpenWebRTC-SDK` is (still) a local podspec file you need to clone `openwebrtc-ios-sdk` before you can run NativeDemo.

If you haven't installed CocoaPods yet, do so first:

    sudo gem install cocoapods
    pod setup

Then run:

    pod install
    open NativeDemo.xcworkspace

**NOTE!** When using CocoaPods, you should always use the `.xcworkspace` file and not the usual `.xcproject`.
