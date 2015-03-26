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
#define kSendMessageURL @"%@/ctos/%@/%@/%@"

@interface PeerServerHandler () <EventSourceDelegate, NSURLConnectionDelegate>

@property (nonatomic, strong) EventSource *eventSource;
@property (nonatomic, strong) NSString *baseURL;
@property (nonatomic, strong) NSString *deviceID;
@property (nonatomic, strong) NSString *currentRoomID;
@property (nonatomic, strong) NSMutableArray *sendQueue;

@end

@implementation PeerServerHandler

- (instancetype)initWithBaseURL:(NSString *)baseURL
{
    if (self = [super init]) {
        _baseURL = baseURL;
    }
    return self;
}

- (void)joinRoom:(NSString *)roomID withDeviceID:(NSString *)deviceID
{
    self.currentRoomID = roomID;
    self.deviceID = deviceID;
    NSString *eventSourceURL = [NSString stringWithFormat:kEventSourceURL, self.baseURL, roomID, deviceID, nil];

    self.eventSource = [[EventSource alloc] initWithURL:[NSURL URLWithString:eventSourceURL]
                                               delegate:self];
}

- (NSMutableArray *)sendQueue
{
    if (!_sendQueue) {
        _sendQueue = [NSMutableArray array];
    }
    return _sendQueue;
}

#pragma mark - EventSource

- (void)eventSource:(EventSource *)eventSource didFailWithError:(NSError *)error
{
    NSLog(@"[PeerServerHandler] EventSource didFailWithError: %@", error);
    [self.delegate peerServer:self failedToJoinRoom:self.currentRoomID withError:error];
}

- (void)eventSource:(EventSource *)eventSource didReceiveEvent:(NSString *)event withData:(NSString *)data
{
    if ([@"join" isEqualToString:event]) {
        [self.delegate peerServer:self peer:data joinedRoom:self.currentRoomID];
    } else if ([@"leave" isEqualToString:event]) {
        [self.delegate peerServer:self peer:data leftRoom:self.currentRoomID];
    } else if ([@"sessionfull" isEqualToString:event]) {
        [self.delegate peerServer:self roomIsFull:self.currentRoomID];
    } else if ([event hasPrefix:@"user"]) {
        // Events on the form: user-78ba491c
        NSString *peerUser = [event componentsSeparatedByString:@"-"][1];

        NSError *error = nil;
        NSDictionary *json = [NSJSONSerialization JSONObjectWithData:[data dataUsingEncoding:NSUTF8StringEncoding]
                                                             options:0
                                                               error:&error];
        if (error || !json) {
            NSLog(@"[PeerServerHandler] ###################### Got INVALID json: %@", data);
            [self eventSource:eventSource didFailWithError:error];
            return;
        }

        if (json[@"sdp"]) {
            NSString *type = json[@"type"];
            if ([@"offer" isEqualToString:type]) {
                [self.delegate peerServer:self peer:peerUser sentOffer:json[@"sdp"][@"sdp"]];
            } else if ([@"answer" isEqualToString:type]) {
                [self.delegate peerServer:self peer:peerUser sentAnswer:json[@"sdp"][@"sdp"]];
            } else {
                NSLog(@"[PeerServerHandler] WARNING! Got malformed offer/answer from peer");
            }
        } else if (json[@"candidate"]) {
            [self.delegate peerServer:self peer:peerUser sentCandidate:json[@"candidate"]];
        } else if (json[@"orientation"]) {
            NSInteger orientation = [json[@"orientation"] integerValue];
            [self.delegate peerServer:self peer:peerUser sentOrientation:orientation];
        } else {
            NSLog(@"[PeerServerHandler] WARNING! Received unsupported message: %@", json);
        }
    } else {
        NSLog(@"Unsupported message received: %@", event);
    }
}

- (void)processSendQueue
{
    NSDictionary *currentMessage = self.sendQueue[0];
    [self.sendQueue removeObjectAtIndex:0];

    NSString *url = [NSString stringWithFormat:kSendMessageURL, self.baseURL, self.currentRoomID, self.deviceID, currentMessage[@"peerID"], nil];

    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:url]];
    request.HTTPMethod = @"POST";
    [request setValue:@"text/plain" forHTTPHeaderField:@"Content-Type"];

    NSString *stringData = currentMessage[@"message"];
    NSData *requestBodyData = [stringData dataUsingEncoding:NSUTF8StringEncoding];
    request.HTTPBody = requestBodyData;

    NSURLConnection *conn = [[NSURLConnection alloc] initWithRequest:request delegate:self];
    [conn start];
}

- (void)sendMessage:(NSString *)message toPeer:(NSString *)peerID
{
    [self.sendQueue addObject:@{@"peerID": peerID, @"message": message}];

    if ([self.sendQueue count] == 1) {
        [self processSendQueue];
    }
}

- (void)leave
{
    [self.sendQueue removeAllObjects];

    if (self.eventSource) {
        [self.eventSource disconnect];
        self.eventSource = nil;
    }
    self.currentRoomID = nil;
}

- (void)maybeSendNextMessage
{
    if ([self.sendQueue count] > 0) {
        [self processSendQueue];
    }
}

#pragma mark NSURLConnection Delegate Methods

- (NSCachedURLResponse *)connection:(NSURLConnection *)connection
                  willCacheResponse:(NSCachedURLResponse*)cachedResponse
{
    return nil;
}

- (void)connectionDidFinishLoading:(NSURLConnection *)connection
{
    NSLog(@"[PeerServerHandler] Message successfully sent to peer");
    [self maybeSendNextMessage];
}

- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error
{
    NSLog(@"[PeerServerHandler] WARNING! Failed to send data to peer: %@", error);
    [self maybeSendNextMessage];
}

@end
