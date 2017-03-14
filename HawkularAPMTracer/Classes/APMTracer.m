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
#import "APMTraceFragment.h"
#import "APMNode.h"
#import <opentracing/OTGlobal.h>
#import <opentracing/OTReference.h>

@interface APMTracer ()

@property (strong, nonatomic, nonnull) APMRecorder *recorder;

@end

@implementation APMTracer

+ (void)setup:(NSURL *)apmURL credential:(NSURLCredential* _Nonnull)credential flushInterval:(NSTimeInterval)flushInterval {
    APMTracer *tracer = [[APMTracer alloc] initWithAPMURL:apmURL credential:credential flushInterval: flushInterval];
    [OTGlobal initSharedTracer:tracer];
}

- (void)flush {
    [self.recorder send];
}

- (instancetype)initWithAPMURL:(NSURL*)apmURL credential:(NSURLCredential* _Nonnull)credential flushInterval:(NSTimeInterval)flushInterval {
    self = [super init];
    if (self) {
        self.recorder = [[APMRecorder alloc] initWithURL:apmURL credential:credential flushInterval:flushInterval timeoutInterval:10];
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
    if (parent == nil) {
        return [self startSpan:operationName references:nil tags:tags startTime:startTime];
    }
    if ([(id)parent isMemberOfClass:[APMSpanContext class]]) {
        [self.recorder.unfinishedSpanContexts addObject:parent];
    }
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
    [self.recorder.unfinishedSpanContexts addObject:span.context];
    return span;
}

- (BOOL)inject:(id<OTSpanContext>)spanContext format:(NSString *)format carrier:(id)carrier {
    return [self inject:spanContext format:format carrier:carrier error: nil];
}

- (BOOL)inject:(id<OTSpanContext>)spanContext format:(NSString *)format carrier:(id)carrier error:(NSError * _Nullable __autoreleasing *)outError {
    NSParameterAssert(spanContext);

    if (![(id)spanContext isKindOfClass:[APMSpanContext class]]) {
        return NO;
    }

    APMSpanContext *apmSpanContext = (APMSpanContext*)spanContext;
    apmSpanContext.hasBeenInjected = true;

    if ([format isEqualToString:OTFormatHTTPHeaders] && [carrier isKindOfClass:[NSMutableDictionary class]]) {
        NSMutableDictionary *headers = (NSMutableDictionary*)carrier;
        headers[@"HWKAPMID"] = apmSpanContext.spanID; // TODO: Node relative IDs
        headers[@"HWKAPMTRACEID"] = apmSpanContext.traceID;
        headers[@"HWKAPMLEVEL"] = apmSpanContext.level;
        headers[@"HWKAPMTXN"] = apmSpanContext.transaction;
        return YES;
    }
    return NO;
}

- (id<OTSpanContext>)extractWithFormat:(NSString *)format carrier:(id)carrier {
    return [self extractWithFormat:format carrier:carrier error:nil];
}

- (APMSpanContext*)extractWithFormat:(NSString *)format carrier:(id)carrier error:(NSError * _Nullable __autoreleasing *)outError {
    if ([format isEqualToString:OTFormatHTTPHeaders] && [carrier isKindOfClass:[NSDictionary class]]) {
        NSDictionary *headers = (NSDictionary*)carrier;
        NSString *spanID = headers[@"HWKAPMID"];

        for (APMSpanContext *context in self.recorder.unfinishedSpanContexts) {
            if ([context.spanID isEqualToString:spanID]) {
                return context;
            }
        }

        NSString *traceID = headers[@"HWKAPMTRACEID"];
        NSString *parentSpanID = headers[@"HWKAPMPARENTID"];
        NSString *level = headers[@"HWKAPMLEVEL"];
        NSString *transaction = headers[@"HWKAPMTXN"];

        APMSpanContext *parentContext = nil;

        if (parentSpanID != nil && traceID != nil) {
            NSMutableDictionary *parentHeaders = @{
                                                   @"HWKAPMTRACEID": traceID,
                                                   @"HWKAPMID": parentSpanID,
                                                   }.mutableCopy;
            parentHeaders[@"HWKAPMLEVEL"] = level;
            parentHeaders[@"HWKAPMTXN"] = transaction;

            id<OTSpanContext> parentContext = [self extractWithFormat:OTFormatHTTPHeaders carrier:parentHeaders error:outError];
            if ([(id)parentContext isMemberOfClass:[APMSpanContext class]]) {
                parentContext = (APMSpanContext*)parentContext;
            }
        }

        if (traceID != nil && spanID != nil) {
            APMSpanContext *context = [[APMSpanContext alloc] initWithTraceID:traceID spanID:spanID];
            context.parentContext = parentContext;
            context.transaction = transaction;
            context.level = level;
            return context;
        } else {
            return nil;
        }
    }
    if ([format isEqualToString:OTFormatTextMap] && [carrier isKindOfClass:[NSDictionary class]]) {
        NSDictionary *headers = (NSDictionary*)carrier;
        NSString *traceID = headers[@"HWKAPMTRACEID"];
        APMSpanContext *context = [[APMSpanContext alloc] initWithTraceID:traceID spanID:[APMSpan generateID]];
        return context;
    }
    return nil;
}

@end
