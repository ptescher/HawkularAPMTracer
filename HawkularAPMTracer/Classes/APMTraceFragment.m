//
//  APMTrace.m
//  Riff
//
//  Created by Patrick Tescher on 2/23/17.
//  Copyright © 2017 Out There Labs. All rights reserved.
//

#import "APMTraceFragment.h"
#import "APMNode.h"
#import "APMSpanContext.h"
#import "APMSpan.h"

@interface APMTraceFragment ()

@property (strong, nonatomic, nonnull) NSMutableArray<APMNode*> *rootNodes;
@property (strong, nonatomic, nonnull) NSMutableArray<APMNode*> *orphanedNodes;
@property (strong, nonatomic, nonnull) NSString *fragmendID;
@property (strong, nonatomic, nullable) NSString *hostAddress;
@property (readonly, nullable) NSDate *timestamp;
@property (strong, nonatomic, nullable) NSString *traceID;
@property (nonatomic) bool isFinished;

@end

@implementation APMTraceFragment

- (instancetype)initWithTraceID:(NSString* _Nonnull)traceID spanID:(NSString*)spanID {
    self = [super init];
    if (self) {
        self.rootNodes = [NSMutableArray<APMNode*> new];
        self.orphanedNodes = [NSMutableArray<APMNode*> new];
        self.traceID = traceID;
        self.isFinished = false;
        self.fragmendID = spanID;
    }
    return self;
}

- (NSDate *)timestamp {
    return [self.rootNodes valueForKeyPath:@"@min.timestamp"];
}

- (NSDictionary *)traceDictionary {
    NSMutableDictionary *traceDictionary = [[NSMutableDictionary alloc] initWithCapacity:7];
    traceDictionary[@"fragmentId"] = self.fragmendID;
    traceDictionary[@"hostAddress"] = self.hostAddress;
    traceDictionary[@"nodes"] = [self.rootNodes valueForKeyPath:@"@unionOfObjects.nodeDictionary"];
    traceDictionary[@"timestamp"] = self.timestamp == nil ? nil : [NSNumber numberWithLong: [self.timestamp timeIntervalSince1970] * 1000000];
    traceDictionary[@"traceId"] = self.traceID;
    traceDictionary[@"transaction"] = self.transaction;
    return [traceDictionary copy];
}

@end
