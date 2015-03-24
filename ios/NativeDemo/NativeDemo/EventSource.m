//
//  EventSource.m
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

#import "EventSource.h"

@interface EventSource () <NSURLConnectionDelegate>

@property NSURLConnection *connection;
@property NSString *currentEventName;
@property NSMutableArray *data;

@end

@implementation EventSource

- (instancetype)initWithURL:(NSURL *)url delegate:(id <EventSourceDelegate>)delegate
{
    self = [super init];
    if (self) {
        self.delegate = delegate;
        NSURLRequest *request = [NSURLRequest requestWithURL:url];
        self.connection = [[NSURLConnection alloc] initWithRequest:request delegate:self];
    }
    return self;
}

- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data
{
    NSString *string = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    NSArray *lines = [string componentsSeparatedByString:@"\n"];
    for (NSString *line in lines) {
        [self appendLine:line];
    }
}

- (void)appendLine:(NSString *)line
{
    if (!self.currentEventName) {
        if ([line hasPrefix:@"event:"]) {
            self.currentEventName = [line substringFromIndex:6];
            if ([self.currentEventName length] == 0) {
                self.currentEventName = nil;
                return;
            }
            self.data = [NSMutableArray new];
        } else if ([line length] > 1) {
            NSLog(@"[EventSource] invalid line, expected event: %@", line);
        }
    } else {
        if ([line hasPrefix:@"data:"]) {
            [self.data addObject:[NSMutableString stringWithString:[line substringFromIndex:5]]];
        } else if ([line length] == 0) {
            NSString* dataConcat = [self.data componentsJoinedByString:@"\n"];
            [self.delegate eventSource:self didReceiveEvent:self.currentEventName withData:dataConcat];
            self.currentEventName = nil;
            self.data = nil;
        } else {
            NSLog(@"[EventSource] invalid line, expected data: %@", line);
            [self.data.lastObject appendString:line];
        }
    }
}

- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error
{
    [self.delegate eventSource:self didFailWithError:error];
}

- (void)disconnect
{
    [self.connection cancel];
}

@end
