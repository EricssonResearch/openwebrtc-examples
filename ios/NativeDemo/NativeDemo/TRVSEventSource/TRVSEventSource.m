//
//  TRVSEventSourceManager.m
//  TRVSEventSource
//
//  Created by Travis Jeffery on 10/8/13.
//  Copyright (c) 2013 Travis Jeffery. All rights reserved.
//

#import "TRVSEventSource.h"

static NSUInteger const TRVSEventSourceListenersCapacity = 100;
static NSString *const TRVSEventSourceOperationQueueName =
    @"com.travisjeffery.TRVSEventSource.operationQueue";

static NSDictionary *TRVSServerSentEventFieldsFromData(
    NSData *data,
    NSError *__autoreleasing *error) {
  if (!data || [data length] == 0)
    return nil;

  NSString *string =
      [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
  NSMutableDictionary *mutableFields = [NSMutableDictionary dictionary];

  for (NSString *line in [string componentsSeparatedByCharactersInSet:
                                     [NSCharacterSet newlineCharacterSet]]) {
    if (!line || [line length] == 0 || [line hasPrefix:@":"])
      continue;

    @autoreleasepool {
      NSScanner *scanner = [[NSScanner alloc] initWithString:line];
      scanner.charactersToBeSkipped = [NSCharacterSet whitespaceCharacterSet];
      NSString *key, *value;
      [scanner scanUpToString:@":" intoString:&key];
      [scanner scanString:@":" intoString:nil];
      [scanner scanUpToString:@"\n" intoString:&value];

      if (key && value) {
        if (mutableFields[key]) {
          mutableFields[key] =
              [mutableFields[key] stringByAppendingFormat:@"\n%@", value];
        } else {
          mutableFields[key] = value;
        }
      }
    }
  }

  return mutableFields;
}

typedef NS_ENUM(NSUInteger, TRVSEventSourceState) {
  TRVSEventSourceConnecting = 0,
  TRVSEventSourceOpen,
  TRVSEventSourceClosed,
  TRVSEventSourceClosing,
  TRVSEventSourceFailed
};

@interface TRVSEventSource ()<NSStreamDelegate>

@property (nonatomic, strong, readwrite) NSOperationQueue *operationQueue;
@property (nonatomic, strong, readwrite) NSURL *URL;
@property (nonatomic, strong, readwrite) NSURLSession *URLSession;
@property (nonatomic, strong, readwrite) NSURLSessionTask *URLSessionTask;
@property (nonatomic, readwrite) TRVSEventSourceState state;
@property (nonatomic, strong, readwrite) NSMapTable *listenersKeyedByEvent;
@property (nonatomic, strong, readwrite) NSOutputStream *outputStream;
@property (nonatomic, readwrite) NSUInteger offset;

@end

@implementation TRVSEventSource

#pragma mark - Public

- (instancetype)initWithURL:(NSURL *)URL {
  return [self initWithURL:URL
      sessionConfiguration:NSURLSessionConfiguration
                               .defaultSessionConfiguration];
}

- (instancetype)initWithURL:(NSURL *)URL
       sessionConfiguration:(NSURLSessionConfiguration *)sessionConfiguration {
  if (!(self = [super init]))
    return nil;

  _operationQueue = [[NSOperationQueue alloc] init];
  _operationQueue.name = TRVSEventSourceOperationQueueName;
  _URL = URL;
  _listenersKeyedByEvent =
      [[NSMapTable alloc] initWithKeyOptions:NSPointerFunctionsCopyIn
                                valueOptions:NSPointerFunctionsStrongMemory
                                    capacity:TRVSEventSourceListenersCapacity];
  _URLSession = [NSURLSession sessionWithConfiguration:sessionConfiguration
                                              delegate:self
                                         delegateQueue:_operationQueue];

  return self;
}

- (void)open {
  [self transitionToConnecting];
}

- (void)close {
  [self transitionToClosing];
}

- (NSUInteger)addListenerForEvent:(NSString *)event
                usingEventHandler:(TRVSEventSourceEventHandler)eventHandler {
  NSMutableDictionary *mutableListenersKeyedByIdentifier =
      [self.listenersKeyedByEvent objectForKey:event];
  if (!mutableListenersKeyedByIdentifier)
    mutableListenersKeyedByIdentifier = [NSMutableDictionary dictionary];

  NSUInteger identifier = [[NSUUID UUID] hash];
  mutableListenersKeyedByIdentifier[@(identifier)] = [eventHandler copy];

  [self.listenersKeyedByEvent setObject:mutableListenersKeyedByIdentifier
                                 forKey:event];

  return identifier;
}

- (void)removeEventListenerWithIdentifier:(NSUInteger)identifier {
  NSEnumerator *enumerator = [self.listenersKeyedByEvent keyEnumerator];
  id event = nil;

  while ((event = [enumerator nextObject])) {
    NSMutableDictionary *mutableListenersKeyedByIdentifier =
        [self.listenersKeyedByEvent objectForKey:event];

    if ([mutableListenersKeyedByIdentifier objectForKey:@(identifier)]) {
      [mutableListenersKeyedByIdentifier removeObjectForKey:@(identifier)];
      [self.listenersKeyedByEvent setObject:mutableListenersKeyedByIdentifier
                                     forKey:event];
      return;
    }
  }
}

- (void)removeAllListenersForEvent:(NSString *)event {
  [self.listenersKeyedByEvent removeObjectForKey:event];
}

#pragma mark - State

- (BOOL)isConnecting {
  return self.state == TRVSEventSourceConnecting;
}

- (BOOL)isOpen {
  return self.state == TRVSEventSourceOpen;
}

- (BOOL)isClosed {
  return self.state == TRVSEventSourceClosed;
}

- (BOOL)isClosing {
  return self.state == TRVSEventSourceClosing;
}

#pragma mark - NSURLSessionDelegate

- (void)URLSession:(NSURLSession *)session
          dataTask:(NSURLSessionDataTask *)dataTask
    didReceiveData:(NSData *)data {
  NSUInteger length = data.length;
  while (YES) {
    NSInteger totalNumberOfBytesWritten = 0;
    if (self.outputStream.hasSpaceAvailable) {
      const uint8_t *dataBuffer = (uint8_t *)[data bytes];

      NSInteger numberOfBytesWritten = 0;
      while (totalNumberOfBytesWritten < (NSInteger)length) {
        numberOfBytesWritten =
            [self.outputStream write:&dataBuffer[0] maxLength:length];
        if (numberOfBytesWritten == -1) {
          return;
        } else {
          totalNumberOfBytesWritten += numberOfBytesWritten;
        }
      }

      break;
    }
  }
}

- (void)URLSession:(NSURLSession *)session
              dataTask:(NSURLSessionDataTask *)dataTask
    didReceiveResponse:(NSURLResponse *)response
     completionHandler:
         (void (^)(NSURLSessionResponseDisposition))completionHandler {
  completionHandler(NSURLSessionResponseAllow);
  [self transitionToOpenIfNeeded];
}

- (void)URLSession:(NSURLSession *)session
                    task:(NSURLSessionTask *)task
    didCompleteWithError:(NSError *)error {
  if (self.isClosing && error.code == NSURLErrorCancelled) {
    [self transitionToClosed];
  } else {
    [self transitionToFailedWithError:error];
  }
}

#pragma mark - NSStreamDelegate

- (void)stream:(NSStream *)stream handleEvent:(NSStreamEvent)eventCode {
  switch (eventCode) {
    case NSStreamEventHasSpaceAvailable: {
      NSData *data =
          [stream propertyForKey:NSStreamDataWrittenToMemoryStreamKey];
      NSError *error = nil;
      TRVSServerSentEvent *event = [TRVSServerSentEvent
          eventWithFields:TRVSServerSentEventFieldsFromData(
                              [data subdataWithRange:NSMakeRange(
                                                         self.offset,
                                                         [data length] -
                                                             self.offset)],
                              &error)];
      self.offset = [data length];

      if (error)
        [self transitionToFailedWithError:error];

      if (error || !event)
        break;

      [[self.listenersKeyedByEvent objectForKey:event.event]
          enumerateKeysAndObjectsUsingBlock:
              ^(id _, TRVSEventSourceEventHandler eventHandler, BOOL *stop) {
                  eventHandler(event, nil);
              }];

      if ([self.delegate
              respondsToSelector:@selector(eventSource:didReceiveEvent:)]) {
        [self.delegate eventSource:self didReceiveEvent:event];
      }

      break;
    }
    case NSStreamEventErrorOccurred: {
      [self transitionToFailedWithError:self.outputStream.streamError];

      break;
    }
    default:
      break;
  }
}

#pragma NSCoding

- (id)initWithCoder:(NSCoder *)aDecoder {
  NSURL *URL = [aDecoder decodeObjectForKey:@"URL"];

  if (!(self = [self initWithURL:URL]))
    return nil;

  return self;
}

- (void)encodeWithCoder:(NSCoder *)aCoder {
  [aCoder encodeObject:self.URL forKey:@"URL"];
}

#pragma NSCopying

- (id)copyWithZone:(NSZone *)zone {
  return [[[self class] allocWithZone:zone] initWithURL:self.URL];
}

#pragma mark - Private

- (void)transitionToOpenIfNeeded {
  if (self.state != TRVSEventSourceConnecting)
    return;

  self.state = TRVSEventSourceOpen;

  if ([self.delegate respondsToSelector:@selector(eventSourceDidOpen:)]) {
    [self.delegate eventSourceDidOpen:self];
  }
}

- (void)transitionToFailedWithError:(NSError *)error {
  self.state = TRVSEventSourceFailed;

  if ([self.delegate
          respondsToSelector:@selector(eventSource:didFailWithError:)]) {
    [self.delegate eventSource:self didFailWithError:error];
  }
}

- (void)transitionToClosed {
  self.state = TRVSEventSourceClosed;

  if ([self.delegate respondsToSelector:@selector(eventSourceDidClose:)]) {
    [self.delegate eventSourceDidClose:self];
  }
}

- (void)transitionToConnecting {
  self.state = TRVSEventSourceConnecting;
  [self setupOutputStream];
  self.URLSessionTask = [self.URLSession dataTaskWithURL:self.URL];
  [self.URLSessionTask resume];
}

- (void)transitionToClosing {
  self.state = TRVSEventSourceClosing;
  [self closeOutputStream];
  [self.URLSession invalidateAndCancel];
}

- (void)setupOutputStream {
  self.outputStream = [NSOutputStream outputStreamToMemory];
  self.outputStream.delegate = self;
  [self.outputStream scheduleInRunLoop:[NSRunLoop currentRunLoop]
                               forMode:NSDefaultRunLoopMode];
  [self.outputStream open];
}

- (void)closeOutputStream {
  self.outputStream.delegate = nil;
  [self.outputStream removeFromRunLoop:[NSRunLoop currentRunLoop]
                               forMode:NSDefaultRunLoopMode];
  [self.outputStream close];
}

@end
