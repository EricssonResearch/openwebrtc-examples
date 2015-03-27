//
//  VideoAttributes.m
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

#import "VideoAttributes.h"

@implementation VideoAttributes

static NSDictionary *modesDictionary;

+ (NSDictionary *)modesDictionary
{
    if (!modesDictionary) {
        modesDictionary = @{@"QCIF":@[@"176", @"144"],
                            @"QVGA":@[@"320", @"240"],
                            @"CIF":@[@"352", @"288"],
                            @"360p":@[@"640", @"360"],
                            @"VGA":@[@"640", @"480"],
                            @"720p":@[@"1280", @"720"],
                            @"1080p":@[@"1920", @"1080"]};
    }
    return modesDictionary;
}

+ (VideoAttributes *)loadFromSettings
{
    // Decide on video attributes.
    VideoAttributes *attrs = [[VideoAttributes alloc] init];

    NSString *videoResolution = [[NSUserDefaults standardUserDefaults] stringForKey:@"video_resolution"];
    [attrs setResolutionFromMode:videoResolution];

    if ([[NSUserDefaults standardUserDefaults] stringForKey:@"video_bitrate"]) {
        attrs.bitrate = [[[NSUserDefaults standardUserDefaults] stringForKey:@"video_bitrate"] integerValue];
    } else {
        NSLog(@"WARNING! No bitrate (video_bitrate) specified in Settings, using %d." , kVideoBitrate);
        attrs.bitrate = kVideoBitrate;
    }

    attrs.framerate = [[[NSUserDefaults standardUserDefaults] stringForKey:@"video_fps"] integerValue];
    if (!attrs.framerate) {
        attrs.framerate = 25;
    }

    return attrs;
}

- (NSDictionary *)toDictionary
{
    NSMutableDictionary *dict = [NSMutableDictionary dictionary];
    [dict setValue:[NSNumber numberWithInteger:self.width] forKey:@"width"];
    [dict setValue:[NSNumber numberWithInteger:self.height] forKey:@"height"];
    [dict setValue:[NSNumber numberWithInteger:self.framerate] forKey:@"framerate"];
    [dict setValue:[NSNumber numberWithInteger:self.bitrate] forKey:@"bitrate"];
    [dict setObject:self.mode forKey:@"mode"];
    return dict;
}

- (void)setResolutionFromMode:(NSString *)mode
{
    if (![[VideoAttributes modesDictionary] valueForKey:mode]) {
        NSLog(@"WARNING! No video resolution for mode: %@ (using default VGA)", mode);
        mode = @"VGA";
    }
    self.mode = mode;

    NSArray *size = [VideoAttributes modesDictionary][mode];
    self.width = [size[0] integerValue];
    self.height = [size[1] integerValue];
}

- (NSString *)description
{
    return [NSString stringWithFormat:@"%@", [self toDictionary]];
}

@end