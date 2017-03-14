//
//  APMRecorder.h
//  Riff
//
//  Created by Patrick Tescher on 2/23/17.
//  Copyright © 2017 Out There Labs. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <opentracing/OTSpanContext.h>

@class APMTraceFragment, APMSpan;
@interface APMRecorder : NSObject

@property (readonly, nonnull) NSMutableSet *unfinishedSpanContexts;

- (nonnull instancetype)initWithURL:(nonnull NSURL*)baseURL credential:(nonnull NSURLCredential*)credential flushInterval:(NSTimeInterval)flushInterval timeoutInterval:(NSTimeInterval)timeoutInterval;

- (BOOL)addNodeForSpan:(APMSpan *)span;

- (void)send;

@end
