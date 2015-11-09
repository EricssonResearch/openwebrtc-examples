//
//  SelfViewController.m
//  Selfie
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

#import "SelfViewController.h"
#import <OpenWebRTC-SDK/OpenWebRTC.h>


@interface SelfViewController () <OpenWebRTCNativeHandlerDelegate>
{
    OpenWebRTCNativeHandler *nativeHandler;
}

@property (weak) IBOutlet OpenWebRTCVideoView *selfView;
@property (weak, nonatomic) IBOutlet UISegmentedControl *cameraSelector;
@property (strong) NSMutableDictionary *segments;
@property (weak, nonatomic) IBOutlet UIButton *rotation;
@property (weak, nonatomic) IBOutlet UIButton *mirror;

@end

@implementation SelfViewController


- (IBAction)cameraSelected:(id)sender
{
    NSString *key = [[self.segments allKeys] objectAtIndex:self.cameraSelector.selectedSegmentIndex];
    [nativeHandler setVideoCaptureSourceByName:key];
}

- (IBAction)onMirror:(UIButton *)sender
{
    static BOOL isMirrored = false;
    [nativeHandler videoView:self.selfView setMirrored:isMirrored = !isMirrored];
}

- (IBAction)onRotate:(UIButton *)sender
{
    static int rotation = 0;
    [nativeHandler videoView:self.selfView setVideoRotation:rotation += 90];
}

- (void)viewDidLoad
{
    [super viewDidLoad];

    [OpenWebRTC initialize];

    self.segments = [NSMutableDictionary dictionary];

    nativeHandler = [[OpenWebRTCNativeHandler alloc] initWithDelegate:self];

    OpenWebRTCSettings *settings = [[OpenWebRTCSettings alloc] initWithDefaults];
    settings.videoFramerate = 30.0;
    settings.videoWidth = 1280;
    settings.videoHeight = 720;
    nativeHandler.settings = settings;

    [nativeHandler setSelfView:self.selfView];
    [nativeHandler startGetCaptureSourcesForAudio:NO video:YES];

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(updateVideoRotation)
                                                 name:UIDeviceOrientationDidChangeNotification
                                               object:nil];
}

- (void)updateVideoRotation
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
}

- (void)gotLocalSources:(NSArray *)sources
{
    NSLog(@"gotLocalSources: %@", sources);

    for (NSDictionary *source in sources) {
        [self.segments setObject:source[@"source"] forKey:source[@"name"]];
    }

    dispatch_async(dispatch_get_main_queue(), ^{
        [self.cameraSelector removeAllSegments];
        for (NSString *item in self.segments) {
            [self.cameraSelector insertSegmentWithTitle:item atIndex:self.cameraSelector.numberOfSegments animated:NO];
        }
        self.cameraSelector.selectedSegmentIndex = 1;
    });

    [nativeHandler videoView:self.selfView setVideoRotation:0];
}

// The methods below are not needed in this app.
- (void)answerGenerated:(NSDictionary *)answer
{

}

- (void)offerGenerated:(NSDictionary *)offer
{

}

- (void)candidateGenerate:(NSString *)candidate
{

}

- (void)gotRemoteSource:(NSDictionary *)source
{

}

@end
