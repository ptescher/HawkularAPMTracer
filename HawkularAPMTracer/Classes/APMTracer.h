//
//  APMTracer.h
//  Riff
//
//  Created by Patrick Tescher on 2/23/17.
//  Copyright © 2017 Out There Labs. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <opentracing/OTTracer.h>
#import <opentracing/OTSpanContext.h>

@class APMRecorder;
@interface APMTracer : NSObject<OTTracer>

@property (readonly, nonnull) APMRecorder *recorder;

+ (void)setup:(NSURL* _Nonnull)apmURL credential:(NSURLCredential* _Nonnull)credential flushInterval:(NSTimeInterval)flushInterval;
- (void)flush;
- (void)flush:(void (^)(NSError * _Nullable error))completionHandler;

@end
