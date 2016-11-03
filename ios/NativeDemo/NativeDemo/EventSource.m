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

@interface EventSource () <NSURLSessionDataDelegate>

@property (strong, nonatomic) NSURLSession *session;

@property (strong, nonatomic) NSURLSessionDataTask *dataTask;

@property (strong, nonatomic) NSString *currentEventName;

@property (strong, nonatomic) NSMutableArray *data;

@end

@implementation EventSource

#pragma mark - Class life cycle

- (instancetype)initWithURL:(NSURL *)url delegate:(id <EventSourceDelegate>)delegate {
    self = [super init];
    if (self) {
        _delegate = delegate;
        
        // Initialize default session
        _session = [NSURLSession sessionWithConfiguration:[NSURLSessionConfiguration defaultSessionConfiguration]
                                                 delegate:self
                                            delegateQueue:[NSOperationQueue mainQueue]];
        
        _dataTask = [_session dataTaskWithURL:url];
        
        // Init session task
        [_dataTask resume];
    }
    
    return self;
}

- (void)dealloc {
    _currentEventName = nil;
    
    [_data removeAllObjects];
    _data = nil;
}

#pragma mark - NSURLSessionData delegate

- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)dataTask didReceiveResponse:(NSURLResponse *)response completionHandler:(void (^)(NSURLSessionResponseDisposition))completionHandler {
    NSLog(@"[EventSource] response => %@", response.description);
    
    // Allow to receive data
    completionHandler(NSURLSessionResponseAllow);
}

- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)dataTask didReceiveData:(NSData *)data {
    NSString *string = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    NSArray *lines = [string componentsSeparatedByString:@"\n"];
    NSLog(@"[EventSource] received data: %@", string);
    for (NSString *line in lines) {
        [self appendLine:line];
    }
}

- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didCompleteWithError:(nullable NSError *)error {
    [self.delegate eventSource:self didFailWithError:error];
}

#pragma mark - Support methods

- (void)appendLine:(NSString *)line {
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

- (void)disconnect {
    if (self.dataTask) {
        [self.dataTask cancel];
        self.dataTask = nil;
    }
}

@end
