//
//  OpenWebRTCViewController.m
//
//  Copyright (c) 2014, Ericsson AB.
//  All rights reserved.
//
//  Redistribution and use in source and binary forms, with or without modification,
//  are permitted provided that the following conditions are met:
//
//  1. Redistributions of source code must retain the above copyright notice, this
//  list of conditions and the following disclaimer.
//
//  2. Redistributions in binary form must reproduce the above copyright notice, this
//  list of conditions and the following disclaimer in the documentation and/or other
//  materials provided with the distribution.

//  THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
//  ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
//  WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED.
//  IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT,
//  INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT
//  NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR
//  PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY,
//  WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
//  ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY
//  OF SUCH DAMAGE.
//

#import "OpenWebRTCViewController.h"
#import <AVFoundation/AVAudioSession.h>

#include <owr_bridge.h>

#define kBridgeLocalURL @"http://localhost:10717/owr.js"

@interface OpenWebRTCViewController ()
{
    NSString *_URL;
}

@end

@implementation OpenWebRTCViewController

+ (void)initOpenWebRTC
{
    owr_bridge_start_in_thread();

    NSError* theError = nil;
    BOOL result = YES;

    [[UIApplication sharedApplication] setIdleTimerDisabled:YES];
    [[UIApplication sharedApplication] setStatusBarStyle:UIStatusBarStyleLightContent];

    AVAudioSession *myAudioSession = [AVAudioSession sharedInstance];

    result = [myAudioSession setCategory:AVAudioSessionCategoryPlayAndRecord error:&theError];
    if (!result) {
        NSLog(@"setCategory failed");
    }

    result = [myAudioSession setActive:YES error:&theError];
    if (!result) {
        NSLog(@"setActive failed");
    }
}

- (void)viewDidLoad
{
    [super viewDidLoad];

    self.javascriptCode = @
        "(function () {"
        "    if (window.RTCPeerConnection)"
        "        return \"\";"
        "    var xhr = new XMLHttpRequest();"
        "    xhr.open(\"GET\", \"" kBridgeLocalURL "\", false);"
        "    xhr.send();"
        "    eval(xhr.responseText);"
        "    return \"ok\";"
        "})()";

    self.browserView.owrDelegate = self;

    // Setup native video rendering.
    /*
    owr_window_registry_register(owr_window_registry_get(),
                                 kSelfViewTag,
                                 (__bridge gpointer)(self.selfView));
    owr_window_registry_register(owr_window_registry_get(),
                                 kRemoteViewTag,
                                 (__bridge gpointer)(self.remoteView));

    renderer = owr_video_renderer_new(kSelfViewTag);
    g_assert(renderer);
    g_object_set(renderer, "width", 1280, "height", 720, "max-framerate", 60.0, NULL);
    */
}

- (void)loadRequestWithURL:(NSString *)url
{
    _URL = url;
    NSURLRequest *request = [NSURLRequest requestWithURL:[NSURL URLWithString:url]
                                             cachePolicy:NSURLRequestUseProtocolCachePolicy
                                         timeoutInterval:10];
    [self.browserView loadRequest:request];
}

- (void)insertJavascript:(NSTimer*)theTimer
{
    if ([self.browserView isOnPageWithURL:_URL]) {
        NSLog(@"injecting bootstrap script");
        if ([self.browserView stringByEvaluatingJavaScriptFromString:self.javascriptCode].length > 0) {
            NSLog(@"stopping timer");
            [theTimer invalidate];
        }
    }
}

#pragma mark webview delegate stuff

- (void)webViewDidStartLoad:(OpenWebRTCWebView *)webView
{
    [[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:YES];
    NSLog(@"webViewDidStartLoading...");

    if (pageNavigationTimer.isValid)
        [pageNavigationTimer invalidate];

    NSLog(@"creating timer");
    pageNavigationTimer = [NSTimer scheduledTimerWithTimeInterval:0
                                                           target:self
                                                         selector:@selector(insertJavascript:)
                                                         userInfo:nil
                                                          repeats:YES];
    [self newVideoRect:CGRectZero forSelfView:YES];
    [self newVideoRect:CGRectZero forSelfView:NO];
}

- (BOOL)webView:(UIWebView *)webView shouldStartLoadWithRequest:(NSURLRequest *)request navigationType:(UIWebViewNavigationType)navigationType
{
    return YES;
}

- (void)newVideoRect:(CGRect)rect forSelfView:(BOOL)rectIsSelfView
{
    if (rectIsSelfView) {
        self.selfView.frame = rect;
    } else {
        self.remoteView.frame = rect;
    }
}

- (void)webviewProgress:(float)progress
{

}

- (void)webViewDidFinishLoad:(UIWebView *)webView
{
    NSURL *currentURL = webView.request.URL;
    [[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:NO];

    NSLog(@"webViewDidFinishLoading... %@", currentURL.absoluteString);

    if (pageNavigationTimer.isValid)
        [pageNavigationTimer invalidate];
}

- (void)webView:(UIWebView *)webView didFailLoadWithError:(NSError *)error
{
    [[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:NO];
    [pageNavigationTimer invalidate];
    NSLog(@"WEBVIEW LOADING ERROR ---- %@", [error description]);
    if (error.code == -999) {
        NSLog(@"Error: %@", error.localizedDescription);
        return;
    }
    [[[UIAlertView alloc] initWithTitle:@"Could not load webpage"
                                message:error.localizedDescription
                               delegate:nil
                      cancelButtonTitle:@"Close"
                      otherButtonTitles: nil] show];
}

@end
