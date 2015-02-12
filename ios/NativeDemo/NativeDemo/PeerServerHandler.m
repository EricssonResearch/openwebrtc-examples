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
#import "TRVSEventSource.h" // From https://github.com/travisjeffery/TRVSEventSource

#define kEventSourceURL @"%@/stoc/%@/%@"


@interface PeerServerHandler () <TRVSEventSourceDelegate>
{

}

@property (nonatomic, strong) TRVSEventSource *eventSource;
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

    TRVSEventSource *eventSource = [[TRVSEventSource alloc] initWithURL:[NSURL URLWithString:eventSourceURL]];
    NSLog(@"[PeerServerHandler] Connecting to server at: %@", eventSourceURL);

    /**
     * Join a room.
     */
    [eventSource addListenerForEvent:@"join" usingEventHandler:^(TRVSServerSentEvent *event, NSError *error) {
        //NSDictionary *JSON = [NSJSONSerialization JSONObjectWithData:event.data options:0 error:NULL];

        NSString *data = [NSString stringWithUTF8String:[event.data bytes]];
        NSLog(@"[PeerServerHandler] Received JOIN response with data: %@", data);

        NSString *peerUserID = [NSString stringWithFormat:@"user-%@", data];

        if (self.delegate) {
            [self.delegate peerServer:self peer:peerUserID joinedRoom:self.currentRoomID];
        }

        [self performSelector:@selector(joinEventSourceChannelWithPeerID:) withObject:peerUserID];
    }];

    /**
     * Peer leaves room.
     */
    [eventSource addListenerForEvent:@"leave" usingEventHandler:^(TRVSServerSentEvent *event, NSError *error) {
        //NSDictionary *JSON = [NSJSONSerialization JSONObjectWithData:event.data options:0 error:NULL];
        NSString *data = [NSString stringWithUTF8String:[event.data bytes]];
        NSLog(@"[PeerServerHandler] Received LEAVE with data: %@", data);

        NSString *peerUserID = [NSString stringWithFormat:@"user-%@", data];

        if (self.delegate) {
            [self.delegate peerServer:self peer:peerUserID leftRoom:self.currentRoomID];
        }

        [self performSelector:@selector(removeEventSourceListenerWithName:) withObject:peerUserID];
    }];

    /**
     * Room is full.
     */
    [eventSource addListenerForEvent:@"sessionfull" usingEventHandler:^(TRVSServerSentEvent *event, NSError *error) {
        //NSDictionary *JSON = [NSJSONSerialization JSONObjectWithData:event.data options:0 error:NULL];
        NSString *data = [NSString stringWithUTF8String:[event.data bytes]];
        NSLog(@"[PeerServerHandler] Received SESSIONFULL with data: %@", data);

        if (self.delegate) {
            [self.delegate peerServer:self roomIsFull:self.currentRoomID];
        }
    }];

    self.eventSource = eventSource;
    [self.eventSource setDelegate:self];
    [self.eventSource open];
}

- (void)removeEventSourceListenerWithName:(NSString *)eventName
{
    NSLog(@"[PeerServerHandler] Removing listener for: %@", eventName);
    [self.eventSource removeAllListenersForEvent:eventName];
}

- (void)joinEventSourceChannelWithPeerID:(NSString *)peerID
{
    PeerServerHandler *weakSelf = self;
    [self.eventSource addListenerForEvent:peerID usingEventHandler:^(TRVSServerSentEvent *event, NSError *error) {
        //NSDictionary *JSON = [NSJSONSerialization JSONObjectWithData:event.data options:0 error:NULL];
        NSString *data = [NSString stringWithUTF8String:[event.data bytes]];
        NSLog(@"[PeerServerHandler] Received DATA frome peer: %@", data);

        NSDictionary *JSON = [NSJSONSerialization JSONObjectWithData:event.data options:0 error:NULL];
        NSLog(@"JSON:\n%@", JSON);
        if ([@"OFFER" isEqualToString:JSON[@"messageType"]]) {
            NSLog(@"[PeerServerHandler] OFFER received");

            if (weakSelf.delegate) {
                [weakSelf.delegate peerServer:weakSelf peer:peerID sentOffer:JSON];
            }
        }
    }];
}

#pragma mark - TRVSEventSourceDelegate methods

- (void)eventSourceDidOpen:(TRVSEventSource *)eventSource
{
    if (self.delegate) {
        [self.delegate peerServer:self successfullyJoinedRoom:self.currentRoomID];
    }
}

- (void)eventSource:(TRVSEventSource *)eventSource didFailWithError:(NSError *)error
{
    NSLog(@"[PeerServerHandler] An error occurred: %@", error);
}


@end
