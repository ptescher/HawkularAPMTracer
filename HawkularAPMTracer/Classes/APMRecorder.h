//
//  APMRecorder.h
//  Riff
//
//  Created by Patrick Tescher on 2/23/17.
//  Copyright © 2017 Out There Labs. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <opentracing/OTSpanContext.h>

static NSUInteger APMRecorderMaxPendingNodes = 1000;
static NSUInteger APMRecorderMaxUnfinishedSpans = 1000;
static NSUInteger APMRecorderMaxPendingFragments = 1000;

@class APMTraceFragment, APMSpan;
@interface APMRecorder : NSObject

@property (readonly, nonnull) NSMutableOrderedSet *unfinishedSpanContexts;
@property (readonly, nonnull) NSMutableOrderedSet *orphanedNodes;

- (nonnull instancetype)initWithURL:(nonnull NSURL*)baseURL credential:(nonnull NSURLCredential*)credential flushInterval:(NSTimeInterval)flushInterval timeoutInterval:(NSTimeInterval)timeoutInterval;

- (BOOL)addNodeForSpan:(nonnull APMSpan *)span;

- (void)send;
- (void)send:(void (^)(NSError * _Nullable error))completionHandler;

@end
