//
//  PeerServerHandler.m
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

#import "PeerServerHandler.h"
#import "EventSource.h"

#define kEventSourceURL @"%@/stoc/%@/%@"

@interface PeerServerHandler () <EventSourceDelegate>

@property (nonatomic, strong) EventSource *eventSource;
@property (nonatomic, strong) NSString *baseURL;
@property (nonatomic, strong) NSString *currentRoomID;

@end

@implementation PeerServerHandler

- (instancetype)initWithBaseURL:(NSString *)baseURL
{
    if (self = [super init]) {
        _baseURL = baseURL;
    }
    return self;
}

- (void)joinRoomWithID:(NSString *)roomID
{
    self.currentRoomID = roomID;

    NSString *deviceID = [[[UIDevice currentDevice] identifierForVendor] UUIDString];
    NSString *eventSourceURL = [NSString stringWithFormat:kEventSourceURL, self.baseURL, roomID, deviceID, nil];

    self.eventSource = [[EventSource alloc] initWithURL:[NSURL URLWithString:eventSourceURL]
                                               delegate:self];
}

#pragma mark - EventSource

- (void)eventSource:(EventSource *)eventSource didFailWithError:(NSError *)error
{
    NSLog(@"[PeerServerHandler] EventSource didFailWithError: %@", error);
    [self.delegate peerServer:self failedToJoinRoom:self.currentRoomID withError:error];
}

- (void)eventSource:(EventSource *)eventSource didReceiveEvent:(NSString *)event withData:(NSString *)data
{
    //NSLog(@"[PeerServerHandler] didReceiveEvent: %@ - %@", event, data);

    if ([@"join" isEqualToString:event]) {
        [self.delegate peerServer:self peer:data joinedRoom:self.currentRoomID];
    } else if ([@"leave" isEqualToString:event]) {
        [self.delegate peerServer:self peer:data leftRoom:self.currentRoomID];
    } else if ([@"sessionfull" isEqualToString:event]) {
        [self.delegate peerServer:self roomIsFull:self.currentRoomID];
    } else if ([event hasPrefix:@"user"]) {
        // Events on the form: user-78ba491c
        NSString *peerUser = [event componentsSeparatedByString:@"-"][0];

        NSError *error = nil;
        NSDictionary *json = [NSJSONSerialization JSONObjectWithData:[data dataUsingEncoding:NSUTF8StringEncoding]
                                                             options:0
                                                               error:&error];
        if (error || !json) {
            [self eventSource:eventSource didFailWithError:error];
            return;
        }

        if (json[@"sdp"]) {
            [self.delegate peerServer:self peer:peerUser sentOffer:json[@"sdp"][@"sdp"]];
        } else if (json[@"candidate"]) {
            [self.delegate peerServer:self peer:peerUser sentCandidate:json];
        }
    }
}

- (void)leave
{
    if (self.eventSource) {
        [self.eventSource disconnect];
        self.eventSource = nil;
    }
    self.currentRoomID = nil;
}

@end
