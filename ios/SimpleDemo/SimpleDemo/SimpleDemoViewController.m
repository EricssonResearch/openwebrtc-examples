//
//  SimpleDemoViewController.m
//  SimpleDemo
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

#import "SimpleDemoViewController.h"

@interface SimpleDemoViewController ()
{
    IBOutlet UISlider *roomSlider;
    IBOutlet UILabel *roomLabel;
    IBOutlet UIBarButtonItem *joinButton;
    IBOutlet UIBarButtonItem *callButton;
    IBOutlet UIBarButtonItem *hangupButton;
}

@end

@implementation SimpleDemoViewController

- (void)viewDidLoad
{
    [super viewDidLoad];

    [self.navigationController setToolbarHidden:NO animated:NO];

    joinButton.enabled = callButton.enabled = hangupButton.enabled = NO;

    // TODO: Send selfView and remoteView ref to OpenWebRTC.
    [self loadRequestWithURL:@"http://demo.openwebrtc.org"];

    self.browserView.hidden = NO;
}

- (void)webView:(WKWebView *)webView didFinishNavigation:(WKNavigation *)navigation
{
    joinButton.enabled = YES;
}

- (IBAction)joinButtonTapped:(id)sender
{
    int room = [roomSlider value];
    NSString *js = [NSString stringWithFormat:@"document.getElementById('session_txt').value='%d';document.getElementById('join_but').click();", room];
    [self.browserView evaluateJavaScript:js completionHandler:nil];

    joinButton.enabled = NO;
    callButton.enabled = YES;
}

- (IBAction)callButtonTapped:(id)sender
{
    callButton.enabled = NO;
    hangupButton.enabled = YES;
}

- (IBAction)hangupButtonTapped:(id)sender
{
    exit(0); // Nice :)
}

- (IBAction)sliderValueChanged:(UISlider *)sender
{
    int sliderValue = (int)sender.value;
    roomLabel.text = [NSString stringWithFormat:@"%d", sliderValue];
}

- (void)didReceiveMemoryWarning
{
    NSLog(@"WARNING! didReceiveMemoryWarning");
    [super didReceiveMemoryWarning];
}

@end
