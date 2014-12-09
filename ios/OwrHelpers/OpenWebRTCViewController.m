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
#include <owr/owr.h>
#include <owr/owr_local.h>
#include <owr/owr_window_registry.h>

#define kBridgeLocalURL @"http://localhost:10717/owr.js"

@interface OpenWebRTCViewController ()
{
    NSString *_URL;

    NSMutableDictionary *renderers;
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

- (void)userContentController:(WKUserContentController *)userContentController didReceiveScriptMessage:(WKScriptMessage *)message
{
    NSDictionary *msg = (NSDictionary *)[message body];
    NSLog(@"OWR message: %@", msg);

    NSString *tag = msg[@"tag"];
    if (!tag)
        return;

    /* Check if renderer has already been set up. */
    if (![renderers valueForKey:tag]) {
        id renderView = [@"capture" isEqualToString:msg[@"sourceType"]] ? self.selfView : self.remoteView;
        owr_window_registry_register(owr_window_registry_get(),
                                     [tag UTF8String],
                                     (__bridge gpointer)(renderView));

        [renderers setObject:msg[@"sourceType"] forKey:tag];
        self.browserView.hidden = YES;
        self.selfView.hidden = NO;
    }
}

- (void)viewDidLoad
{
    [super viewDidLoad];

    renderers = [NSMutableDictionary dictionary];

    self.javascriptCode = @
        "(function () {"
        "    var xhr = new XMLHttpRequest();"
        "    xhr.open(\"GET\", \"" kBridgeLocalURL "\", false);"
        "    xhr.send();"
        "    eval(xhr.responseText);"
        "})()";

    self.browserView = [[OpenWebRTCWebView alloc] initWithFrame:self.view.frame];
    [self.view addSubview:self.browserView];

    self.browserView.owrDelegate = self;
    self.browserView.navigationDelegate = self;

    WKUserScript *userScript = [[WKUserScript alloc] initWithSource:self.javascriptCode
                                                      injectionTime:WKUserScriptInjectionTimeAtDocumentStart
                                                   forMainFrameOnly:YES];
    [self.browserView.configuration.userContentController addUserScript:userScript];

    [self.browserView.configuration.userContentController addScriptMessageHandler:self name:@"owr"];
}

- (void)loadRequestWithURL:(NSString *)url
{
    _URL = url;
    NSURLRequest *request = [NSURLRequest requestWithURL:[NSURL URLWithString:url]
                                             cachePolicy:NSURLRequestUseProtocolCachePolicy
                                         timeoutInterval:10];
    [self.browserView loadRequest:request];
}

@end
