//
//  APMTracer.m
//  Riff
//
//  Created by Patrick Tescher on 2/23/17.
//  Copyright © 2017 Out There Labs. All rights reserved.
//

#import "APMTracer.h"
#import "APMSpan.h"
#import "APMRecorder.h"
#import "APMSpanContext.h"
#import "APMTrace.h"
#import <opentracing/OTGlobal.h>
#import <opentracing/OTReference.h>

@interface APMTracer ()

@property (strong, nonatomic, nonnull) APMRecorder *recorder;

@end

@implementation APMTracer

+ (void)setup:(NSURL *)apmURL flushInterval:(NSTimeInterval)flushInterval {
    APMTracer *tracer = [[APMTracer alloc] initWithAPMURL:apmURL flushInterval: flushInterval];
    [OTGlobal initSharedTracer:tracer];
}

- (instancetype)initWithAPMURL:(NSURL*)apmURL flushInterval:(NSTimeInterval)flushInterval {
    self = [super init];
    if (self) {
        self.recorder = [[APMRecorder alloc] initWithURL:apmURL flushInterval:flushInterval timeoutInterval:10];
    }
    return self;
}

- (id<OTSpan>)startSpan:(NSString *)operationName {
    return [self startSpan:operationName childOf:nil tags:nil startTime:[NSDate date]];
}

- (id<OTSpan>)startSpan:(NSString *)operationName tags:(NSDictionary *)tags {
    return [self startSpan:operationName childOf:nil tags:tags startTime:[NSDate date]];
}

- (id<OTSpan>)startSpan:(NSString *)operationName childOf:(id<OTSpanContext>)parent {
    return [self startSpan:operationName childOf:parent tags:nil startTime:[NSDate date]];
}

- (id<OTSpan>)startSpan:(NSString *)operationName childOf:(id<OTSpanContext>)parent tags:(NSDictionary *)tags {
    return [self startSpan:operationName childOf:parent tags:tags startTime:[NSDate date]];
}

- (id<OTSpan>)startSpan:(NSString *)operationName
                childOf:(id<OTSpanContext>)parent
                   tags:(NSDictionary *)tags
              startTime:(NSDate *)startTime {
    return [self startSpan:operationName references:@[[OTReference childOf:parent]] tags:tags startTime:startTime];
}

- (id<OTSpan>)startSpan:(NSString *)operationName
             references:(NSArray *)references
                   tags:(NSDictionary *)tags
              startTime:(NSDate *)startTime {

    APMSpan *span = [[APMSpan alloc] initWithTracer:self references:references startTime:startTime];
    span.operationName = operationName;
    for (NSString *key in tags.allKeys) {
        [span setTag:key value:tags[key]];
    }
    return span;
}

- (BOOL)inject:(id<OTSpanContext>)spanContext format:(NSString *)format carrier:(id)carrier {
    return [self inject:spanContext format:format carrier:carrier error: nil];
}

- (BOOL)inject:(id<OTSpanContext>)spanContext format:(NSString *)format carrier:(id)carrier error:(NSError * _Nullable __autoreleasing *)outError {
    NSParameterAssert(spanContext);


    if ([(APMSpanContext*)spanContext isKindOfClass:[APMSpanContext class]]) {
        APMSpanContext *apmSpanContext = (APMSpanContext*)spanContext;
        APMTrace *trace = apmSpanContext.trace;
        NSDictionary *tags = carrier[@"tags"];
        NSString *type = tags[@"node.type"] ?: @"Component";
        [trace addNodeWithSpanContext:apmSpanContext carrier:carrier type:type];
        if (apmSpanContext.parentContext == nil) {
            return [self.recorder addTrace:trace error: outError];
        } else {
            return @YES;
        }
    } else {
        return @NO;
    }
}

- (id<OTSpanContext>)extractWithFormat:(NSString *)format carrier:(id)carrier {
    return [self extractWithFormat:format carrier:carrier error:nil];
}

- (id<OTSpanContext>)extractWithFormat:(NSString *)format carrier:(id)carrier error:(NSError * _Nullable __autoreleasing *)outError {
    return nil;
}

@end
