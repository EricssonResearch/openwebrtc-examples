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
#import "VideoAttributes.h"

#import <OpenWebRTC-SDK/OpenWebRTC.h>

#define kServerURL @"http://demo.openwebrtc.org:38080"

@interface NativeDemoViewController () <PeerServerHandlerDelegate, OpenWebRTCNativeHandlerDelegate>
{
    IBOutlet UIBarButtonItem *callButton;
    IBOutlet UIBarButtonItem *hangupButton;

    OpenWebRTCNativeHandler *nativeHandler;
    NSMutableArray *cameras;
    NSUInteger currentCameraIndex;
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

    // Configure OpenWebRTC with media settings.
    VideoAttributes *attrs = [VideoAttributes loadFromSettings];
    NSLog(@"Video settings: %@", attrs);

    OpenWebRTCSettings *settings = [[OpenWebRTCSettings alloc] initWithDefaults];
    settings.videoFramerate = attrs.framerate;
    settings.videoBitrate = (int)attrs.bitrate;
    settings.videoWidth = (int)attrs.width;
    settings.videoHeight = (int)attrs.height;
    nativeHandler.settings = settings;

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(sendCurrentOrientation)
                                                 name:UIDeviceOrientationDidChangeNotification
                                               object:nil];
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

    [nativeHandler startGetCaptureSourcesForAudio:YES video:YES];

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
    [nativeHandler terminateCall];
    [self.peerServer leave];

    callButton.enabled = NO;
    hangupButton.enabled = NO;

    [self presentRoomInputView];
}

- (IBAction)selfViewTapped:(id)sender
{
    if ([cameras count] != 2) {
        NSLog(@"WARNING! Camera switching needs 2 cameras to work");
        return;
    }

    currentCameraIndex = !currentCameraIndex;
    [nativeHandler setVideoCaptureSourceByName:cameras[currentCameraIndex]];

    [UIView transitionWithView:self.selfView
                      duration:0.6
                       options:UIViewAnimationOptionTransitionFlipFromTop
                    animations:nil
                    completion:nil];
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
                                               handler:nil];
    [alert addAction:ok];
    [self presentViewController:alert animated:YES completion:nil];
}

#pragma mark - OpenWebRTCNativeHandlerDelegate

- (void)answerGenerated:(NSDictionary *)answer
{
    NSLog(@"Answer generated: \n%@", answer);

    NSDictionary *d = @{@"sdp": answer};
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:d
                                                       options:NSJSONWritingPrettyPrinted
                                                         error:nil];
    NSString *answerString = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];

    if (self.peerID) {
        [self.peerServer sendMessage:answerString toPeer:self.peerID];
    }
}

- (void)offerGenerated:(NSDictionary *)offer
{
    NSLog(@"Offer generated: \n%@", offer);

    NSDictionary *d = @{@"sdp": offer};
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:d
                                                       options:NSJSONWritingPrettyPrinted
                                                         error:nil];
    NSString *offerString = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];

    if (self.peerID) {
        [self.peerServer sendMessage:offerString toPeer:self.peerID];
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

- (void)gotLocalSources:(NSArray *)sources
{
    NSLog(@"gotLocalSources: %@", sources);

    cameras = [NSMutableArray arrayWithCapacity:[sources count]];
    for (NSDictionary *source in sources) {
        if ([source[@"mediaType"] isEqualToString:@"video"]) {
            [cameras addObject:source[@"name"]];
        }
    }
    NSLog(@"Found cameras: %@", cameras);
    currentCameraIndex = 0;

    [nativeHandler videoView:self.selfView setVideoRotation:0];
    self.selfView.hidden = NO;
}

- (void)gotRemoteSource:(NSDictionary *)source
{
    NSLog(@"gotRemoteSource: %@", source);
    callButton.enabled = NO;
    hangupButton.enabled = YES;

    [self sendCurrentOrientation];
}

- (void)sendCurrentOrientation
{
    NSInteger orientation;
    switch ([[UIDevice currentDevice] orientation]) {
        case UIDeviceOrientationLandscapeLeft:
            orientation = 180;
            break;
        case UIDeviceOrientationLandscapeRight:
            orientation = 0;
            break;
        case UIDeviceOrientationPortrait:
            orientation = 90;
            break;
        case UIDeviceOrientationPortraitUpsideDown:
            orientation = 270;
            break;
        default:
            orientation = 0;
            break;
    };

    [nativeHandler videoView:self.selfView setVideoRotation:orientation - 90];

    NSString *message = [NSString stringWithFormat:@"{\"orientation\": %ld}", (long)orientation];
    if (self.peerID) {
        NSLog(@"[PeerServerHandler] Sending orientation msg: %@", message);
        [self.peerServer sendMessage:message toPeer:self.peerID];
    }
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
    NSLog(@"peer <%@> joinedRoom: %@", peerID, roomID);

    callButton.enabled = YES;
    self.peerID = peerID;

    [self sendCurrentOrientation];
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

- (void)peerServer:(PeerServerHandler *)peerServer peer:(NSString *)peerID sentAnswer:(NSString *)answer
{
    NSLog(@"peer <%@> sentAnswer: %@", peerID, answer);
    [nativeHandler handleAnswerReceived:answer];
}

- (void)peerServer:(PeerServerHandler *)peerServer peer:(NSString *)peerID sentCandidate:(NSDictionary *)candidate
{
    NSLog(@"peer <%@> sentCandidate: %@", peerID, candidate);
    [nativeHandler handleRemoteCandidateReceived:candidate];
}

- (void)peerServer:(PeerServerHandler *)peerServer peer:(NSString *)peerID sentOrientation:(NSInteger)orientation
{
    NSLog(@"Rotating remote view to: %ld", (long)orientation);
    [nativeHandler videoView:self.remoteView setVideoRotation:orientation];
}

- (void)peerServer:(PeerServerHandler *)peerServer failedToSendDataWithError:(NSError *)error
{
    [self presentErrorWithMessage:error.description];
}

@end
