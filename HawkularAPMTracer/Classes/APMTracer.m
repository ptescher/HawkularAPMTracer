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
@property (strong, nonatomic, nonnull) NSCache *spanCache;

@end

@implementation APMTracer

+ (void)setup:(NSURL *)apmURL credential:(NSURLCredential* _Nonnull)credential flushInterval:(NSTimeInterval)flushInterval {
    APMTracer *tracer = [[APMTracer alloc] initWithAPMURL:apmURL credential:credential flushInterval: flushInterval];
    [OTGlobal initSharedTracer:tracer];
}

- (instancetype)initWithAPMURL:(NSURL*)apmURL credential:(NSURLCredential* _Nonnull)credential flushInterval:(NSTimeInterval)flushInterval {
    self = [super init];
    if (self) {
        self.recorder = [[APMRecorder alloc] initWithURL:apmURL credential:credential flushInterval:flushInterval timeoutInterval:10];
        self.spanCache = [NSCache new];
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
        [self.spanCache setObject:apmSpanContext forKey:apmSpanContext.spanID];
        APMTrace *trace = apmSpanContext.trace;
        NSDictionary *tags = carrier[@"tags"];
        NSString *type = tags[@"node.type"] ?: @"Component";
        NSDate *startTime = carrier[@"startTime"];
        NSDate *finishTime = carrier[@"finishTime"];
        [trace addNodeWithSpanContext:apmSpanContext carrier:carrier type:type startTime:startTime finishTime:finishTime];
        if (trace.isFinished) {
            return [self.recorder addTrace:trace error: outError];
        } else {
            return @YES;
        }
    } else {
        return @NO;
    }
}

- (id<OTSpanContext>)cachedContextWithSpanID:(NSString*)spanID {
    [self.spanCache objectForKey:spanID];
}

- (id<OTSpanContext>)extractWithFormat:(NSString *)format carrier:(id)carrier {
    return [self extractWithFormat:format carrier:carrier error:nil];
}

- (id<OTSpanContext>)extractWithFormat:(NSString *)format carrier:(id)carrier error:(NSError * _Nullable __autoreleasing *)outError {
    if ([format isEqualToString:OTFormatHTTPHeaders]) {
        NSDictionary *headers = (NSDictionary*)carrier;
        NSString *traceID = headers[@"X-B3-TraceId"];
        NSString *spanID = headers[@"X-B3-SpanId"];
        NSString *parentSpanID = headers[@"X-B3-ParentSpanId"];
        NSString *sampled = headers[@"X-B3-Sampled"];
        NSString *transaction = headers[@"X-B3-Transaction"];
        if ([sampled isEqualToString:@"1"] && traceID != nil && spanID != nil) {
            APMSpanContext *context = [[APMSpanContext alloc] initWithTraceID:traceID spanID:spanID];
            context.transaction = transaction;
            if (parentSpanID != nil && traceID != nil) {
                NSMutableDictionary *parentHeaders = @{
                                          @"X-B3-TraceId": traceID,
                                          @"X-B3-SpanId": parentSpanID,
                                          }.mutableCopy;
                parentHeaders[@"X-B3-Sampled"] = sampled;
                parentHeaders[@"X-B3-Transaction"] = transaction;
                context.parentContext = [self cachedContextWithSpanID:parentSpanID] ?: [self extractWithFormat:OTFormatHTTPHeaders carrier:parentHeaders error:outError];
            }
            return context;
        }
    }
    if ([format isEqualToString:OTFormatTextMap]) {
        NSDictionary *headers = (NSDictionary*)carrier;
        NSString *traceID = headers[@"HWKAPMTRACEID"];
        APMSpanContext *context = [[APMSpanContext alloc] initWithTraceID:traceID spanID:[APMSpan generateID]];
        return context;
    }
    return nil;
}

@end
