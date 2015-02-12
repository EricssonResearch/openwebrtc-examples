//
//  TRVSServerSentEvent.h
//  TRVSEventSource
//
//  Created by Travis Jeffery on 10/8/13.
//  Copyright (c) 2013 Travis Jeffery. All rights reserved.
//

#import <Foundation/Foundation.h>


/**
 `TRVSServerSentEvent` objects represent events received from the server by an event source. A server-sent event has associated `event` type, an `identifier`, associated `data`, and a `retry` inteval. Any additional fields not defined by the EventSource API spec are stored in a `userInfo` dictionary.
 */
@interface TRVSServerSentEvent : NSObject <NSCoding, NSCopying>

// The event type.
@property (nonatomic, copy, readonly) NSString *event;

// The event identifier.
@property (nonatomic, copy, readonly) NSString *identifier;

// The retry interval sent with the event.
@property (nonatomic, readonly) NSTimeInterval retry;

// The data associated with the event.
@property (nonatomic, copy, readonly) NSData *data;

// Any additional fields in the event.
@property (nonatomic, copy, readonly) NSDictionary *userInfo;

// Creates and returns event associated with the given fields.
+ (instancetype)eventWithFields:(NSDictionary *)fields;

@end
