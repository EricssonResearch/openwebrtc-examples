//
//  NativeDemoViewController.m
//  NativeDemo
//
//  Copyright (c) 2015, Ericsson AB.
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

#import "NativeDemoViewController.h"
#import "PeerServerHandler.h"

#import <OpenWebRTC-SDK/OpenWebRTC.h>

//#define kServerURL @"http://demo.openwebrtc.io:38080"
//#define kServerURL @"http://localhost:8080"
#define kServerURL @"http://129.192.20.149:8080"

@interface NativeDemoViewController () <PeerServerHandlerDelegate, OpenWebRTCNativeHandlerDelegate>
{
    IBOutlet UIBarButtonItem *callButton;
    IBOutlet UIBarButtonItem *hangupButton;

    OpenWebRTCNativeHandler *nativeHandler;
}

@property (weak) IBOutlet OpenWebRTCVideoView *selfView;
@property (weak) IBOutlet OpenWebRTCVideoView *remoteView;

@property (nonatomic, strong) NSString *roomID;
@property (nonatomic, strong) NSString *peerID;
@property (nonatomic, strong) PeerServerHandler *peerServer;

@end

@implementation NativeDemoViewController

- (void)viewDidLoad
{
    [super viewDidLoad];

    [self.navigationController setToolbarHidden:NO animated:NO];

    nativeHandler = [[OpenWebRTCNativeHandler alloc] initWithDelegate:self];

    // Setup the video windows.
    self.selfView.transform = CGAffineTransformMakeRotation(M_PI_2);
    self.selfView.hidden = YES;
    [nativeHandler setSelfView:self.selfView];
    [nativeHandler setRemoteView:self.remoteView];

    [nativeHandler addSTUNServerWithAddress:@"mmt-stun.verkstad.net"
                                       port:3478];
    [nativeHandler addTURNServerWithAddress:@"mmt-turn.verkstad.net"
                                       port:443
                                   username:@"webrtc"
                                   password:@"secret"
                                      isTCP:NO];

    callButton.enabled = hangupButton.enabled = NO;

    self.peerServer = [[PeerServerHandler alloc] initWithBaseURL:kServerURL];
    self.peerServer.delegate = self;
}

- (void)viewDidAppear:(BOOL)animated
{
    [self presentRoomInputView];
}

- (void)presentRoomInputView
{
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Enter Room ID"
                                                                   message:@"Use the same ID to connect 2 clients"
                                                            preferredStyle:UIAlertControllerStyleAlert];

    UIAlertAction *ok = [UIAlertAction actionWithTitle:@"Done"
                                                 style:UIAlertActionStyleDefault
                                               handler:^(UIAlertAction * action) {
                                                   UITextField *roomTextField = alert.textFields[0];
                                                   NSString *room = [roomTextField text];
                                                   if (![@"" isEqualToString:room])
                                                       [self joinButtonTapped:room];
                                                   else
                                                       [self presentRoomInputView];
                                               }];
    [alert addAction:ok];
    [alert addTextFieldWithConfigurationHandler:^(UITextField *textField) {
        textField.keyboardType = UIKeyboardTypeNumberPad;
    }];

    [self presentViewController:alert animated:YES completion:nil];
}

- (void)joinButtonTapped:(NSString *)roomID
{
    NSLog(@"Joining room with ID: %@", roomID);
    self.roomID = roomID;

    [nativeHandler startGetCaptureSourcesForAudio:NO video:YES];

    NSString *deviceID = [[[UIDevice currentDevice] identifierForVendor] UUIDString];
    [self.peerServer joinRoom:roomID withDeviceID:deviceID];
}

- (IBAction)callButtonTapped:(id)sender
{
    callButton.enabled = NO;
    hangupButton.enabled = YES;

    [nativeHandler initiateCall];
}

- (IBAction)hangupButtonTapped:(id)sender
{
    exit(0); // Nice :)
}

- (void)didReceiveMemoryWarning
{
    NSLog(@"WARNING! didReceiveMemoryWarning");
    [super didReceiveMemoryWarning];
}

- (void)presentErrorWithMessage:(NSString *)message
{
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Error!"
                                                                   message:message
                                                            preferredStyle:UIAlertControllerStyleAlert];

    UIAlertAction *ok = [UIAlertAction actionWithTitle:@"OK"
                                                 style:UIAlertActionStyleDefault
                                               handler:^(UIAlertAction * action) {

                                               }];
    [alert addAction:ok];
    [self presentViewController:alert animated:YES completion:nil];
}

#pragma mark - OpenWebRTCNativeHandlerDelegate

- (void)answerGenerated:(NSString *)answer
{
    NSLog(@"Answer generated: \n%@", answer);
    if (self.peerID) {
        [self.peerServer sendMessage:answer toPeer:self.peerID];
    }
}

- (void)offerGenerated:(NSString *)offer
{
    NSLog(@"Offer generated: \n%@", offer);
    if (self.peerID) {
        [self.peerServer sendMessage:offer toPeer:self.peerID];
    }
}

- (void)candidateGenerate:(NSString *)candidate
{
    NSLog(@"Candidate generated: \n%@", candidate);
    if (self.peerID) {
        NSLog(@"Sending candidate to peer: %@", self.peerID);
        [self.peerServer sendMessage:candidate toPeer:self.peerID];
    }
}

- (void)gotLocalSources
{
    self.selfView.hidden = NO;
}

#pragma mark - PeerServerHandlerDelegate

- (void)peerServer:(PeerServerHandler *)peerServer failedToJoinRoom:(NSString *)roomID withError:(NSError *)error
{
    [self presentErrorWithMessage:error.description];
}

- (void)peerServer:(PeerServerHandler *)peerServer roomIsFull:(NSString *)roomID
{
    NSLog(@"roomIsFull: %@", roomID);
}

- (void)peerServer:(PeerServerHandler *)peerServer peer:(NSString *)peerID joinedRoom:(NSString *)roomID
{
    callButton.enabled = YES;
    self.peerID = peerID;

    NSLog(@"peer <%@> joinedRoom: %@", peerID, roomID);
}

- (void)peerServer:(PeerServerHandler *)peerServer peer:(NSString *)peerID leftRoom:(NSString *)roomID
{
    NSLog(@"peer <%@> leftRoom: %@", peerID, roomID);
    self.peerID = nil;
}

- (void)peerServer:(PeerServerHandler *)peerServer peer:(NSString *)peerID sentOffer:(NSString *)offer
{
    NSLog(@"peer <%@> sentOffer: %@", peerID, offer);
    [nativeHandler handleOfferReceived:offer];
}

- (void)peerServer:(PeerServerHandler *)peerServer peer:(NSString *)peerID sentCandidate:(NSDictionary *)candidate
{
    NSLog(@"peer <%@> sentCandidate: %@", peerID, candidate);
    [nativeHandler handleRemoteCandidateReceived:candidate];
}

- (void)peerServer:(PeerServerHandler *)peerServer failedToSendDataWithError:(NSError *)error
{
    [self presentErrorWithMessage:error.description];
}

@end
