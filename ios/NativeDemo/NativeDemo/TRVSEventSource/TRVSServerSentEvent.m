//
//  TRVSServerSentEvent.m
//  TRVSEventSource
//
//  Created by Travis Jeffery on 10/8/13.
//  Copyright (c) 2013 Travis Jeffery. All rights reserved.
//

#import "TRVSServerSentEvent.h"

@interface TRVSServerSentEvent ()

@property (nonatomic, copy, readwrite) NSString *event;
@property (nonatomic, copy, readwrite) NSString *identifier;
@property (nonatomic, readwrite) NSTimeInterval retry;
@property (nonatomic, copy, readwrite) NSData *data;
@property (nonatomic, copy, readwrite) NSDictionary *userInfo;

@end

@implementation TRVSServerSentEvent

+ (instancetype)eventWithFields:(NSDictionary *)fields {
    if (!fields) return nil;
    
    TRVSServerSentEvent *event = [[self alloc] init];
    
    NSMutableDictionary *mutableFields = [NSMutableDictionary dictionaryWithDictionary:fields];
    event.event = mutableFields[@"event"];
    event.identifier = mutableFields[@"id"];
    event.data = [mutableFields[@"data"] dataUsingEncoding:NSUTF8StringEncoding];
    event.retry = [mutableFields[@"retry"] integerValue];
    
    [mutableFields removeObjectsForKeys:@[@"event", @"id", @"data", @"retry"]];
    event.userInfo = mutableFields;
    
    return event;
}

#pragma mark - NSCoding

- (id)initWithCoder:(NSCoder *)aDecoder {
    if (!(self = [self init])) return nil;
    
    self.event = [aDecoder decodeObjectForKey:@"event"];
    self.identifier = [aDecoder decodeObjectForKey:@"identifier"];
    self.data = [aDecoder decodeObjectForKey:@"data"];
    self.retry = [aDecoder decodeIntegerForKey:@"retry"];
    
    return self;
}

- (void)encodeWithCoder:(NSCoder *)aCoder {
    [aCoder encodeObject:self.event forKey:@"event"];
    [aCoder encodeObject:self.identifier forKey:@"identifier"];
    [aCoder encodeObject:self.data forKey:@"data"];
    [aCoder encodeInteger:self.retry forKey:@"retry"];
}

#pragma mark - NSCopying

- (id)copyWithZone:(NSZone *)zone {
    TRVSServerSentEvent *event = [[[self class] allocWithZone:zone] init];
    event.event = self.event;
    event.identifier = self.identifier;
    event.data = self.data;
    event.retry = self.retry;    
    return event;
}

@end
