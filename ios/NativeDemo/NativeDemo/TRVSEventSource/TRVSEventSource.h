//
//  TRVSEventSourceManager.h
//  TRVSEventSource
//
//  Created by Travis Jeffery on 10/8/13.
//  Copyright (c) 2013 Travis Jeffery. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "TRVSEventSourceDelegate.h"
#import "TRVSServerSentEvent.h"

@class TRVSServerSentEvent;

typedef void (^TRVSEventSourceEventHandler)(TRVSServerSentEvent *event, NSError *error);


/**
 `TRVSEventSource` is an Objective-C implementation of the EventSource DOM interface supported by modern browsers.
 
 An event source opens an HTTP connection, and receives events as they are sent from the server. Each event is encoded as an `TRVSServerSentEvent` object, and dispatched to all listeners for that particular event type.
 
 @see http://www.w3.org/TR/eventsource/
 */
@interface TRVSEventSource : NSObject <NSURLSessionDelegate, NSURLSessionDataDelegate, NSCopying, NSCoding>

// The URL the event source receives events from.
@property (nonatomic, strong, readonly) NSURL *URL;
// The managed session.
@property (nonatomic, strong, readonly) NSURLSession *URLSession;
// The task used to connect to the URL and receive event data.
@property (nonatomic, strong, readonly) NSURLSessionTask *URLSessionTask;
// The operation queue on which delegate callbacks are run.
@property (nonatomic, strong, readonly) NSOperationQueue *operationQueue;
// The delegate you're using that's responsible for what to do when the event source state changes or receives events.
@property (nonatomic, weak) id<TRVSEventSourceDelegate> delegate;

// @name connection state

// The connection state can be in only one state at any given time.
- (BOOL)isConnecting;
- (BOOL)isOpen;
- (BOOL)isClosed;
- (BOOL)isClosing;

// @name initializing an event source

/**
 *  Initializes an `TRVSEventSource` object with the specified URL. The event source will open only by calling -[TRVSEventSource open].
 *
 *  @param URL The url the event source will receive events from.
 *
 *  @return The newly-initialized event source.
 */
- (instancetype)initWithURL:(NSURL *)URL;

/**
 *  Initializes an `TRVSEventSource` object with the specified URL and session configuration. The event source will open only by calling -[TRVSEventSource open].
 *
 *  @param URL The url the event source will receive events from.
 *
 *  @param sessionConfiguration The session configuration that will be used to initialize the session object.
 *
 *  @return The newly-initialized event source.
 */
- (instancetype)initWithURL:(NSURL *)URL sessionConfiguration:(NSURLSessionConfiguration *)sessionConfiguration;

// @name opening and closing an event source

/**
 *  Opens a connection to the `URL` to receive events. The request specifies an `Accept` HTTP header field value of `text/event-stream`.
 */
- (void)open;

/**
 *  Closes the connection.
 */
- (void)close;

// @name listening for events

/**
 *  Adds a listener to the event source thats runs the `eventHandler` block whenever an event is received with the given `event` name.
 *
 *  @param event        The name of the event to listen for.
 *  @param eventHandler The block to run when events with the given name are received.
 *
 *  @return The identifier associated with the listener for the specified event. Pass this to `-[TRVSEventSource removeEventListenerWithIdentifier:]` to remove the listener.
 */
- (NSUInteger)addListenerForEvent:(NSString *)event
                usingEventHandler:(TRVSEventSourceEventHandler)eventHandler;

/**
 Removes the event listener with the given identifier
 
 @param identifier The identifier associated with the event listener.
 
 @discussion The event listener identifier is returned when added with `-[TRVSEventSource addListenerForEvent:usingBlock:]`.
 */
- (void)removeEventListenerWithIdentifier:(NSUInteger)identifier;

/**
 * Removes all listeners for events of the given type.
 */
- (void)removeAllListenersForEvent:(NSString *)event;

@end
